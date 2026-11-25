// Holt OSM- und Höhendaten für die Spielwelt rund um Riegersdorf und schreibt data/riegersdorf.json.
// Lokale Meter: x = Osten, z = Süden, y = Höhe über dem tiefsten Punkt. Ursprung = Ortskern Riegersdorf.
//
// Aufruf:  node tools/build_world_data.mjs [--refresh]
//
// Quellen:
//  - OpenStreetMap (Overpass API), © OpenStreetMap-Mitwirkende, ODbL
//  - Höhen: AWS Terrain Tiles (Terrarium), u.a. aus dem österreichischen DGM
//  - Spielgrenze: tools/map_border.json (aus Marcos Kartenbild, siehe map_border_fit.mjs)
//
// Hier passiert die rechenintensive Vorarbeit: Gelände unter Straßen glätten, Flächenarten je
// Rasterpunkt bestimmen, Bäume setzen (nicht auf Straßen, Gleisen, Bächen oder in Häusern).

import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const RAW = path.join(ROOT, "data", "raw");
const OUT = path.join(ROOT, "data", "riegersdorf.json");
const REFRESH = process.argv.includes("--refresh");
const UA = "saint-leonard-dev/0.1";

const LAT0 = 46.5491278; // Ortskern Riegersdorf (OSM place=village)
const LON0 = 13.7806496;
const MARGIN = 400; // Meter Landschaft außerhalb der Grenze
const STEP = 5; // Meter zwischen Höhenpunkten
const ZOOM = 15;
const FAR_ZOOM = 12; // Berge rundherum, grob
const FAR_HALF = 9000;
const FAR_STEP = 45;

const M_PER_DEG_LAT = 110574;
const M_PER_DEG_LON = 111320 * Math.cos((LAT0 * Math.PI) / 180);
const toLocal = (lat, lon) => [
  +((lon - LON0) * M_PER_DEG_LON).toFixed(2),
  +(-(lat - LAT0) * M_PER_DEG_LAT).toFixed(2),
];
const toLatLon = (x, z) => [LAT0 - z / M_PER_DEG_LAT, LON0 + x / M_PER_DEG_LON];

const border = JSON.parse(fs.readFileSync(path.join(ROOT, "tools", "map_border.json"), "utf8")).border.map(([la, lo]) => toLocal(la, lo));
const bx = border.map((p) => p[0]), bz = border.map((p) => p[1]);
const X0 = Math.floor((Math.min(...bx) - MARGIN) / STEP) * STEP;
const Z0 = Math.floor((Math.min(...bz) - MARGIN) / STEP) * STEP;
const NX = Math.ceil((Math.max(...bx) + MARGIN - X0) / STEP) + 1;
const NZ = Math.ceil((Math.max(...bz) + MARGIN - Z0) / STEP) + 1;
// Spielbereich + sichtbarer Rand: nur hier wachsen Bäume (das Raster ist ein Rechteck und reicht
// bei der Villach-Erweiterung weit über die Grenze hinaus, z. B. in den Dobratsch-Wald)
const NEAR_CELL = 25;
const NNX = Math.ceil((NX * STEP) / NEAR_CELL) + 1, NNZ = Math.ceil((NZ * STEP) / NEAR_CELL) + 1;
const nearMask = new Uint8Array(NNX * NNZ);
{
  const inside = (x, z) => {
    let c = false;
    for (let a = 0, b = border.length - 1; a < border.length; b = a++) {
      const [xa, za] = border[a], [xb, zb] = border[b];
      if ((za > z) !== (zb > z) && x < ((xb - xa) * (z - za)) / (zb - za) + xa) c = !c;
    }
    return c;
  };
  const segDist = (x, z) => {
    let best = Infinity;
    for (let a = 0, b = border.length - 1; a < border.length; b = a++) {
      const [xa, za] = border[a], [xb, zb] = border[b];
      const dx = xb - xa, dz = zb - za, l2 = dx * dx + dz * dz;
      const t = l2 > 0 ? Math.min(1, Math.max(0, ((x - xa) * dx + (z - za) * dz) / l2)) : 0;
      best = Math.min(best, Math.hypot(x - xa - t * dx, z - za - t * dz));
    }
    return best;
  };
  for (let j = 0; j < NNZ; j++)
    for (let i = 0; i < NNX; i++) {
      const x = X0 + i * NEAR_CELL, z = Z0 + j * NEAR_CELL;
      nearMask[j * NNX + i] = inside(x, z) || segDist(x, z) < MARGIN + NEAR_CELL ? 1 : 0;
    }
}
const nearPlay = (i, j) => nearMask[Math.floor((j * STEP) / NEAR_CELL) * NNX + Math.floor((i * STEP) / NEAR_CELL)] === 1;
const [S, W] = toLatLon(X0, Z0 + (NZ - 1) * STEP);
const [N, E] = toLatLon(X0 + (NX - 1) * STEP, Z0);

fs.mkdirSync(RAW, { recursive: true });

async function cached(file, urls, opts) {
  const p = path.join(RAW, file);
  if (!REFRESH && fs.existsSync(p) && fs.statSync(p).size > 0) return fs.readFileSync(p);
  let lastErr;
  for (let attempt = 0; attempt < 4; attempt++) {
    for (const url of [].concat(urls)) {
      console.log("lade", url.slice(0, 90));
      try {
        const res = await fetch(url, { headers: { "User-Agent": UA }, signal: AbortSignal.timeout(240000), ...opts });
        if (!res.ok) throw new Error(`${res.status} ${url}`);
        const buf = Buffer.from(await res.arrayBuffer());
        fs.writeFileSync(p, buf);
        return buf;
      } catch (e) {
        lastErr = e;
        console.log("  fehlgeschlagen:", e.message);
      }
    }
    await new Promise((r) => setTimeout(r, 5000 * (attempt + 1)));
  }
  throw lastErr;
}

// ---------------------------------------------------------------- PNG (RGB/RGBA, 8 bit)
function decodePng(buf) {
  let pos = 8, width = 0, height = 0, colorType = 0;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString("ascii", pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      if (data[8] !== 8 || data[12] !== 0) throw new Error("PNG-Format nicht unterstützt");
      colorType = data[9];
    } else if (type === "IDAT") idat.push(data);
    else if (type === "IEND") break;
    pos += 12 + len;
  }
  const bpp = colorType === 6 ? 4 : colorType === 2 ? 3 : 0;
  if (!bpp) throw new Error("PNG-Farbtyp nicht unterstützt: " + colorType);
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * bpp;
  const out = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const f = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[y * stride + x - bpp] : 0;
      const b = y > 0 ? out[(y - 1) * stride + x] : 0;
      const c = x >= bpp && y > 0 ? out[(y - 1) * stride + x - bpp] : 0;
      let v = line[x];
      if (f === 1) v += a;
      else if (f === 2) v += b;
      else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) {
        const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      out[y * stride + x] = v & 255;
    }
  }
  return { width, height, bpp, data: out };
}

// ---------------------------------------------------------------- Höhen
async function heightSampler(zoom, s, w, n, e) {
  const tn = 2 ** zoom;
  const lonToX = (lon) => ((lon + 180) / 360) * tn;
  const latToY = (lat) => {
    const r = (lat * Math.PI) / 180;
    return ((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * tn;
  };
  const tiles = {};
  for (let tx = Math.floor(lonToX(w)); tx <= Math.floor(lonToX(e)); tx++)
    for (let ty = Math.floor(latToY(n)); ty <= Math.floor(latToY(s)); ty++) {
      const buf = await cached(`terrarium_${zoom}_${tx}_${ty}.png`,
        `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/${zoom}/${tx}/${ty}.png`);
      tiles[`${tx}_${ty}`] = decodePng(buf);
    }
  const px = (gx, gy) => {
    const tx = Math.floor(gx / 256), ty = Math.floor(gy / 256);
    const t = tiles[`${tx}_${ty}`];
    if (!t) return 0;
    const o = ((gy - ty * 256) * t.width + (gx - tx * 256)) * t.bpp;
    return t.data[o] * 256 + t.data[o + 1] + t.data[o + 2] / 256 - 32768;
  };
  return (lat, lon) => {
    const fx = lonToX(lon) * 256 - 0.5, fy = latToY(lat) * 256 - 0.5;
    const ix = Math.floor(fx), iy = Math.floor(fy), ax = fx - ix, ay = fy - iy;
    return px(ix, iy) * (1 - ax) * (1 - ay) + px(ix + 1, iy) * ax * (1 - ay) +
      px(ix, iy + 1) * (1 - ax) * ay + px(ix + 1, iy + 1) * ax * ay;
  };
}

// ---------------------------------------------------------------- OSM
async function loadOsm() {
  const bbox = `${S},${W},${N},${E}`;
  const q = `[out:json][timeout:180];(way(${bbox});relation(${bbox})[type=multipolygon];node(${bbox})[~"."~"."];);out body;>;out skel qt;`;
  const buf = await cached("osm_world.json", [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
  ], { method: "POST", body: new URLSearchParams({ data: q }) });
  return JSON.parse(buf.toString("utf8"));
}

const ROAD_WIDTH = {
  motorway: 11, trunk: 9, primary: 7, secondary: 6.5, tertiary: 6, unclassified: 4.5, residential: 4.5,
  living_street: 4, service: 3.2, track: 2.6, path: 1.4, footway: 1.6, cycleway: 2, steps: 1.6,
  motorway_link: 5, trunk_link: 5, primary_link: 5, secondary_link: 5, tertiary_link: 4.5,
};
const LANDUSE = {
  farmland: "farmland", meadow: "meadow", grass: "meadow", residential: "residential",
  forest: "forest", cemetery: "cemetery", orchard: "meadow", farmyard: "residential", allotments: "meadow",
  industrial: "industrial", commercial: "industrial", retail: "industrial", railway: "industrial", construction: "industrial",
};
const NATURAL = { wood: "forest", water: "water", scrub: "scrub", grassland: "meadow", heath: "meadow" };
// Reihenfolge = Priorität (spätere übermalen frühere), Index = Wert im Flächenraster
const AREA_KINDS = ["grass", "meadow", "farmland", "scrub", "residential", "industrial", "cemetery", "forest", "pitch", "parking", "water"];

const num = (v) => {
  const f = parseFloat(String(v ?? "").replace(",", "."));
  return Number.isFinite(f) ? f : null;
};

function buildingInfo(t) {
  const type = t.building === "yes" ? (t.amenity || "yes") : t.building;
  let levels = num(t["building:levels"]);
  const height = num(t.height);
  if (levels == null) {
    levels = { garage: 1, garages: 1, carport: 1, shed: 1, hut: 1, roof: 1, barn: 1.6, farm_auxiliary: 1.6,
      transformer_tower: 2, church: 3, chapel: 1.5, apartments: 3, train_station: 2, industrial: 2.5,
      warehouse: 2.5, commercial: 2, retail: 1.6, school: 2.5 }[type] ?? 2;
  }
  let wall = height ?? levels * 2.9;
  if (type === "church") wall = Math.max(wall, 9);
  const flatTypes = ["garage", "garages", "carport", "roof", "shed", "industrial", "warehouse", "retail", "commercial"];
  const roof = t["roof:shape"] || (flatTypes.includes(type) ? "flat" : "gabled");
  return { type, levels: Math.max(1, Math.round(levels)), wall: +wall.toFixed(2), roof };
}

const ringFromWay = (way, nodes) =>
  way.nodes.map((id) => nodes.get(id)).filter(Boolean).map((nd) => toLocal(nd.lat, nd.lon));

function joinRings(ways, nodes) {
  const segs = ways.map((w) => w.nodes.slice());
  const rings = [];
  while (segs.length) {
    let ring = segs.shift();
    let changed = true;
    while (ring[0] !== ring[ring.length - 1] && changed) {
      changed = false;
      for (let i = 0; i < segs.length; i++) {
        const s = segs[i], end = ring[ring.length - 1];
        if (s[0] === end) ring = ring.concat(s.slice(1));
        else if (s[s.length - 1] === end) ring = ring.concat(s.slice(0, -1).reverse());
        else continue;
        segs.splice(i, 1);
        changed = true;
        break;
      }
    }
    if (ring[0] === ring[ring.length - 1])
      rings.push(ring.map((id) => nodes.get(id)).filter(Boolean).map((nd) => toLocal(nd.lat, nd.lon)).slice(0, -1));
  }
  return rings;
}

function convertOsm(osm) {
  const nodes = new Map(), ways = new Map();
  for (const e of osm.elements) {
    if (e.type === "node") nodes.set(e.id, e);
    else if (e.type === "way") ways.set(e.id, e);
  }
  const out = { buildings: [], roads: [], rails: [], water_lines: [], areas: [], pois: [], places: [], lone_trees: [] };
  const closed = (w) => w.nodes.length > 3 && w.nodes[0] === w.nodes[w.nodes.length - 1];

  for (const w of ways.values()) {
    const t = w.tags;
    if (!t) continue;
    if (t.building && closed(w) && t.building !== "no") {
      const pts = ringFromWay(w, nodes).slice(0, -1);
      if (pts.length >= 3)
        out.buildings.push({ id: w.id, pts, name: t.name || null, housenumber: t["addr:housenumber"] || null, ...buildingInfo(t) });
    } else if (t.highway && ROAD_WIDTH[t.highway] && t.area !== "yes") {
      const layer = num(t.layer) ?? 0;
      out.roads.push({ kind: t.highway, width: ROAD_WIDTH[t.highway], bridge: !!t.bridge && t.bridge !== "no",
        tunnel: !!t.tunnel && t.tunnel !== "no", layer, name: t.name || t.ref || null,
        tracktype: t.tracktype || null, surface: t.surface || null, pts: ringFromWay(w, nodes) });
    } else if (t.railway === "rail" || t.railway === "platform") {
      out.rails.push({ kind: t.railway, width: t.railway === "rail" ? 3.2 : 3, bridge: !!t.bridge && t.bridge !== "no",
        tunnel: !!t.tunnel && t.tunnel !== "no", pts: ringFromWay(w, nodes) });
    } else if (t.waterway && t.tunnel !== "culvert" && ["river", "stream", "ditch", "drain", "canal"].includes(t.waterway)) {
      out.water_lines.push({ kind: t.waterway, width: t.waterway === "river" ? 14 : t.waterway === "stream" ? 2.5 : 1.5, pts: ringFromWay(w, nodes) });
    }
    const area = LANDUSE[t.landuse] || NATURAL[t.natural] || (t.leisure === "pitch" ? "pitch" : null) ||
      (t.amenity === "parking" ? "parking" : null) || (t.water || t.waterway === "riverbank" ? "water" : null);
    if (area && closed(w)) out.areas.push({ kind: area, outer: [ringFromWay(w, nodes).slice(0, -1)], inner: [] });
  }

  for (const r of osm.elements.filter((e) => e.type === "relation" && e.tags)) {
    const t = r.tags;
    const kind = LANDUSE[t.landuse] || NATURAL[t.natural] || (t.water ? "water" : null);
    if (!kind) continue;
    const mw = (role) => r.members.filter((m) => m.type === "way" && (role === "inner" ? m.role === "inner" : m.role !== "inner"))
      .map((m) => ways.get(m.ref)).filter(Boolean);
    out.areas.push({ kind, outer: joinRings(mw("outer"), nodes), inner: joinRings(mw("inner"), nodes) });
  }

  for (const nd of nodes.values()) {
    const t = nd.tags;
    if (!t) continue;
    const pos = toLocal(nd.lat, nd.lon);
    if (t.natural === "tree") out.lone_trees.push(pos);
    if (t.place && t.name && ["village", "hamlet", "town", "suburb", "neighbourhood", "isolated_dwelling", "locality"].includes(t.place))
      out.places.push({ name: t.name, kind: t.place, pos });
    if (t.name && (t.amenity || t.railway === "halt" || t.railway === "station" || t.shop || t.tourism)) {
      out.pois.push({ name: t.name, kind: t.amenity || t.railway || t.shop || t.tourism, housenumber: t["addr:housenumber"] || null, pos });
    }
  }
  for (const b of out.buildings) {
    if (!b.name) continue;
    const c = b.pts.reduce((a, p) => [a[0] + p[0] / b.pts.length, a[1] + p[1] / b.pts.length], [0, 0]);
    out.pois.push({ name: b.name, kind: b.type, housenumber: b.housenumber, pos: c.map((v) => +v.toFixed(2)) });
  }
  return out;
}

// ---------------------------------------------------------------- Geometrie
function inPoly(x, z, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, zi] = poly[i], [xj, zj] = poly[j];
    if ((zi > z) !== (zj > z) && x < ((xj - xi) * (z - zi)) / (zj - zi) + xi) inside = !inside;
  }
  return inside;
}

function resample(pts, maxSeg) {
  const out = [];
  for (let k = 0; k < pts.length; k++) {
    if (k > 0) {
      const [ax, az] = pts[k - 1], [bx, bz] = pts[k];
      const n = Math.ceil(Math.hypot(bx - ax, bz - az) / maxSeg);
      for (let s = 1; s < n; s++) out.push([ax + ((bx - ax) * s) / n, az + ((bz - az) * s) / n]);
    }
    out.push(pts[k]);
  }
  return out;
}

const smoothstep = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};

// ---------------------------------------------------------------- main
const osm = await loadOsm();
const world = convertOsm(osm);
console.log(`Raster ${NX} x ${NZ} (${((NX * NZ) / 1e6).toFixed(2)} Mio Punkte)`);

const sample = await heightSampler(ZOOM, S, W, N, E);
const H = new Float32Array(NX * NZ);
let minH = Infinity;
for (let j = 0; j < NZ; j++)
  for (let i = 0; i < NX; i++) {
    const [la, lo] = toLatLon(X0 + i * STEP, Z0 + j * STEP);
    const v = sample(la, lo);
    H[j * NX + i] = v;
    if (v < minH) minH = v;
  }
const BASE = Math.floor(minH);
for (let k = 0; k < H.length; k++) H[k] -= BASE;

const hAt = (x, z) => {
  const fx = Math.min(Math.max((x - X0) / STEP, 0), NX - 1.001), fz = Math.min(Math.max((z - Z0) / STEP, 0), NZ - 1.001);
  const i = Math.floor(fx), j = Math.floor(fz), ax = fx - i, az = fz - j, o = j * NX + i;
  return (H[o] * (1 - ax) + H[o + 1] * ax) * (1 - az) + (H[o + NX] * (1 - ax) + H[o + NX + 1] * ax) * az;
};

// Gelände unter Straßen und Gleisen glätten: geglättetes Längsprofil, seitlich sanft auslaufend
const bestD = new Float32Array(NX * NZ).fill(Infinity);
const target = new Float32Array(NX * NZ);
const halfW = new Float32Array(NX * NZ);
const clear = new Uint8Array(NX * NZ); // 1 = hier keine Bäume
const flatten = [
  ...world.roads.filter((r) => !r.tunnel && !r.bridge && !["path", "footway", "steps"].includes(r.kind)),
  ...world.rails.filter((r) => r.kind === "rail" && !r.tunnel && !r.bridge),
];
for (const r of flatten) {
  const line = resample(r.pts, 2);
  if (line.length < 2) continue;
  let prof = line.map(([x, z]) => hAt(x, z));
  const win = r.kind === "rail" ? 20 : r.width > 6 ? 12 : 7;
  for (let pass = 0; pass < 2; pass++) {
    const next = prof.slice();
    for (let k = 0; k < prof.length; k++) {
      let s = 0, c = 0;
      for (let d = -win; d <= win; d++) {
        const q = k + d;
        if (q >= 0 && q < prof.length) { s += prof[q]; c++; }
      }
      next[k] = s / c;
    }
    prof = next;
  }
  const hw = r.width / 2, R = hw + 5;
  for (let k = 1; k < line.length; k++) {
    const [ax, az] = line[k - 1], [bx2, bz2] = line[k];
    const dx = bx2 - ax, dz = bz2 - az, len2 = dx * dx + dz * dz || 1e-6;
    const i0 = Math.max(0, Math.floor((Math.min(ax, bx2) - R - X0) / STEP)), i1 = Math.min(NX - 1, Math.ceil((Math.max(ax, bx2) + R - X0) / STEP));
    const j0 = Math.max(0, Math.floor((Math.min(az, bz2) - R - Z0) / STEP)), j1 = Math.min(NZ - 1, Math.ceil((Math.max(az, bz2) + R - Z0) / STEP));
    for (let j = j0; j <= j1; j++)
      for (let i = i0; i <= i1; i++) {
        const px = X0 + i * STEP, pz = Z0 + j * STEP;
        const u = Math.min(1, Math.max(0, ((px - ax) * dx + (pz - az) * dz) / len2));
        const d = Math.hypot(px - (ax + dx * u), pz - (az + dz * u));
        const o = j * NX + i;
        if (d < hw + 3.5) clear[o] = 1;
        if (d - hw < bestD[o] - halfW[o]) {
          bestD[o] = d;
          halfW[o] = hw;
          target[o] = prof[k - 1] + (prof[k] - prof[k - 1]) * u;
        }
      }
  }
}
for (let o = 0; o < H.length; o++) {
  if (bestD[o] === Infinity) continue;
  const w = 1 - smoothstep(halfW[o] + 0.8, halfW[o] + 5, bestD[o]);
  H[o] = H[o] + (target[o] - H[o]) * w;
}

// Keine Bäume auf Bächen, Brücken und Wegen
for (const r of [...world.water_lines, ...world.roads.filter((r) => r.bridge || ["path", "footway", "steps"].includes(r.kind))]) {
  for (const [x, z] of resample(r.pts, 2)) {
    const R = r.width / 2 + 3;
    for (let j = Math.floor((z - R - Z0) / STEP); j <= Math.ceil((z + R - Z0) / STEP); j++)
      for (let i = Math.floor((x - R - X0) / STEP); i <= Math.ceil((x + R - X0) / STEP); i++)
        if (i >= 0 && j >= 0 && i < NX && j < NZ && Math.hypot(X0 + i * STEP - x, Z0 + j * STEP - z) < R) clear[j * NX + i] = 1;
  }
}
// ... und nicht in oder direkt neben Häusern
for (const b of world.buildings) {
  const xs = b.pts.map((p) => p[0]), zs = b.pts.map((p) => p[1]);
  const i0 = Math.max(0, Math.floor((Math.min(...xs) - 4 - X0) / STEP)), i1 = Math.min(NX - 1, Math.ceil((Math.max(...xs) + 4 - X0) / STEP));
  const j0 = Math.max(0, Math.floor((Math.min(...zs) - 4 - Z0) / STEP)), j1 = Math.min(NZ - 1, Math.ceil((Math.max(...zs) + 4 - Z0) / STEP));
  for (let j = j0; j <= j1; j++) for (let i = i0; i <= i1; i++) clear[j * NX + i] = 1;
}

// Flächenarten je Rasterpunkt
const CLS = new Uint8Array(NX * NZ);
const areas = world.areas.filter((a) => AREA_KINDS.includes(a.kind) && a.outer.length)
  .sort((a, b) => AREA_KINDS.indexOf(a.kind) - AREA_KINDS.indexOf(b.kind));
for (const a of areas) {
  const v = AREA_KINDS.indexOf(a.kind);
  for (const ring of a.outer) {
    const xs = ring.map((p) => p[0]), zs = ring.map((p) => p[1]);
    const i0 = Math.max(0, Math.floor((Math.min(...xs) - X0) / STEP)), i1 = Math.min(NX - 1, Math.ceil((Math.max(...xs) - X0) / STEP));
    const j0 = Math.max(0, Math.floor((Math.min(...zs) - Z0) / STEP)), j1 = Math.min(NZ - 1, Math.ceil((Math.max(...zs) - Z0) / STEP));
    for (let j = j0; j <= j1; j++)
      for (let i = i0; i <= i1; i++) {
        const x = X0 + i * STEP, z = Z0 + j * STEP;
        if (inPoly(x, z, ring) && !a.inner.some((h) => inPoly(x, z, h))) CLS[j * NX + i] = v;
      }
  }
}

// Bäume: Wald dicht, Gebüsch locker, in Gärten und Wiesen vereinzelt
let seed = 12345;
const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
const trees = [];
const forest = AREA_KINDS.indexOf("forest"), scrub = AREA_KINDS.indexOf("scrub");
const sparse = new Set(["residential", "meadow", "grass", "cemetery"].map((k) => AREA_KINDS.indexOf(k)));
for (let j = 0; j < NZ; j++)
  for (let i = 0; i < NX; i++) {
    const o = j * NX + i;
    if (clear[o] || !nearPlay(i, j)) continue;
    const c = CLS[o];
    const p = c === forest ? 0.5 : c === scrub ? 0.18 : sparse.has(c) ? 0.012 : 0;
    if (rnd() >= p) continue;
    const x = X0 + i * STEP + (rnd() - 0.5) * STEP * 0.9, z = Z0 + j * STEP + (rnd() - 0.5) * STEP * 0.9;
    const conifer = c === forest ? rnd() < 0.65 : rnd() < 0.25;
    trees.push(+x.toFixed(1), +z.toFixed(1), conifer ? 1 : 0, +(0.75 + rnd() * 0.6).toFixed(2));
  }
for (const [x, z] of world.lone_trees) trees.push(x, z, 0, 1);

// Berge rundherum (grob)
const farSample = await heightSampler(FAR_ZOOM, ...toLatLon(-FAR_HALF, FAR_HALF), ...toLatLon(FAR_HALF, -FAR_HALF));
const FN = Math.round((2 * FAR_HALF) / FAR_STEP) + 1;
const FH = new Float32Array(FN * FN);
for (let j = 0; j < FN; j++)
  for (let i = 0; i < FN; i++) {
    const [la, lo] = toLatLon(-FAR_HALF + i * FAR_STEP, -FAR_HALF + j * FAR_STEP);
    FH[j * FN + i] = farSample(la, lo) - BASE;
  }

const b64 = (typed) => Buffer.from(typed.buffer, typed.byteOffset, typed.byteLength).toString("base64");
const out = {
  info: {
    name: "Riegersdorf", origin_lat: LAT0, origin_lon: LON0, base_height: BASE,
    attribution: "© OpenStreetMap-Mitwirkende (ODbL); Höhendaten: AWS Terrain Tiles / DGM Österreich",
  },
  grid: { x0: X0, z0: Z0, nx: NX, nz: NZ, step: STEP, heights: b64(H), classes: b64(CLS), kinds: AREA_KINDS },
  far: { x0: -FAR_HALF, z0: -FAR_HALF, n: FN, step: FAR_STEP, heights: b64(FH) },
  border,
  trees: b64(new Float32Array(trees)),
  buildings: world.buildings, roads: world.roads, rails: world.rails, water_lines: world.water_lines,
  water_areas: world.areas.filter((a) => a.kind === "water").map((a) => a.outer).flat(),
  pois: world.pois, places: world.places,
};
fs.writeFileSync(OUT, JSON.stringify(out));
console.log(
  `fertig: ${world.buildings.length} Gebäude, ${world.roads.length} Straßen, ${world.rails.length} Bahn, ` +
  `${world.water_lines.length} Gewässer, ${areas.length} Flächen, ${trees.length / 4} Bäume, ${world.places.length} Orte, ` +
  `Basis ${BASE} m, ${(fs.statSync(OUT).size / 1e6).toFixed(1)} MB`
);

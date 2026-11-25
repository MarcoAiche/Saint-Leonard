// Einmalig (P2-M1, Issue #17): Kartenerweiterung bis Villach.
// Marcos rote Linie (Kartenbild 1910 x 913 px) wird über Ortsbeschriftungen im Bild und deren
// Nominatim-Koordinaten in Geo-Koordinaten umgerechnet und mit der bisherigen Spielgrenze verbunden.
// Aufruf: node tools/map_border_villach.mjs  (schreibt tools/map_border.json neu)
import fs from "node:fs";

// [px, py, lat, lon]  Bezugspunkte (Beschriftung im Bild -> OSM-Ort)
const ref = [
  [1180, 361, 46.61673, 13.85003], // Villach
  [1428, 138, 46.63364, 13.88727], // Landskron
  [1018, 260, 46.61824, 13.82817], // St. Martin
  [1155, 209, 46.62178, 13.84700], // Lind
  [1035, 373, 46.60921, 13.83437], // Völkendorf
  [974, 447, 46.58970, 13.82372], // Warmbad-Judendorf
  [1116, 487, 46.59206, 13.84500], // Auen
  [1380, 420, 46.59961, 13.87974], // Maria Gail
  [1230, 557, 46.59082, 13.85815], // Tschinowitsch
  [1605, 207, 46.62185, 13.90839], // Zauchen
  [1677, 227, 46.62083, 13.91827], // Drautschen
  [1475, 294, 46.61670, 13.88333], // St. Magdalen
  [888, 770, 46.57038, 13.81431], // Unterfederaun
  [1167, 774, 46.57065, 13.84484], // Müllnern
  [1493, 556, 46.59097, 13.89390], // Mittewald
  [1513, 41, 46.63690, 13.89744], // Gratschach
  [1633, 343, 46.60977, 13.91347], // St. Ulrich
  [1003, 176, 46.62596, 13.82882], // Untere Fellach
  [872, 323, 46.61266, 13.80857], // Goritschach
  [785, 284, 46.61619, 13.79581], // Pogöriach
  [1550, 153, 46.62722, 13.90168], // St. Michael
  [478, 791, 46.56846, 13.75698], // Oberschütt
  [676, 832, 46.56501, 13.78370], // Unterschütt
  [1382, 770, 46.57045, 13.87811], // Höfling
];

const fit = (xs, ys) => {
  const n = xs.length, mx = xs.reduce((a, b) => a + b) / n, my = ys.reduce((a, b) => a + b) / n;
  let sxy = 0, sxx = 0;
  for (let i = 0; i < n; i++) { sxy += (xs[i] - mx) * (ys[i] - my); sxx += (xs[i] - mx) ** 2; }
  const a = sxy / sxx; return [a, my - a * mx];
};
// Beschriftungen von Stadtteilen sitzen nicht immer genau auf dem OSM-Punkt: grobe Ausreißer weglassen
let use = ref.slice();
let ax, bx, ay, by;
for (let round = 0; round < 4; round++) {
  [ax, bx] = fit(use.map(r => r[0]), use.map(r => r[3]));
  [ay, by] = fit(use.map(r => r[1]), use.map(r => r[2]));
  const errs = use.map(r => Math.hypot((ax * r[0] + bx - r[3]) * 76600, (ay * r[1] + by - r[2]) * 110574));
  const keep = use.filter((r, i) => errs[i] < 450);
  if (keep.length === use.length) break;
  use = keep;
}
let maxErr = 0;
for (const r of use) maxErr = Math.max(maxErr, Math.hypot((ax * r[0] + bx - r[3]) * 76600, (ay * r[1] + by - r[2]) * 110574));
console.log(`Bezugspunkte ${use.length}/${ref.length}, m/px x ${(ax * 76600).toFixed(1)} y ${(-ay * 110574).toFixed(1)}, max Fehler ${maxErr.toFixed(0)} m`);
console.log("weggelassen:", ref.filter(r => !use.includes(r)).map(r => `${r[0]},${r[1]}`).join(" ") || "keine");

// rote Linie im Uhrzeigersinn: unten links (bei Unterfederaun) hoch, über Fellach/Lind nach Landskron,
// rechts am Autobahnknoten herunter und über Maria Gail/Müllnern zurück Richtung Fürnitz
const red = [[1005, 722], [1015, 695], [995, 660], [968, 622], [945, 580], [925, 540], [910, 500], [905, 460], [906, 420],
  [912, 380], [930, 348], [955, 325], [968, 295], [965, 262], [955, 220], [945, 180], [940, 130], [943, 92], [960, 72],
  [1000, 60], [1050, 63], [1100, 72], [1150, 69], [1190, 80], [1222, 100], [1262, 118], [1300, 125], [1350, 130],
  [1400, 140], [1450, 158], [1500, 180], [1550, 210], [1568, 240], [1572, 262], [1560, 292], [1540, 322], [1520, 352],
  [1503, 382], [1480, 420], [1452, 468], [1430, 500], [1400, 522], [1360, 545], [1300, 575], [1250, 602], [1200, 632],
  [1170, 660], [1140, 690], [1110, 720], [1085, 750], [1068, 772]];
const villach = red.map(([x, y]) => [+(ay * y + by).toFixed(6), +(ax * x + bx).toFixed(6)]);

// bisherige Grenze (im Uhrzeigersinn, Start oben links). Nordspitze bei Unterfederaun bleibt,
// die Ostflanke bis Fürnitz wird durch die neue Linie ersetzt.
const old = JSON.parse(fs.readFileSync("tools/map_border.json", "utf8")).border;
const isOld = old.length === 40 && old[0][0] === 46.568469;
if (!isOld) { console.log("map_border.json ist schon erweitert, nichts zu tun"); process.exit(0); }
// old[1] = Nordspitze (46.5693, 13.8099); old[7] = Ostrand bei Fürnitz (46.5596, 13.8192)
const border = [old[0], old[1], ...villach, ...old.slice(7)];

const lats = border.map(b => b[0]), lons = border.map(b => b[1]);
console.log("Punkte", border.length, "lat", Math.min(...lats), Math.max(...lats), "lon", Math.min(...lons), Math.max(...lons));
console.log("Ausdehnung ca.", ((Math.max(...lons) - Math.min(...lons)) * 76600).toFixed(0), "x", ((Math.max(...lats) - Math.min(...lats)) * 110574).toFixed(0), "m");
fs.writeFileSync("tools/map_border.json", JSON.stringify({
  note: "Spielgrenze [lat, lon]: Marcos Kartenbild (map_border_fit.mjs), im Süden um die Berge erweitert, im Norden bis Villach (map_border_villach.mjs, Issue #17)",
  border,
}, null, 1));
console.log("tools/map_border.json geschrieben");

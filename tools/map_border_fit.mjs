// Einmalig: rote Spielgrenze aus Marcos Kartenbild (1742x784 px) in Geo-Koordinaten umrechnen.
// Bezugspunkte = Ortsbeschriftungen im Bild + Nominatim-Koordinaten.
import fs from "node:fs";
const ref = [
  [1346, 193, 46.56260, 13.81600], [1133, 601, 46.54614, 13.80374], [1358, 340, 46.55606, 13.81635],
  [979, 304, 46.55685, 13.79293], [913, 523, 46.54633, 13.78966], [741, 277, 46.55765, 13.78156],
  [689, 525, 46.54590, 13.77623], [600, 737, 46.53927, 13.77364], [303, 557, 46.54630, 13.75181],
  [580, 392, 46.55369, 13.77518], [775, 104, 46.56501, 13.78370], [1003, 556, 46.54902, 13.79595],
  [705, 466, 46.54913, 13.78065],
];
const fit = (xs, ys) => {
  const n = xs.length, mx = xs.reduce((a, b) => a + b) / n, my = ys.reduce((a, b) => a + b) / n;
  let sxy = 0, sxx = 0;
  for (let i = 0; i < n; i++) { sxy += (xs[i] - mx) * (ys[i] - my); sxx += (xs[i] - mx) ** 2; }
  const a = sxy / sxx; return [a, my - a * mx];
};
const [ax, bx] = fit(ref.map(r => r[0]), ref.map(r => r[3]));
const [ay, by] = fit(ref.map(r => r[1]), ref.map(r => r[2]));
let err = 0;
for (const r of ref) {
  const dx = (ax * r[0] + bx - r[3]) * 76600, dy = (ay * r[1] + by - r[2]) * 110574;
  err = Math.max(err, Math.hypot(dx, dy));
}
console.log("m/px x", (ax * 76600).toFixed(2), "y", (-ay * 110574).toFixed(2), "max Fehler", err.toFixed(0), "m");
// rote Linie, im Uhrzeigersinn ab oben
const px = [[1170,25],[1240,4],[1290,10],[1300,55],[1292,92],[1340,118],[1380,165],[1400,240],[1420,330],
  [1440,400],[1450,470],[1452,525],[1425,568],[1335,610],[1240,642],[1150,668],[1000,680],[850,675],[720,672],
  [600,682],[520,642],[452,592],[412,525],[400,462],[420,398],[468,333],[540,282],[640,240],[750,210],[830,180],
  [893,154],[932,168],[970,188],[1000,190],[1048,162],[1088,140],[1108,95],[1128,55]];
const border = px.map(([x, y]) => [+(ay * y + by).toFixed(6), +(ax * x + bx).toFixed(6)]);
fs.writeFileSync("tools/map_border.json", JSON.stringify({ note: "Spielgrenze [lat, lon], aus Marcos Kartenbild umgerechnet", border }, null, 1));
const lats = border.map(b => b[0]), lons = border.map(b => b[1]);
console.log("lat", Math.min(...lats), Math.max(...lats), "lon", Math.min(...lons), Math.max(...lons));
console.log("Groesse ca.", ((Math.max(...lons) - Math.min(...lons)) * 76600).toFixed(0), "x", ((Math.max(...lats) - Math.min(...lats)) * 110574).toFixed(0), "m");

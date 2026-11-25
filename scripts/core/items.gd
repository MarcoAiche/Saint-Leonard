class_name Items
extends RefCounted
## Alle Gegenstände, Preise und welcher Laden sie verkauft bzw. ankauft.
## kind: ammo, weapon, tool, drink, smoke, food, ingredient, placeable, furniture, loot, house, cargo

const SHOP_NAMES := {
	"gun": "Waffengeschäft",
	"super": "Supermarkt",
	"bauhaus": "Bauhaus",
	"gas": "Tankstelle",
	"butcher": "Fleischerei",
	"pub": "Gasthaus Pirtscher",
	"fire": "Feuerwehrhaus Korpitsch (Bar)",
}

const ITEMS := {
	# Waffen und Ausrüstung
	"pistol": {name = "Pistole", kind = "weapon", price = 450, shops = ["gun"]},
	"assault_rifle": {name = "Sturmgewehr", kind = "weapon", price = 1600, shops = ["gun"]},
	"sniper": {name = "Scharfschützengewehr", kind = "weapon", price = 2200, shops = ["gun"]},
	"ammo": {name = "Patronen (10 Stk.)", kind = "ammo", price = 25, shops = ["gun"], gives = 10},
	"scope8": {name = "Zielfernrohr 8x", kind = "tool", price = 350, shops = ["gun"]},
	"flashlight": {name = "Taschenlampe", kind = "tool", price = 35, shops = ["gun", "bauhaus"]},
	"knife": {name = "Jagdmesser", kind = "tool", price = 45, shops = ["gun"]},
	# Getränke, Rauchen, Essen
	"beer": {name = "Bier", kind = "drink", price = 3, shops = ["super", "gas", "pub", "fire"], alcohol = 0.03},
	"schnaps": {name = "Schnaps", kind = "drink", price = 9, shops = ["super", "pub", "fire"], alcohol = 0.07},
	"moonshine": {name = "Schwarzgebrannter", kind = "drink", price = 0, shops = [], alcohol = 0.16, illegal = true, sell = {pub = 45, gas = 30, fire = 40}},
	"cigarettes": {name = "Zigaretten (Packung)", kind = "smoke", price = 7, shops = ["super", "gas"], gives = 20},
	"snack": {name = "Wurstsemmel", kind = "food", price = 4, shops = ["super", "gas", "pub", "fire"], heal = 15, stamina = 30},
	"meat_cooked": {name = "Gegrilltes Wildfleisch", kind = "food", price = 0, shops = [], heal = 40, stamina = 60, sell = {pub = 25}},
	# Schnaps brennen
	"sugar": {name = "Zucker", kind = "ingredient", price = 3, shops = ["super"]},
	"yeast": {name = "Hefe", kind = "ingredient", price = 2, shops = ["super"]},
	"fruit": {name = "Obst (Kiste)", kind = "ingredient", price = 6, shops = ["super"]},
	"grain": {name = "Getreide (Sack)", kind = "ingredient", price = 5, shops = ["super"]},
	"jerrycan": {name = "Reservekanister (20 l)", kind = "tool", price = 45, shops = ["gas"]},
	# Bauhaus: zum Aufstellen
	"still": {name = "Brennkessel-Bausatz", kind = "placeable", price = 450, shops = ["bauhaus"]},
	"stand": {name = "Hochstand", kind = "placeable", price = 260, shops = ["bauhaus"]},
	"trailcam": {name = "Wildkamera", kind = "placeable", price = 90, shops = ["bauhaus"]},
	"campfire": {name = "Feuerstelle", kind = "placeable", price = 15, shops = ["bauhaus", "gas"]},
	"straps": {name = "Spanngurte", kind = "tool", price = 20, shops = ["bauhaus"]},
	"crate": {name = "Festkiste (Bier)", kind = "cargo", price = 30, shops = ["super"]},
	# Möbel
	"table": {name = "Tisch", kind = "furniture", price = 60, shops = ["bauhaus"]},
	"chair": {name = "Stuhl", kind = "furniture", price = 25, shops = ["bauhaus"]},
	"bed": {name = "Bett", kind = "furniture", price = 150, shops = ["bauhaus"]},
	"sofa": {name = "Sofa", kind = "furniture", price = 190, shops = ["bauhaus"]},
	"shelf": {name = "Regal", kind = "furniture", price = 70, shops = ["bauhaus"]},
	"lamp": {name = "Stehlampe", kind = "furniture", price = 35, shops = ["bauhaus"]},
	"rug": {name = "Teppich", kind = "furniture", price = 30, shops = ["bauhaus"]},
	"stove": {name = "Kachelofen", kind = "furniture", price = 320, shops = ["bauhaus"]},
	"frame": {name = "Fotorahmen", kind = "furniture", price = 8, shops = ["bauhaus"]},
	"frame_big": {name = "Großer Bilderrahmen", kind = "furniture", price = 25, shops = ["bauhaus"]},
	"chest": {name = "Holztruhe", kind = "furniture", price = 80, shops = ["bauhaus"]},
	"plant": {name = "Zimmerpflanze", kind = "furniture", price = 20, shops = ["bauhaus"]},
	# Beute
	"meat": {name = "Wildfleisch (roh)", kind = "loot", price = 0, shops = [], sell = {butcher = 55}},
	"hide": {name = "Fell", kind = "loot", price = 0, shops = [], sell = {butcher = 20}},
	"antlers": {name = "Geweih", kind = "loot", price = 0, shops = [], sell = {butcher = 40}},
	"tusks": {name = "Keilerwaffen", kind = "loot", price = 0, shops = [], sell = {butcher = 60}},
	"legend_antlers": {name = "Geweih des Riesenhirschs", kind = "loot", price = 0, shops = []},
	# Handwerk (zu Hause an der Werkbank)
	"trophy": {name = "Trophäe (Wandschild)", kind = "furniture", price = 0, shops = []},
	"trophy_boar": {name = "Keilerkopf (Wandschild)", kind = "furniture", price = 0, shops = []},
	"pelt_rug": {name = "Fellteppich", kind = "furniture", price = 0, shops = []},
	"jacket": {name = "Lederjacke", kind = "outfit", price = 0, shops = []},
	"hunter_hat": {name = "Jägerhut mit Gamsbart", kind = "outfit", price = 0, shops = []},
}

## Rezepte für die Werkbank zu Hause: Ergebnis -> benötigte Teile
const RECIPES := {
	"trophy": {antlers = 1},
	"trophy_boar": {tusks = 1, hide = 1},
	"pelt_rug": {hide = 2},
	"jacket": {hide = 3},
	"hunter_hat": {hide = 1, tusks = 1},
	"meat_cooked": {meat = 1},
}

## Häuser im Bauhaus-Katalog (Bauplätze in Saint Leonard)
const HOUSES := [
	{name = "Holzhütte", price = 2500, size = Vector2(6, 5), levels = 1, wall = Color(0.62, 0.42, 0.26), roof = Color(0.35, 0.22, 0.15)},
	{name = "Kleines Häuschen", price = 4200, size = Vector2(7, 6), levels = 1, wall = Color(0.95, 0.92, 0.84), roof = Color(0.62, 0.22, 0.17)},
	{name = "Jägerhaus", price = 6500, size = Vector2(8, 7), levels = 1, wall = Color(0.78, 0.68, 0.52), roof = Color(0.30, 0.30, 0.33)},
	{name = "Bungalow", price = 8000, size = Vector2(11, 8), levels = 1, wall = Color(0.93, 0.93, 0.93), roof = Color(0.40, 0.40, 0.44)},
	{name = "Kärntner Bauernhaus", price = 11000, size = Vector2(10, 8), levels = 2, wall = Color(0.98, 0.95, 0.86), roof = Color(0.55, 0.20, 0.15)},
	{name = "Almhaus", price = 12500, size = Vector2(9, 9), levels = 2, wall = Color(0.60, 0.40, 0.24), roof = Color(0.32, 0.32, 0.34)},
	{name = "Einfamilienhaus", price = 15000, size = Vector2(10, 9), levels = 2, wall = Color(0.96, 0.88, 0.70), roof = Color(0.65, 0.25, 0.18)},
	{name = "Haus mit Garage", price = 18500, size = Vector2(13, 9), levels = 2, wall = Color(0.88, 0.92, 0.95), roof = Color(0.36, 0.36, 0.40)},
	{name = "Landhaus", price = 24000, size = Vector2(14, 10), levels = 2, wall = Color(0.98, 0.94, 0.82), roof = Color(0.58, 0.22, 0.16)},
	{name = "Villa am Feld", price = 35000, size = Vector2(16, 12), levels = 2, wall = Color(1.0, 1.0, 0.98), roof = Color(0.25, 0.25, 0.28)},
]

## Werkstatt-Umbauten am Pickup
const UPGRADES := {
	"mud_tires": {name = "Geländereifen (Matsch)", price = 600},
	"lift": {name = "Höherlegung + Fahrwerk", price = 900},
	"bullbar": {name = "Rammschutz", price = 350},
	"spotlights": {name = "Dachscheinwerfer", price = 400},
	"roof_rack": {name = "Dachträger", price = 250},
	"exhaust": {name = "Sportauspuff (laut)", price = 300},
	"winch": {name = "Seilwinde", price = 700},
	"armor": {name = "Unterfahrschutz", price = 500},
}

const PAINTS := [
	["Rot", Color(0.72, 0.16, 0.12)], ["Jagdgrün", Color(0.22, 0.34, 0.20)], ["Schwarz", Color(0.12, 0.12, 0.13)],
	["Weiß", Color(0.92, 0.92, 0.90)], ["Blau", Color(0.16, 0.32, 0.62)], ["Sandbeige", Color(0.72, 0.62, 0.45)],
	["Orange", Color(0.92, 0.45, 0.10)], ["Tarnbraun", Color(0.40, 0.30, 0.20)],
]


static func info(id: String) -> Dictionary:
	return ITEMS.get(id, {name = id, kind = "loot", price = 0, shops = []})


static func display(id: String) -> String:
	return info(id).name


## Was ein Laden verkauft
static func stock(shop: String) -> Array:
	var out := []
	for id in ITEMS:
		if shop in ITEMS[id].shops:
			out.append(id)
	return out


## Was ein Laden ankauft: [[id, preis], ...]
static func buys(shop: String) -> Array:
	var out := []
	for id in ITEMS:
		var s: Dictionary = ITEMS[id].get("sell", {})
		if s.has(shop):
			out.append([id, s[shop]])
	return out

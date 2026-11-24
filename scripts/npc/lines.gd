class_name NpcLines
extends RefCounted
## Sprüche der Leute in Saint Leonard (Kärntner Einschlag). Werden als Sprechblase gezeigt.

const LINES := {
	"Wirt Sepp": ["Griaß di! A Bier geht imma.", "Wanns Gasthaus zuasperrt, wo sauf ma dann?", "Da Inspektor kann mi gern haben.", "Hearst, du riachst noch Pulverdampf!", "Heit is a guater Tag zum Bleiben."],
	"Kommandant Ferdl": ["Bei uns brennt nur da Schnaps.", "Pokern? Do? Na, nie. ... Ab zwanzig Uhr.", "Wer am lautesten is, holt de Polizei.", "Des Löschauto fahrt eh nimma, oba es schaut guat aus.", "Prost, Kameraden!"],
	"Tankwart Hias": ["Volltanken? Oder nur a Bier?", "De Zigaretten san fia di heit billiger. Nein, doch ned.", "I hob nix gsehn, i hob nix ghört.", "Hast a Mutprobe gfällig?"],
	"Fleischer Franz": ["Schee frisches Wildbret!", "Na, wieder an Rehbock?", "De Keilerwaffen nimm i a.", "Blut an da Jacke steht da guat."],
	"Mechaniker Gust": ["Mehr Stollen, mehr Spaß.", "Wer ko, der ko. Wer ned ko, braucht a Seilwinde.", "Den Auspuff hört ma bis Villach!", "Gib Gas, i repariers eh."],
	"Kassiererin": ["Haben Sie eine Kundenkarte?", "Zucker und Hefe? Backen Sie was?", "Schönen Tag noch!"],
	"Büchsenmacher": ["Waidmannsheil!", "Ruhig atmen, dann triffst a.", "Patronen san ka Spielzeug. Außer für di."],
	"Bauhaus-Verkäufer": ["Wenn's um Kessel geht ... äh, um Ihr Zuhause!", "Hochstand im Angebot!"],
	"Polizei": ["Fahrzeugkontrolle, bitte anhalten.", "Haben Sie was getrunken?", "Schöner Tag, gell?"],
	"Polizeiinspektion": ["Strafen zahlen ist auch eine Bürgerpflicht."],
	"": ["Servus!", "Griaß enk!", "Heast, schiaß ma ned in de Hendln!", "Is des Ihr Pickup? Der is ja voller Matsch!", "Wos is des fia a Gestank? Ah, Schnaps."],
}


static func pick(npc_name: String, rng: RandomNumberGenerator) -> String:
	var list: Array = LINES.get(npc_name, LINES[""])
	return list[rng.randi() % list.size()]

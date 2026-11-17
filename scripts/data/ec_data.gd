extends RefCounted
## Dati di Eclipse — Seconda Alba per la Galassia: settori, tecnologie, parti delle navi, scoperte,
## specie e progetti delle navi neutrali. Trascritti dal modulo di Tabletop Simulator (tessere, plance
## e regolamento). Gli identificativi interni restano in inglese, i nomi mostrati sono in italiano.

# ------------------------------------------------------------------ esagoni
## Esagoni con il lato piatto in alto. Lati: 0 nord, 1 nord-est, 2 sud-est, 3 sud, 4 sud-ovest, 5 nord-ovest.
const DIRS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]

## Posizioni di partenza (anello II, sulle sei «punte») per numero di giocatori.
const START_SLOTS := {2: [0, 3], 3: [0, 2, 4], 4: [0, 1, 3, 4], 5: [0, 1, 2, 3, 4], 6: [0, 1, 2, 3, 4, 5]}
const OUTER_COUNT := {2: 5, 3: 8, 4: 14, 5: 16, 6: 18}
const TECH_START := {2: 12, 3: 14, 4: 16, 5: 18, 6: 20}
const TECH_ROUND := {2: 4, 3: 6, 4: 7, 5: 8, 6: 9}
const MAX_DIST := 4                     # gli anelli esterni possono allargarsi fino a qui
const ROUNDS := 8

# ------------------------------------------------------------------ risorse e tracciati
const RES := ["m", "s", "$"]
const RES_NAME := {"m": "Materiali", "s": "Scienza", "$": "Denaro"}
const RES_SHORT := {"m": "Mat", "s": "Sci", "$": "Den"}
const POP_VALUES := [2, 3, 4, 6, 8, 10, 12, 15, 18, 21, 24, 28]
const POP_START := 11                   # cubetti sul tracciato all'inizio (caselle 3-28)
const INF_VALUES := [0, 0, 1, 2, 3, 5, 7, 10, 13, 17, 21, 25, 30]
const INF_SPACES := 13
const DISC_TOTAL := 16
const TECH_DISCOUNT := [0, 1, 2, 3, 4, 6, 8]
const TECH_VP := [0, 0, 0, 0, 1, 2, 3, 5]
const SHIP_LIMIT := {"int": 8, "cru": 4, "dre": 2, "sb": 4}
const SHIP_NAME := {"int": "Intercettore", "cru": "Incrociatore", "dre": "Corazzata", "sb": "Base stellare"}
const SHIP_PLURAL := {"int": "Intercettori", "cru": "Incrociatori", "dre": "Corazzate", "sb": "Basi stellari"}
const SHIP_TYPES := ["int", "cru", "dre", "sb"]
const SHIP_REP := {"int": 1, "cru": 2, "dre": 3, "sb": 1, "anc": 1, "gua": 2, "gcds": 3}
const SHIP_SIZE := {"int": 1, "sb": 2, "cru": 3, "dre": 4, "anc": 2, "gua": 3, "gcds": 5}
const REP_BAG := {1: 12, 2: 10, 3: 7, 4: 4}

const ACTIONS := ["exp", "res", "upg", "bui", "mov", "inf"]
const ACTION_NAME := {"exp": "Esplorare", "res": "Ricercare", "upg": "Potenziare", "bui": "Costruire", "mov": "Muovere", "inf": "Influenzare"}
const ACTION_SHORT := {"exp": "ESP", "res": "RIC", "upg": "POT", "bui": "COS", "mov": "MUO", "inf": "INF"}

const COLORS := [
	{"id": "red", "name": "Rosso", "c": Color("#d8352f")},
	{"id": "blue", "name": "Blu", "c": Color("#2f7fe0")},
	{"id": "green", "name": "Verde", "c": Color("#3fae4a")},
	{"id": "yellow", "name": "Giallo", "c": Color("#f2c230")},
	{"id": "white", "name": "Bianco", "c": Color("#e8ecf2")},
	{"id": "black", "name": "Nero", "c": Color("#3a3d46")},
]
## Ogni colore ha una plancia a due facce: fazione terrestre o specie aliena.
const COLOR_SPECIES := [["terran_directorate", "eridani"], ["terran_federation", "hydran"], ["terran_union", "planta"],
	["terran_republic", "draco"], ["terran_conglomerate", "mechanema"], ["terran_alliance", "orion"]]

# ------------------------------------------------------------------ settori
## pl: pianeti ("$" denaro, "s" scienza, "m" materiali, "g" grigio; "*" = avanzato)
## wh: wormhole sui sei lati (orientamento della tessera stampata); disc: tessera scoperta;
## anc: Antichi; art: artefatto; warp: portale di curvatura; npc: guardiano o SDCG
const SECTORS := {
	1: {"name": "Centro Galattico", "ring": 0, "vp": 4, "wh": [1, 1, 1, 1, 1, 1], "pl": ["s*", "s", "m*", "m", "$", "$"], "disc": true, "art": true, "npc": "gcds"},
	101: {"name": "Castor", "ring": 1, "vp": 2, "wh": [0, 1, 1, 1, 1, 1], "pl": ["m*", "m", "$"], "disc": true, "anc": 1},
	102: {"name": "Pollux", "ring": 1, "vp": 2, "wh": [1, 0, 1, 1, 0, 1], "pl": ["s", "s"]},
	103: {"name": "Beta Leonis", "ring": 1, "vp": 2, "wh": [1, 1, 1, 0, 1, 1], "pl": ["s", "$"]},
	104: {"name": "Arcturus", "ring": 1, "vp": 2, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$*", "$", "s*", "s"], "disc": true, "anc": 2},
	105: {"name": "Zeta Herculis", "ring": 1, "vp": 2, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$", "s", "m*"], "disc": true, "anc": 1},
	106: {"name": "Capella", "ring": 1, "vp": 2, "wh": [1, 1, 1, 1, 0, 0], "pl": ["s", "m"]},
	107: {"name": "Aldebaran", "ring": 1, "vp": 3, "wh": [1, 1, 1, 1, 0, 1], "pl": ["s*", "$", "m*"], "art": true},
	108: {"name": "Mu Cassiopeiae", "ring": 1, "vp": 2, "wh": [1, 1, 0, 1, 1, 0], "pl": ["s", "$*", "g"], "disc": true, "anc": 1},
	109: {"name": "Alpha Lacertae", "ring": 1, "vp": 4, "wh": [0, 1, 1, 1, 1, 1], "pl": ["m", "$"], "disc": true, "anc": 2, "art": true},
	110: {"name": "Iota Bootis", "ring": 1, "vp": 2, "wh": [1, 0, 1, 1, 1, 0], "pl": ["$*", "g*"], "disc": true},
	201: {"name": "Alpha Centauri", "ring": 2, "vp": 1, "wh": [0, 1, 0, 1, 0, 1], "pl": ["m", "$"]},
	202: {"name": "Fomalhaut", "ring": 2, "vp": 2, "wh": [0, 1, 0, 1, 0, 1], "pl": ["s*", "s"], "art": true},
	203: {"name": "Chi Draconis", "ring": 2, "vp": 2, "wh": [1, 1, 0, 1, 0, 1], "pl": ["m", "$*", "s"], "disc": true, "anc": 2},
	204: {"name": "Vega", "ring": 2, "vp": 2, "wh": [1, 1, 0, 1, 0, 1], "pl": ["$*", "g", "m*"], "disc": true, "anc": 1, "art": true},
	205: {"name": "Mu Herculis", "ring": 2, "vp": 1, "wh": [0, 0, 1, 1, 1, 0], "pl": ["$*", "$", "s*"], "art": true},
	206: {"name": "Epsilon Indi", "ring": 2, "vp": 1, "wh": [0, 1, 1, 1, 0, 1], "pl": ["m"], "disc": true},
	207: {"name": "Zeta Reticuli", "ring": 2, "vp": 2, "wh": [1, 1, 0, 1, 0, 0], "pl": [], "disc": true},
	208: {"name": "Iota Persei", "ring": 2, "vp": 2, "wh": [1, 0, 1, 1, 0, 1], "pl": [], "disc": true},
	209: {"name": "Delta Eridani", "ring": 2, "vp": 1, "wh": [1, 1, 0, 1, 0, 1], "pl": ["$", "s"]},
	210: {"name": "Psi Capricorni", "ring": 2, "vp": 1, "wh": [1, 0, 0, 1, 0, 1], "pl": ["$", "m"]},
	211: {"name": "Beta Aquilae", "ring": 2, "vp": 1, "wh": [1, 1, 1, 1, 0, 0], "pl": ["$", "g", "m*"], "disc": true, "anc": 1},
	214: {"name": "Beta Monocerotis", "ring": 2, "vp": 2, "wh": [1, 1, 1, 0, 1, 1], "pl": ["g*", "m*", "s"], "disc": true, "anc": 1},
	281: {"name": "Delta Corvi", "ring": 2, "vp": 2, "wh": [1, 0, 1, 1, 0, 1], "pl": ["s", "$"], "disc": true, "warp": true},
	301: {"name": "Zeta Draconis", "ring": 3, "vp": 2, "wh": [1, 0, 1, 1, 0, 0], "pl": ["$", "s", "m*"], "disc": true, "anc": 2, "art": true},
	302: {"name": "Gamma Serpentis", "ring": 3, "vp": 2, "wh": [1, 0, 0, 1, 1, 0], "pl": ["s*", "$*", "m"], "disc": true, "anc": 1, "art": true},
	303: {"name": "Eta Cephei", "ring": 3, "vp": 2, "wh": [0, 0, 0, 1, 0, 1], "pl": ["g", "s*", "$*"], "disc": true, "anc": 1, "art": true},
	304: {"name": "Theta Pegasi", "ring": 3, "vp": 2, "wh": [1, 0, 0, 1, 0, 0], "pl": ["$*", "m"]},
	305: {"name": "Lambda Serpentis", "ring": 3, "vp": 1, "wh": [1, 1, 0, 1, 0, 0], "pl": ["s", "m"], "disc": true, "anc": 1},
	306: {"name": "Beta Centauri", "ring": 3, "vp": 1, "wh": [0, 1, 0, 1, 0, 0], "pl": ["$", "m"]},
	307: {"name": "Sigma Sagittarii", "ring": 3, "vp": 2, "wh": [1, 0, 1, 1, 0, 0], "pl": ["$", "s*"]},
	308: {"name": "Kappa Scorpii", "ring": 3, "vp": 2, "wh": [0, 0, 1, 1, 0, 1], "pl": ["s", "m*"]},
	309: {"name": "Phi Piscium", "ring": 3, "vp": 2, "wh": [1, 0, 0, 1, 0, 1], "pl": ["$", "s*"]},
	310: {"name": "Nu Phoenicis", "ring": 3, "vp": 1, "wh": [1, 0, 0, 1, 0, 0], "pl": ["s", "m"]},
	311: {"name": "Canopus", "ring": 3, "vp": 1, "wh": [1, 0, 1, 1, 0, 0], "pl": ["m"], "disc": true},
	312: {"name": "Antares", "ring": 3, "vp": 1, "wh": [1, 1, 0, 1, 0, 0], "pl": ["m"], "disc": true},
	313: {"name": "Alpha Ursae Minoris", "ring": 3, "vp": 1, "wh": [1, 0, 0, 1, 0, 0], "pl": ["g"], "disc": true},
	314: {"name": "Spica", "ring": 3, "vp": 1, "wh": [0, 0, 1, 1, 1, 0], "pl": ["g"], "disc": true},
	315: {"name": "Epsilon Aurigae", "ring": 3, "vp": 1, "wh": [1, 0, 0, 1, 0, 1], "pl": [], "disc": true},
	316: {"name": "Iota Carinae", "ring": 3, "vp": 1, "wh": [1, 1, 0, 1, 0, 0], "pl": [], "disc": true},
	317: {"name": "Beta Crucis", "ring": 3, "vp": 2, "wh": [0, 0, 0, 1, 1, 0], "pl": ["$*", "$"]},
	318: {"name": "Gamma Velorum", "ring": 3, "vp": 1, "wh": [0, 0, 1, 1, 0, 0], "pl": ["g", "m*"]},
	381: {"name": "Zeta Sextantis", "ring": 3, "vp": 1, "wh": [1, 0, 0, 1, 1, 0], "pl": ["m", "$"], "disc": true, "warp": true},
	382: {"name": "Zeta Chamaeleontis", "ring": 3, "vp": 1, "wh": [1, 0, 1, 1, 0, 0], "pl": ["s", "m"], "disc": true, "warp": true},
	# settori di partenza (la freccia, sul lato 0, guarda il Centro Galattico)
	221: {"name": "Procyon", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$*", "$", "s*", "s", "m"], "art": true, "home": true},
	222: {"name": "Epsilon Eridani", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$*", "$", "s*", "s"], "art": true, "home": true},
	223: {"name": "Altair", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$*", "$", "s*", "s", "m"], "art": true, "home": true},
	224: {"name": "Beta Hydri", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$", "s*", "m*"], "art": true, "home": true},
	225: {"name": "Eta Cassiopeiae", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$*", "$", "s*", "s", "m"], "art": true, "home": true},
	226: {"name": "61 Cygni", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["s", "m"], "art": true, "home": true},
	227: {"name": "Sirius", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$*", "$", "s*", "s", "m"], "art": true, "home": true},
	228: {"name": "Sigma Draconis", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$", "s", "m*"], "art": true, "home": true},
	229: {"name": "Tau Ceti", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$*", "$", "s*", "s", "m"], "art": true, "home": true},
	230: {"name": "Lambda Aurigae", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$*", "$", "s", "m*"], "art": true, "home": true},
	231: {"name": "Delta Pavonis", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$*", "$", "s*", "s", "m"], "art": true, "home": true},
	232: {"name": "Rigel", "ring": 2, "vp": 3, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$*", "s", "m*", "m"], "art": true, "home": true},
	# settori dei Guardiani (nelle zone di partenza libere)
	271: {"name": "Omega Fornacis", "ring": 2, "vp": 2, "wh": [1, 1, 0, 1, 1, 0], "pl": ["m*", "$", "s"], "disc": true, "art": true, "npc": "gua"},
	272: {"name": "Sigma Hydrae", "ring": 2, "vp": 2, "wh": [1, 1, 0, 1, 1, 0], "pl": ["$", "s*", "m"], "disc": true, "art": true, "npc": "gua"},
	273: {"name": "Theta Ophiuchi", "ring": 2, "vp": 2, "wh": [1, 1, 0, 1, 1, 0], "pl": ["m*", "m", "$"], "disc": true, "art": true, "npc": "gua"},
	274: {"name": "Alpha Lyncis", "ring": 2, "vp": 2, "wh": [1, 1, 0, 1, 1, 0], "pl": ["s*", "s", "$"], "disc": true, "art": true, "npc": "gua"},
}
const STACK_I := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
const STACK_II := [201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 214, 281]
const STACK_III := [301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 318, 381, 382]
const GUARDIANS := [271, 272, 273, 274]

# ------------------------------------------------------------------ parti delle navi
## en: energia (+ prodotta, - consumata); comp: computer; sh: scudi; hull: scafo; mv: movimento;
## ini: iniziativa; can: dadi dei cannoni; mis: dadi dei missili; tech: tecnologia richiesta;
## anc: parte antica (da una scoperta, se tolta esce dal gioco)
## Dadi: y giallo (1 danno), o arancione (2), b blu (3), r rosso (4), x squarcio.
const PARTS := {
	"ion_cannon": {"name": "Cannone ionico", "en": -1, "can": ["y"]},
	"plasma_cannon": {"name": "Cannone al plasma", "en": -2, "can": ["o"], "tech": "plasma_cannon"},
	"soliton_cannon": {"name": "Cannone a solitoni", "en": -3, "can": ["b"], "tech": "soliton_cannon"},
	"antimatter_cannon": {"name": "Cannone ad antimateria", "en": -4, "can": ["r"], "tech": "antimatter_cannon"},
	"rift_cannon": {"name": "Cannone a squarcio", "en": -2, "can": ["x"], "tech": "rift_cannon"},
	"plasma_missile": {"name": "Missile al plasma", "en": -1, "mis": ["o", "o"], "tech": "plasma_missile"},
	"flux_missile": {"name": "Missile a flusso", "en": 0, "ini": 1, "mis": ["y", "y"], "tech": "flux_missile"},
	"electron_computer": {"name": "Computer a elettroni", "en": 0, "comp": 1},
	"positron_computer": {"name": "Computer a positroni", "en": -1, "comp": 2, "tech": "positron_computer"},
	"gluon_computer": {"name": "Computer a gluoni", "en": -2, "comp": 3, "tech": "gluon_computer"},
	"gauss_shield": {"name": "Scudo di Gauss", "en": 0, "sh": 1, "tech": "gauss_shield"},
	"phase_shield": {"name": "Scudo di fase", "en": -1, "sh": 2, "tech": "phase_shield"},
	"absorption_shield": {"name": "Scudo ad assorbimento", "en": 4, "sh": 1, "tech": "absorption_shield"},
	"hull": {"name": "Scafo", "en": 0, "hull": 1},
	"improved_hull": {"name": "Scafo migliorato", "en": 0, "hull": 2, "tech": "improved_hull"},
	"conifold_field": {"name": "Campo conifold", "en": -2, "hull": 3, "tech": "conifold_field"},
	"sentient_hull": {"name": "Scafo senziente", "en": 0, "comp": 1, "hull": 1, "tech": "sentient_hull"},
	"nuclear_drive": {"name": "Propulsore nucleare", "en": -1, "mv": 1, "ini": 1},
	"fusion_drive": {"name": "Propulsore a fusione", "en": -2, "mv": 2, "ini": 2, "tech": "fusion_drive"},
	"tachyon_drive": {"name": "Propulsore a tachioni", "en": -3, "mv": 3, "ini": 3, "tech": "tachyon_drive"},
	"transition_drive": {"name": "Propulsore di transizione", "en": 0, "mv": 3, "tech": "transition_drive"},
	"nuclear_source": {"name": "Generatore nucleare", "en": 3},
	"fusion_source": {"name": "Generatore a fusione", "en": 6, "tech": "fusion_source"},
	"tachyon_source": {"name": "Generatore a tachioni", "en": 9, "tech": "tachyon_source"},
	"zero_point_source": {"name": "Generatore a punto zero", "en": 12, "tech": "zero_point_source"},
	# parti antiche (scoperte)
	"soliton_missile": {"name": "Missile a solitoni", "en": 0, "ini": 1, "mis": ["b"], "anc": true, "img": "0e83dbb1"},
	"antimatter_missile": {"name": "Missile ad antimateria", "en": 0, "mis": ["r"], "anc": true, "img": "0ea4e637"},
	"ion_turret": {"name": "Torretta ionica", "en": 0, "can": ["y", "y"], "anc": true, "img": "139838af"},
	"hypergrid_source": {"name": "Generatore iperreticolare", "en": 11, "anc": true, "img": "15638638"},
	"muon_source": {"name": "Generatore a muoni", "en": 2, "ini": 1, "anc": true, "outside": true, "img": "486917ff"},
	"nonlinear_drive": {"name": "Propulsore non lineare", "en": 2, "mv": 2, "anc": true, "img": "4e9a3f39"},
	"soliton_charger": {"name": "Caricatore a solitoni", "en": -1, "can": ["b"], "anc": true, "img": "51ef67ef"},
	"inversion_shield": {"name": "Scudo a inversione", "en": 2, "sh": 2, "anc": true, "img": "543abfd0"},
	"shard_hull": {"name": "Scafo a schegge", "en": 0, "hull": 3, "anc": true, "img": "6705b886"},
	"rift_conductor": {"name": "Conduttore a squarcio", "en": -1, "hull": 1, "can": ["x"], "anc": true, "img": "6e9b218f"},
	"flux_shield": {"name": "Scudo a flusso", "en": -2, "sh": 3, "ini": 1, "anc": true, "img": "7d278f38"},
	"morph_shield": {"name": "Scudo mutaforma", "en": 0, "sh": 1, "ini": 1, "regen": 1, "anc": true, "img": "84cea3d2"},
	"plasma_turret": {"name": "Torretta al plasma", "en": -3, "can": ["o", "o"], "anc": true, "img": "b60cf36f"},
	"ion_disruptor": {"name": "Distruttore ionico", "en": 0, "ini": 3, "can": ["y"], "anc": true, "img": "c8112916"},
	"axion_computer": {"name": "Computer ad assioni", "en": 0, "comp": 2, "ini": 1, "anc": true, "img": "e02ee2a3"},
	"conformal_drive": {"name": "Propulsore conforme", "en": -2, "mv": 4, "ini": 2, "anc": true, "img": "e1393b64"},
	"ion_missile": {"name": "Missile ionico", "en": 0, "mis": ["y", "y", "y"], "anc": true, "img": "f2ca3094"},
}
const DIE_DMG := {"y": 1, "o": 2, "b": 3, "r": 4}
const DIE_NAME := {"y": "ionico", "o": "al plasma", "b": "a solitoni", "r": "ad antimateria", "x": "a squarcio"}
const DIE_COLOR := {"y": Color("#f2c230"), "o": Color("#f08a24"), "b": Color("#2f86d8"), "r": Color("#d8352f"), "x": Color("#d64fb4")}
## Facce del dado a squarcio: [danno al bersaglio, danno a sé]
const RIFT_FACES := [[1, 0], [2, 0], [3, 1], [0, 1], [0, 0], [0, 0]]

# ------------------------------------------------------------------ tecnologie
## cat: mil (militari), grid (reticolo), nano, rare; kind: part, build, instant, perm
const TECHS := {
	"neutron_bombs": {"name": "Bombe a neutroni", "cat": "mil", "cost": 2, "min": 2, "n": 5, "kind": "perm", "txt": "Quando attacchi la popolazione, distruggi automaticamente tutti i cubetti del settore."},
	"starbase": {"name": "Base stellare", "cat": "mil", "cost": 4, "min": 3, "n": 5, "kind": "build", "txt": "Puoi costruire basi stellari."},
	"plasma_cannon": {"name": "Cannone al plasma", "cat": "mil", "cost": 6, "min": 4, "n": 5, "kind": "part", "txt": "Puoi montare cannoni al plasma (dado arancione, 2 danni)."},
	"phase_shield": {"name": "Scudo di fase", "cat": "mil", "cost": 8, "min": 5, "n": 5, "kind": "part", "txt": "Puoi montare scudi di fase (-2)."},
	"advanced_mining": {"name": "Estrazione avanzata", "cat": "mil", "cost": 10, "min": 6, "n": 4, "kind": "perm", "txt": "Puoi colonizzare i pianeti avanzati dei materiali."},
	"tachyon_source": {"name": "Generatore a tachioni", "cat": "mil", "cost": 12, "min": 6, "n": 3, "kind": "part", "txt": "Puoi montare generatori a tachioni (+9 energia)."},
	"gluon_computer": {"name": "Computer a gluoni", "cat": "mil", "cost": 14, "min": 7, "n": 3, "kind": "part", "txt": "Puoi montare computer a gluoni (+3)."},
	"plasma_missile": {"name": "Missile al plasma", "cat": "mil", "cost": 16, "min": 8, "n": 3, "kind": "part", "txt": "Puoi montare missili al plasma (2 dadi arancioni prima della battaglia)."},
	"gauss_shield": {"name": "Scudo di Gauss", "cat": "grid", "cost": 2, "min": 2, "n": 5, "kind": "part", "txt": "Puoi montare scudi di Gauss (-1)."},
	"fusion_source": {"name": "Generatore a fusione", "cat": "grid", "cost": 4, "min": 3, "n": 5, "kind": "part", "txt": "Puoi montare generatori a fusione (+6 energia)."},
	"improved_hull": {"name": "Scafo migliorato", "cat": "grid", "cost": 6, "min": 4, "n": 5, "kind": "part", "txt": "Puoi montare scafi migliorati (+2 scafo)."},
	"positron_computer": {"name": "Computer a positroni", "cat": "grid", "cost": 8, "min": 5, "n": 5, "kind": "part", "txt": "Puoi montare computer a positroni (+2)."},
	"advanced_economy": {"name": "Economia avanzata", "cat": "grid", "cost": 10, "min": 6, "n": 4, "kind": "perm", "txt": "Puoi colonizzare i pianeti avanzati del denaro."},
	"tachyon_drive": {"name": "Propulsore a tachioni", "cat": "grid", "cost": 12, "min": 6, "n": 3, "kind": "part", "txt": "Puoi montare propulsori a tachioni (movimento 3, iniziativa +3)."},
	"antimatter_cannon": {"name": "Cannone ad antimateria", "cat": "grid", "cost": 14, "min": 7, "n": 3, "kind": "part", "txt": "Puoi montare cannoni ad antimateria (dado rosso, 4 danni)."},
	"quantum_grid": {"name": "Rete quantistica", "cat": "grid", "cost": 16, "min": 8, "n": 3, "kind": "instant", "txt": "Ricevi subito due dischi influenza in più."},
	"nanorobots": {"name": "Nanorobot", "cat": "nano", "cost": 2, "min": 2, "n": 5, "kind": "perm", "txt": "Un'attivazione in più a ogni azione Costruire."},
	"fusion_drive": {"name": "Propulsore a fusione", "cat": "nano", "cost": 4, "min": 3, "n": 5, "kind": "part", "txt": "Puoi montare propulsori a fusione (movimento 2, iniziativa +2)."},
	"orbital": {"name": "Orbitale", "cat": "nano", "cost": 6, "min": 4, "n": 5, "kind": "build", "txt": "Puoi costruire orbitali (una casella popolazione in più per scienza o denaro)."},
	"advanced_robotics": {"name": "Robotica avanzata", "cat": "nano", "cost": 8, "min": 5, "n": 5, "kind": "instant", "txt": "Ricevi subito un disco influenza in più."},
	"advanced_labs": {"name": "Laboratori avanzati", "cat": "nano", "cost": 10, "min": 6, "n": 4, "kind": "perm", "txt": "Puoi colonizzare i pianeti avanzati della scienza."},
	"monolith": {"name": "Monolito", "cat": "nano", "cost": 12, "min": 6, "n": 3, "kind": "build", "txt": "Puoi costruire monoliti (3 PV a fine partita)."},
	"wormhole_generator": {"name": "Generatore di wormhole", "cat": "nano", "cost": 14, "min": 7, "n": 3, "kind": "perm", "txt": "Puoi esplorare, muovere e influenzare anche dove c'è un solo wormhole fra i due settori."},
	"artifact_key": {"name": "Chiave degli artefatti", "cat": "nano", "cost": 16, "min": 8, "n": 3, "kind": "instant", "txt": "Per ogni artefatto nei tuoi settori ricevi subito 5 risorse di un solo tipo."},
	"absorption_shield": {"name": "Scudo ad assorbimento", "cat": "rare", "cost": 7, "min": 6, "n": 1, "kind": "part", "txt": "Puoi montare scudi ad assorbimento (-1, +4 energia)."},
	"ancient_labs": {"name": "Laboratori antichi", "cat": "rare", "cost": 13, "min": 9, "n": 1, "kind": "instant", "txt": "Pesca e risolvi subito una tessera scoperta."},
	"antimatter_splitter": {"name": "Divisore di antimateria", "cat": "rare", "cost": 5, "min": 5, "n": 1, "kind": "perm", "txt": "I danni dei cannoni ad antimateria si dividono liberamente fra i bersagli colpiti."},
	"cloaking_device": {"name": "Dispositivo di occultamento", "cat": "rare", "cost": 7, "min": 6, "n": 1, "kind": "perm", "txt": "Servono due navi avversarie per bloccare ciascuna delle tue navi."},
	"conifold_field": {"name": "Campo conifold", "cat": "rare", "cost": 5, "min": 5, "n": 1, "kind": "part", "txt": "Puoi montare campi conifold (+3 scafo, 2 energia)."},
	"flux_missile": {"name": "Missile a flusso", "cat": "rare", "cost": 11, "min": 8, "n": 1, "kind": "part", "txt": "Puoi montare missili a flusso (2 dadi gialli, iniziativa +1, senza energia)."},
	"improved_logistics": {"name": "Logistica migliorata", "cat": "rare", "cost": 7, "min": 6, "n": 1, "kind": "perm", "txt": "Un'attivazione in più a ogni azione Muovere."},
	"metasynthesis": {"name": "Metasintesi", "cat": "rare", "cost": 17, "min": 11, "n": 1, "kind": "perm", "txt": "Puoi colonizzare qualsiasi pianeta avanzato."},
	"neutron_absorber": {"name": "Assorbitore di neutroni", "cat": "rare", "cost": 5, "min": 5, "n": 1, "kind": "perm", "txt": "Le bombe a neutroni nemiche non hanno effetto su di te."},
	"pico_modulator": {"name": "Picomodulatore", "cat": "rare", "cost": 11, "min": 8, "n": 1, "kind": "perm", "txt": "Due attivazioni in più a ogni azione Potenziare."},
	"rift_cannon": {"name": "Cannone a squarcio", "cat": "rare", "cost": 9, "min": 7, "n": 1, "kind": "part", "txt": "Puoi montare cannoni a squarcio: ignorano computer e scudi, ma possono ritorcersi contro di te."},
	"sentient_hull": {"name": "Scafo senziente", "cat": "rare", "cost": 7, "min": 6, "n": 1, "kind": "part", "txt": "Puoi montare scafi senzienti (+1 computer, +1 scafo)."},
	"soliton_cannon": {"name": "Cannone a solitoni", "cat": "rare", "cost": 9, "min": 7, "n": 1, "kind": "part", "txt": "Puoi montare cannoni a solitoni (dado blu, 3 danni)."},
	"transition_drive": {"name": "Propulsore di transizione", "cat": "rare", "cost": 9, "min": 7, "n": 1, "kind": "part", "txt": "Puoi montare propulsori di transizione (movimento 3, senza energia)."},
	"warp_portal": {"name": "Portale di curvatura", "cat": "rare", "cost": 9, "min": 7, "n": 1, "kind": "instant", "txt": "Metti subito il portale in un tuo settore: lo collega a tutti gli altri portali e vale 1 PV."},
	"zero_point_source": {"name": "Generatore a punto zero", "cat": "rare", "cost": 15, "min": 10, "n": 1, "kind": "part", "txt": "Puoi montare generatori a punto zero (+12 energia)."},
}
const TECH_CATS := ["mil", "grid", "nano"]
const CAT_NAME := {"mil": "Militari", "grid": "Reticolo", "nano": "Nano", "rare": "Rare"}
const CAT_COLOR := {"mil": Color("#c9418f"), "grid": Color("#4fa53f"), "nano": Color("#c9b52b"), "rare": Color("#8c8f96")}
const TECH_ORDER := {
	"mil": ["neutron_bombs", "starbase", "plasma_cannon", "phase_shield", "advanced_mining", "tachyon_source", "gluon_computer", "plasma_missile"],
	"grid": ["gauss_shield", "fusion_source", "improved_hull", "positron_computer", "advanced_economy", "tachyon_drive", "antimatter_cannon", "quantum_grid"],
	"nano": ["nanorobots", "fusion_drive", "orbital", "advanced_robotics", "advanced_labs", "monolith", "wormhole_generator", "artifact_key"],
}

# ------------------------------------------------------------------ scoperte
## Pescate a caso (38 tessere del gioco base del modulo). Ogni tessera si può tenere per 2 PV.
const DISCOVERIES := [
	{"k": "mat6", "img": "077dbe63", "n": 3, "name": "+6 materiali"},
	{"k": "sci5", "img": "cf9a8768", "n": 3, "name": "+5 scienza"},
	{"k": "money8", "img": "812e4d6a", "n": 3, "name": "+8 denaro"},
	{"k": "mix", "img": "955ef7d5", "n": 2, "name": "+2 materiali, +2 scienza, +3 denaro"},
	{"k": "tech", "img": "1c2c709f", "n": 3, "name": "Tecnologia antica"},
	{"k": "cruiser", "img": "3636aa7a", "n": 3, "name": "Incrociatore antico"},
	{"k": "orbital", "img": "b6fd7576", "n": 2, "name": "Orbitale antico (+2 materiali)"},
	{"k": "monolith", "img": "4a33a699", "n": 1, "name": "Monolito antico"},
	{"k": "warp", "img": "65840779", "n": 1, "name": "Portale di curvatura antico"},
	{"k": "part", "part": "soliton_missile", "n": 1},
	{"k": "part", "part": "antimatter_missile", "n": 1},
	{"k": "part", "part": "ion_turret", "n": 1},
	{"k": "part", "part": "hypergrid_source", "n": 1},
	{"k": "part", "part": "muon_source", "n": 1},
	{"k": "part", "part": "nonlinear_drive", "n": 1},
	{"k": "part", "part": "soliton_charger", "n": 1},
	{"k": "part", "part": "inversion_shield", "n": 1},
	{"k": "part", "part": "shard_hull", "n": 1},
	{"k": "part", "part": "rift_conductor", "n": 1},
	{"k": "part", "part": "flux_shield", "n": 1},
	{"k": "part", "part": "morph_shield", "n": 1},
	{"k": "part", "part": "plasma_turret", "n": 1},
	{"k": "part", "part": "ion_disruptor", "n": 1},
	{"k": "part", "part": "axion_computer", "n": 1},
	{"k": "part", "part": "conformal_drive", "n": 1},
	{"k": "part", "part": "ion_missile", "n": 1},
]

# ------------------------------------------------------------------ navi neutrali
const NPC_NAME := {"anc": "Antico", "gua": "Guardiano", "gcds": "SDCG"}
const NPC_PLURAL := {"anc": "Antichi", "gua": "Guardiani", "gcds": "SDCG"}
const NPC_BP := {
	"anc": [{"can": ["y", "y"], "comp": 1, "hull": 1, "ini": 2, "img": "ancients_e7300938"},
		{"can": ["o"], "comp": 1, "hull": 2, "ini": 1, "img": "advanced_ancient_420aafdf"},
		{"can": ["y"], "comp": 2, "hull": 1, "ini": 3, "img": "advanced_ancient_e330941f"}],
	"gua": [{"can": ["y", "y", "y"], "comp": 2, "hull": 2, "ini": 3, "img": "guardians_92c3cf40"},
		{"mis": ["o", "o"], "can": ["r"], "comp": 1, "hull": 3, "ini": 1, "img": "advanced_guardian_13b23b56"},
		{"can": ["o", "o"], "comp": 1, "sh": 1, "hull": 3, "ini": 2, "img": "advanced_guardian_9d5d1960"}],
	"gcds": [{"can": ["y", "y", "y", "y"], "comp": 2, "hull": 7, "ini": 0, "img": "gcds_6ac9934e"},
		{"mis": ["y", "y", "y", "y"], "can": ["r"], "comp": 2, "hull": 3, "ini": 2, "img": "advanced_gcds_e08acf81"},
		{"can": ["o", "o"], "comp": 2, "sh": 2, "hull": 4, "ini": 3, "img": "advanced_gcds_f62524b5"}],
}

# ------------------------------------------------------------------ specie
const BP_STD := {
	"int": ["nuclear_source", "ion_cannon", "nuclear_drive", ""],
	"cru": ["electron_computer", "ion_cannon", "", "nuclear_source", "hull", "nuclear_drive"],
	"dre": ["electron_computer", "ion_cannon", "ion_cannon", "", "nuclear_source", "hull", "hull", "nuclear_drive"],
	"sb": ["electron_computer", "", "ion_cannon", "hull", "hull"],
}
const BP_ORION := {
	"int": ["nuclear_source", "ion_cannon", "nuclear_drive", "gauss_shield"],
	"cru": ["electron_computer", "ion_cannon", "gauss_shield", "nuclear_source", "hull", "nuclear_drive"],
	"dre": ["electron_computer", "ion_cannon", "ion_cannon", "gauss_shield", "nuclear_source", "hull", "hull", "nuclear_drive"],
	"sb": ["electron_computer", "ion_cannon", "gauss_shield", "hull", "hull"],
}
const BP_PLANTA := {
	"int": ["nuclear_source", "ion_cannon", "nuclear_drive"],
	"cru": ["nuclear_source", "ion_cannon", "", "hull", "nuclear_drive"],
	"dre": ["nuclear_source", "ion_cannon", "ion_cannon", "", "hull", "hull", "nuclear_drive"],
	"sb": ["electron_computer", "ion_cannon", "hull", "hull"],
}
const COST_STD := {"int": 3, "cru": 5, "dre": 8, "sb": 3, "orb": 4, "mono": 10}
const TERRAN := {"name": "Terrestri", "res": {"m": 4, "s": 3, "$": 3}, "colony": 3, "trade": 2, "techs": ["starbase"],
	"acts": {"exp": 1, "res": 1, "upg": 2, "bui": 2, "mov": 3, "inf": 2}, "rep": ["A", "X", "X", "X", "X"],
	"ini": {"int": 2, "cru": 1, "dre": 0, "sb": 4}, "bonus": {"sb": {"en": 3}}}
const SPECIES := {
	"terran_directorate": {"faction": "Direttorato Terrestre", "home": 221, "terran": true},
	"terran_federation": {"faction": "Federazione Terrestre", "home": 223, "terran": true},
	"terran_union": {"faction": "Unione Terrestre", "home": 225, "terran": true},
	"terran_republic": {"faction": "Repubblica Terrestre", "home": 227, "terran": true},
	"terran_conglomerate": {"faction": "Conglomerato Terrestre", "home": 229, "terran": true},
	"terran_alliance": {"faction": "Alleanza Terrestre", "home": 231, "terran": true},
	"eridani": {"faction": "Impero di Eridani", "home": 222, "res": {"m": 4, "s": 2, "$": 26}, "colony": 3, "trade": 3,
		"techs": ["gauss_shield", "fusion_drive", "plasma_cannon"], "acts": {"exp": 1, "res": 1, "upg": 2, "bui": 2, "mov": 2, "inf": 2},
		"rep": ["X", "X", "X", "X"], "ini": {"int": 2, "cru": 1, "dre": 0, "sb": 4},
		"bonus": {"int": {"en": 1}, "cru": {"en": 1}, "dre": {"en": 1}, "sb": {"en": 3}}, "start_rep": 2, "disc_minus": 2,
		"txt": "Due tessere reputazione all'inizio. Due dischi influenza in meno. Più energia su intercettori, incrociatori e corazzate."},
	"hydran": {"faction": "Progresso Hydran", "home": 224, "res": {"m": 2, "s": 6, "$": 2}, "colony": 3, "trade": 3,
		"techs": ["advanced_labs"], "acts": {"exp": 1, "res": 2, "upg": 2, "bui": 2, "mov": 2, "inf": 2},
		"rep": ["A", "X", "X", "X"], "ini": {"int": 2, "cru": 1, "dre": 0, "sb": 4}, "bonus": {"sb": {"en": 3}}, "home_adv_sci": true,
		"txt": "Due attivazioni a ogni Ricerca. Inizia con un cubetto sul pianeta avanzato della scienza."},
	"planta": {"faction": "Planta", "home": 226, "res": {"m": 4, "s": 3, "$": 2}, "colony": 4, "trade": 3,
		"techs": ["starbase"], "acts": {"exp": 2, "res": 1, "upg": 2, "bui": 2, "mov": 2, "inf": 2},
		"rep": ["A", "X", "X", "X"], "ini": {"int": 0, "cru": 0, "dre": 0, "sb": 2}, "bp": "planta",
		"bonus": {"int": {"en": 2, "comp": 1}, "cru": {"en": 2, "comp": 1}, "dre": {"en": 2, "comp": 1}, "sb": {"en": 5, "comp": 1}},
		"vp_sector": 1, "fragile": true,
		"txt": "Due attivazioni a ogni Esplorazione. 1 PV in più per ogni settore controllato. Le navi nemiche distruggono da sole i cubetti Planta. Iniziativa più bassa, computer ed energia in più, una casella in meno."},
	"draco": {"faction": "Discendenti di Draco", "home": 228, "res": {"m": 3, "s": 4, "$": 2}, "colony": 3, "trade": 3,
		"techs": ["fusion_drive"], "acts": {"exp": 1, "res": 1, "upg": 2, "bui": 2, "mov": 2, "inf": 2},
		"rep": ["X", "X", "X", "X"], "ini": {"int": 2, "cru": 1, "dre": 0, "sb": 4}, "bonus": {"sb": {"en": 3}}, "draw2": true, "ancient_friend": true,
		"txt": "Esplorando giri due settori e ne scegli uno. Convivono con gli Antichi (niente battaglie, niente blocchi). 1 PV per ogni Antico rimasto sulla mappa."},
	"mechanema": {"faction": "Mechanema", "home": 230, "res": {"m": 4, "s": 3, "$": 3}, "colony": 3, "trade": 3,
		"techs": ["positron_computer"], "acts": {"exp": 1, "res": 1, "upg": 3, "bui": 3, "mov": 2, "inf": 2},
		"rep": ["X", "X", "X", "X"], "ini": {"int": 2, "cru": 1, "dre": 0, "sb": 4}, "bonus": {"sb": {"en": 3}},
		"cost": {"int": 2, "cru": 4, "dre": 7, "sb": 2, "orb": 3, "mono": 8},
		"txt": "Costruzioni più economiche. Tre attivazioni a ogni Potenziare e Costruire."},
	"orion": {"faction": "Egemonia di Orione", "home": 232, "res": {"m": 4, "s": 3, "$": 3}, "colony": 3, "trade": 4,
		"techs": ["neutron_bombs", "gauss_shield"], "acts": {"exp": 1, "res": 1, "upg": 2, "bui": 2, "mov": 2, "inf": 2},
		"rep": ["X", "X", "X", "X", "X"], "ini": {"int": 3, "cru": 2, "dre": 1, "sb": 5}, "bp": "orion",
		"bonus": {"int": {"en": 1}, "cru": {"en": 2}, "dre": {"en": 3}, "sb": {"en": 3}}, "start_cruiser": true,
		"txt": "Inizia con un incrociatore invece dell'intercettore. Iniziativa ed energia in più, scudi di Gauss già montati."},
}


## Dati completi di una specie (le fazioni terrestri condividono la plancia terrestre).
static func species(id: String) -> Dictionary:
	var s: Dictionary = SPECIES[id].duplicate(true)
	if s.get("terran", false):
		var t: Dictionary = TERRAN.duplicate(true)
		for k in s:
			t[k] = s[k]
		t["txt"] = "Nessuna abilità speciale: tre attivazioni a ogni Movimento, commercio 2:1."
		s = t
	if not s.has("cost"):
		s["cost"] = COST_STD.duplicate()
	var bp_kind: String = s.get("bp", "std")
	s["bp_base"] = (BP_ORION if bp_kind == "orion" else (BP_PLANTA if bp_kind == "planta" else BP_STD)).duplicate(true)
	return s


static func species_title(id: String) -> String:
	return SPECIES[id]["faction"]


static func neighbor(h: Vector2i, d: int) -> Vector2i:
	return h + DIRS[d]


static func dist(a: Vector2i, b: Vector2i = Vector2i.ZERO) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dr) + abs(dq + dr)) / 2)


static func key(h: Vector2i) -> String:
	return "%d,%d" % [h.x, h.y]


static func unkey(k: String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1]))


static func ring_of(h: Vector2i) -> int:
	return min(3, dist(h))


## Direzione (0-5) da a verso b, se adiacenti; altrimenti -1.
static func dir_to(a: Vector2i, b: Vector2i) -> int:
	for d in 6:
		if a + DIRS[d] == b:
			return d
	return -1


static func tech_name(t: String) -> String:
	return TECHS[t]["name"] if TECHS.has(t) else t


static func part_name(p: String) -> String:
	return PARTS[p]["name"] if PARTS.has(p) else p

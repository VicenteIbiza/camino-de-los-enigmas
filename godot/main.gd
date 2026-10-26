extends Node3D
## El Camino de los Enigmas: demo del reino en Godot.
## Builds the hex board, the tavern and the dungeon from KayKit pieces, and runs the dice walk.

signal branch_chosen(index: int)

const HEROES := [
	{"id": "Knight", "name": "Auron", "title": "El Caballero", "art": "caballero", "show": ["1H_Sword", "Badge_Shield", "Knight_Helmet", "Knight_Cape"], "atk": "1H_Melee_Attack_Chop"},
	{"id": "Barbarian", "name": "Ragnar", "title": "El Bárbaro", "art": "barbaro", "show": ["2H_Axe", "Barbarian_Hat", "Barbarian_Cape"], "atk": "2H_Melee_Attack_Chop"},
	{"id": "Mage", "name": "Ignara", "title": "La Archimaga", "art": "maga", "show": ["2H_Staff", "Mage_Hat", "Mage_Cape"], "atk": "Spellcast_Shoot"},
	{"id": "Rogue", "name": "Sylwen", "title": "La Arquera", "art": "arquera", "show": ["1H_Crossbow", "Rogue_Cape"], "atk": "1H_Ranged_Shoot"},
	{"id": "Rogue_Hooded", "name": "Vex", "title": "El Asesino", "art": "ninja", "show": ["Knife", "Knife_Offhand", "Rogue_Cape"], "atk": "Dualwield_Melee_Attack_Chop"},
]
const BOSS := {
	"troll": {"name": "Trol del Puente", "hp": 5, "model": "Barbarian", "show": ["2H_Axe"], "tint": Color(0.55, 1.0, 0.45), "hex": Vector2i(-4, -1), "scale": 1.25},
	"golem": {"name": "Gólem de Cristal", "hp": 7, "model": "Knight", "show": ["2H_Sword", "Knight_Helmet"], "tint": Color(0.55, 0.85, 1.35), "hex": Vector2i(3, -1), "scale": 1.35},
	"dragon": {"name": "Dragón Carmesí", "hp": 10, "model": "", "hex": Vector2i(6, 0), "scale": 1.0},
}
const MINI := {
	"esbirro": {"name": "Esqueleto Esbirro", "hp": 2, "model": "Skeleton_Minion", "node": Vector2i(-6, 0), "hex": Vector2i(-6, -1), "atk": "Unarmed_Melee_Attack_Punch_A"},
	"picaro": {"name": "Esqueleto Pícaro", "hp": 3, "model": "Skeleton_Rogue", "node": Vector2i(-2, 2), "hex": Vector2i(-2, 1), "atk": "1H_Melee_Attack_Chop"},
	"mago": {"name": "Esqueleto Mago", "hp": 3, "model": "Skeleton_Mage", "node": Vector2i(1, -2), "hex": Vector2i(2, -2), "atk": "Spellcast_Shoot"},
	"guerrero": {"name": "Esqueleto Guerrero", "hp": 4, "model": "Skeleton_Warrior", "node": Vector2i(2, 0), "hex": Vector2i(2, 1), "atk": "1H_Melee_Attack_Chop"},
}
const QUEST_SPOTS := {
	"granja": {"node": Vector2i(-3, 2), "npc": Vector2i(-4, 2), "model": "Barbarian", "show": ["Barbarian_Hat"], "tint": Color(0.85, 1.0, 0.8)},
	"invierno": {"node": Vector2i(1, -1), "npc": Vector2i(2, -1), "model": "Barbarian", "show": ["Barbarian_Hat", "Barbarian_Cape"], "tint": Color(1.0, 0.85, 0.85)},
	"ermita": {"node": Vector2i(4, 0), "npc": Vector2i(4, 1), "model": "Knight", "show": ["Knight_Cape", "Badge_Shield"], "tint": Color(1.2, 1.05, 0.7)},
}
const ATTR_NAME := {"fuerza": "Fuerza", "sabiduria": "Sabiduría", "suerte": "Suerte"}
const ITEM_NAME := {"elixir": "Elixir de vida", "pocion": "Poción curativa", "pista": "Pista", "reloj": "Reloj de arena", "doble": "Dado doble", "escudo": "Escudo", "portal": "Portal", "trucado": "Dado trucado", "espada": "Espada de fuego"}
## price, when it is used (q: in a question, r: before rolling, p: by itself) and what it does
const ITEMS := {
	"pista": [2, "q", "En una pregunta: tacha dos respuestas falsas, te da la primera letra o suma 20 s a un reto."],
	"reloj": [2, "q", "En una pregunta o reto: +30 segundos."],
	"doble": [3, "r", "Tu próxima tirada usa dos dados y suma los dos."],
	"escudo": [3, "p", "Se usa solo: te libra de una maldición o de retroceder tras un fallo."],
	"portal": [3, "r", "Viaja al instante a la posada, a la mina o a la tienda."],
	"trucado": [4, "r", "Eliges tú el número de tu próxima tirada, del 1 al 6."],
	"espada": [4, "r", "Tu próximo golpe acertado a un enemigo hace el doble de daño."],
	"pocion": [2, "r", "Recuperas 1 corazón."],
	"elixir": [5, "p", "Se usa solo: si te quedas sin corazones, te levanta al momento con 2 corazones."],
}
const ATTR_INFO := {
	"fuerza": ["FUE", "+1 de daño en cada golpe a jefes y minijefes."],
	"sabiduria": ["SAB", "+5 segundos en cada pregunta y reto."],
	"suerte": ["SUE", "+1 al dado de las maldiciones: más fácil que salga algo bueno."],
}
const MAX_ITEMS := 3
const MAX_LV := 10
const SHOP_NPC := Vector2i(1, 1)
const GAME_FOR := {"laberinto": "memoria", "minas": "faroles", "deslizante": "simon", "atrapa": "simon", "memoria": "memoria", "simon": "simon", "faroles": "faroles"}
const TIERS := [[25, 0, 1], [55, 1, 2], [85, 2, 3], [100, 3, 4]]
const ACCESSORY := ["Sword", "Shield", "Axe", "Mug", "Spellbook", "Wand", "Staff", "Crossbow", "Knife", "Throwable", "Helmet", "Hat", "Cape"]
const HX := 2.0
const HZ := 1.7320508
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const ROAD := {"A": [3, 0], "B": [3, 1], "C": [3, 2], "D": [3, 1, 5], "M": [3]}
const TYPE := {
	"start": [Color("f4efe2"), "▶"], "riddle": [Color("8b5bd6"), "?"], "logic": [Color("13917e"), "◆"], "math": [Color("e2602f"), "+"],
	"skill": [Color("2f6fe0"), "✦"], "star": [Color("e9a917"), "★"], "quest": [Color("d08a2a"), "!"], "fork": [Color("ffd84a"), "⬌"],
	"tavern": [Color("ffb347"), "☕"], "shop": [Color("23a35f"), "◈"], "dungeon": [Color("9b5cff"), "☗"], "boss": [Color("c8323f"), "☠"],
}
const TYPE_NAME := {"riddle": "adivinanza", "logic": "acertijo", "math": "problema", "skill": "reto de habilidad", "star": "estrella", "quest": "misión", "fork": "cruce", "start": "salida", "shop": "tienda"}

var gold := Color("f2c14e")
var ink := Color("f4efe2")
var panel_bg := Color(0.05, 0.067, 0.15, 0.82)

var font_body: FontFile
var font_bold: FontFile
var font_head: FontFile
var font_epic: FontFile

var cache := {}
var path_nodes: Array = []
var mode := "board"
var roots := {}
var envs := {}
var world_env: WorldEnvironment
var cam: Camera3D
var yaw := 0.35
var pitch := 0.95
var dist := 15.0
var dist_goal := 15.0
var target := Vector3.ZERO
var goal := Vector3.ZERO
var torches: Array = []
var markers: Array = []
var clouds: Array = []
var beacons: Array = []
var busy := false
var offer_fn: Callable = Callable()

var hero: Node3D
var hero_anim: AnimationPlayer
var hero_def: Dictionary
var hero_at := 0
var hero_yaw := 0.0
var hero_yaw_goal := 0.0
var hero_cache := {}

var spawn := {}
var chest: Node3D
var mine_pos := Vector3.ZERO
var tavern_pos := Vector3.ZERO
var castle_pos := Vector3.ZERO
var touches := {}
var pinch0 := 0.0
var rng := RandomNumberGenerator.new()

# game state
var bank := {}
var decks := {}
var level := 2
var stars := 0
var quests := {}
var quests_done := {}
var qprog := {}
var items: Array = []
var relics: Array = []
var attrs := {"fuerza": 0, "sabiduria": 0, "suerte": 0}
var chest_opened := false
var questbox: Control
var btn_exit: Button
var npcs := {}
var rolls_used := 0
var last_roll := 0
var trail: Array = []
var qpanel: Control
var lbl_stats: Label
var bosses := {}
var d100: HBoxContainer
## Each player keeps these fields; the globals always hold the player whose turn it is.
const PFIELDS := ["hero_def", "hero", "hero_anim", "hero_at", "hero_yaw", "hero_yaw_goal", "stars", "items", "relics", "attrs", "hero_lv", "xp", "hp", "lv_pending", "next_roll", "fire", "trail", "last_roll", "fallen"]
var players: Array = []
var turn := 0
var fallen := false
var party_ui: Control
var hero_lv := 1
var hp := 6  # in half hearts
var hearts_box: HBoxContainer
var xp := 0
var lv_pending := 0
var next_roll := 0
var fire := false
var boss_met := {}
var lines := {}
var narrator: Control
var modal: Control
var lbl_xp: Label
var bar_xp: ProgressBar
var btn_bag: Button
var btn_voice: Button
var hud: Array = []
var cine := false
var cine_spin := 0.0
var skip_intro := false
var title_ui: Control
var bars: Array = []
var btn_skip: Button

# UI
var ui: Control
var lbl_name: Label
var lbl_msg: Label
var img_hero: TextureRect
var btn_act: Button
var box_visit: HBoxContainer
var box_choices: HBoxContainer
var lbl_dice: Label
var fade: ColorRect
var picker: HBoxContainer
var msg: PanelContainer


func _ready() -> void:
	rng.seed = 20261025
	font_body = load("res://assets/fonts/atkinson-400.woff2")
	font_bold = load("res://assets/fonts/atkinson-700.woff2")
	font_head = load("res://assets/fonts/grenze-700.woff2")
	font_epic = load("res://assets/fonts/gotisch-700.woff2")
	var sym: FontFile = load("res://assets/fonts/symbols.woff2")
	for f in [font_body, font_bold, font_head, font_epic]:
		f.fallbacks = [sym]
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.far = 300.0
	add_child(cam)
	world_env = WorldEnvironment.new()
	add_child(world_env)
	bank = JSON.parse_string(FileAccess.get_file_as_string("res://data/preguntas.json"))
	quests = JSON.parse_string(FileAccess.get_file_as_string("res://data/misiones.json"))
	lines = JSON.parse_string(FileAccess.get_file_as_string("res://data/narracion.json"))
	build_path()
	build_board()
	build_bosses()
	build_minis()
	build_tavern()
	build_dungeon()
	build_npcs()
	build_ui()
	set_mode("board")
	set_hud(false)
	show_splash()
	await use_hero(HEROES[0])
	target = goal
	show_title()


# ---------------------------------------------------------------- helpers
func scene(path: String) -> PackedScene:
	if not cache.has(path):
		cache[path] = load(path)
	return cache[path]


func hexp(n: String) -> String:
	return "res://assets/hex/%s.gltf" % n


func dngp(n: String) -> String:
	return "res://assets/dungeon/%s.glb" % n


func hpos(q: int, r: int) -> Vector3:
	return Vector3(HX * (q + r / 2.0), 0.0, HZ * r)


func key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]


## Collects instances of the same piece and draws each mesh as one MultiMesh.
class Batch:
	var items := {}

	func add(path: String, t: Transform3D) -> void:
		if not items.has(path):
			items[path] = []
		items[path].append(t)

	func build(owner_node: Node3D, loader: Callable) -> void:
		for path in items:
			var proto: Node3D = loader.call(path).instantiate()
			var meshes: Array = proto.find_children("*", "MeshInstance3D", true, false)
			for mi in meshes:
				var local: Transform3D = mi.transform
				var p: Node = mi.get_parent()
				while p != proto and p != null:
					local = p.transform * local
					p = p.get_parent()
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mi.mesh
				mm.instance_count = items[path].size()
				for i in items[path].size():
					mm.set_instance_transform(i, items[path][i] * local)
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				if mi.material_override:
					mmi.material_override = mi.material_override
				owner_node.add_child(mmi)
			proto.free()


func xform(pos: Vector3, rot := 0.0, s := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(s, s, s)), pos)


func face(q: int, r: int, tq: int, tr: int) -> float:
	var a := hpos(q, r)
	var b := hpos(tq, tr)
	return atan2(b.x - a.x, b.z - a.z)


func road_for(openings: Array) -> Array:
	var want := openings.duplicate()
	want.sort()
	for t in ROAD:
		var base: Array = ROAD[t]
		if base.size() != want.size():
			continue
		for k in 6:
			var rot: Array = base.map(func(d): return (d + k) % 6)
			rot.sort()
			if rot == want:
				return ["hex_road_" + t, k * PI / 3.0]
	return ["hex_road_A", 0.0]


func dir_index(a: Vector2i, b: Vector2i) -> int:
	for i in 6:
		if a + DIRS[i] == b:
			return i
	return 0


# ---------------------------------------------------------------- path
func add_node(q: int, r: int, type: String, branch := "") -> int:
	path_nodes.append({"q": q, "r": r, "type": type, "next": [], "branch": branch, "p": hpos(q, r)})
	return path_nodes.size() - 1


func link(list: Array) -> void:
	for i in list.size() - 1:
		path_nodes[list[i]]["next"].append(list[i + 1])


func build_path() -> void:
	var main := []
	for a in [[-7, 0, "start"], [-6, 0, "riddle"], [-5, 0, "tavern"], [-4, 0, "boss"], [-3, 0, "fork"]]:
		main.append(add_node(a[0], a[1], a[2]))
	var A := []
	for a in [[-2, -1, "logic"], [-1, -2, "star"], [0, -2, "dungeon"], [1, -2, "skill"], [1, -1, "quest"]]:
		A.append(add_node(a[0], a[1], a[2], "A"))
	var B := []
	for a in [[-3, 1, "star"], [-3, 2, "quest"], [-2, 2, "math"], [-1, 2, "logic"], [0, 1, "skill"]]:
		B.append(add_node(a[0], a[1], a[2], "B"))
	var tail := []
	for a in [[1, 0, "shop"], [2, 0, "star"], [3, 0, "boss"], [4, 0, "quest"], [5, 0, "boss"]]:
		tail.append(add_node(a[0], a[1], a[2]))
	path_nodes[main[3]]["boss"] = "troll"
	path_nodes[tail[2]]["boss"] = "golem"
	path_nodes[tail[4]]["boss"] = "dragon"
	link(main)
	link(A)
	link(B)
	link(tail)
	path_nodes[main[4]]["next"].append_array([A[0], B[0]])
	path_nodes[A[4]]["next"].append(tail[0])
	path_nodes[B[4]]["next"].append(tail[0])


# ---------------------------------------------------------------- board
func build_board() -> void:
	var root := Node3D.new()
	add_child(root)
	roots["board"] = root

	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("3a4a8a")
	sm.sky_horizon_color = Color("f3b07a")
	sm.ground_horizon_color = Color("c99a78")
	sm.ground_bottom_color = Color("3a3048")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("b9a0b0")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.12
	envs["board"] = env

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff0dc")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	root.add_child(sun)
	sun.look_at_from_position(Vector3(-22, 20, 12), Vector3.ZERO)

	var batch := Batch.new()
	var used := {}
	for i in path_nodes.size():
		used[key(path_nodes[i]["q"], path_nodes[i]["r"])] = i
	var occupied := {}
	var place := func(n: String, q: int, r: int, rot := 0.0, s := 1.0) -> void:
		batch.add(hexp(n), xform(hpos(q, r), rot, s))
		occupied[key(q, r)] = true

	place.call("building_tavern_blue", -5, -1, face(-5, -1, -5, 0), 1.25)
	tavern_pos = hpos(-5, -1)
	place.call("building_mine_blue", 0, -3, face(0, -3, 0, -2), 1.3)
	mine_pos = hpos(0, -3)
	place.call("building_blacksmith_blue", -4, 1, face(-4, 1, -4, 0), 1.15)
	place.call("building_church_blue", -6, 1, face(-6, 1, -6, 0), 1.2)
	place.call("building_home_A_blue", -7, -1, face(-7, -1, -6, 0), 1.1)
	place.call("building_home_B_blue", -2, 3, face(-2, 3, -2, 2), 1.1)
	place.call("building_home_A_blue", -4, 3, face(-4, 3, -3, 2), 1.1)
	place.call("building_market_blue", 0, 2, face(0, 2, -1, 2), 1.1)
	place.call("building_windmill_blue", 2, 2, 2.2, 1.25)
	place.call("building_well_blue", -2, 0, 0.4, 1.1)
	place.call("building_lumbermill_blue", 3, -2, face(3, -2, 2, -1), 1.15)
	place.call("building_watermill_blue", 3, 2, -0.6, 1.15)
	place.call("building_barracks_blue", 6, 0, face(6, 0, 5, 0), 1.7)
	castle_pos = hpos(6, 0)
	place.call("building_tower_A_blue", 6, -1, 0.0, 1.3)
	place.call("building_tower_A_blue", 5, 1, 0.0, 1.3)
	place.call("tent", 4, -1, 0.8, 1.1)
	place.call("weaponrack", 3, 1, -0.5, 1.2)
	place.call("target", 4, 1, -0.9, 1.1)
	place.call("building_grain", -6, 2, 0.3, 1.0)
	place.call("building_grain", -5, 2, 1.4, 1.0)
	for b in BOSS.values() + MINI.values():
		occupied[key(b["hex"].x, b["hex"].y)] = true

	var water := {"-1,0": true, "0,-1": true, "-1,1": true, "0,0": true}
	for r in range(3, 7):
		for q in range(1, 10):
			if r + q > 4 + (0 if rng.randf() < 0.5 else 1):
				water[key(q, r)] = true
	var mountains := ["-1,-3", "1,-3", "0,-4", "-1,-4", "1,-4"]
	for r in range(-7, 8):
		for c in range(-11, 12):
			var q := c - (r - (r & 1)) / 2
			var k := key(q, r)
			var here := hpos(q, r)
			if absf(here.x) > 23.0 or absf(here.z) > 13.0:
				continue
			if used.has(k):
				var pn: Dictionary = path_nodes[used[k]]
				var ops := []
				for ni in pn["next"]:
					ops.append(dir_index(Vector2i(pn["q"], pn["r"]), Vector2i(path_nodes[ni]["q"], path_nodes[ni]["r"])))
				for j in path_nodes.size():
					if path_nodes[j]["next"].has(used[k]):
						ops.append(dir_index(Vector2i(pn["q"], pn["r"]), Vector2i(path_nodes[j]["q"], path_nodes[j]["r"])))
				var rf := road_for(ops)
				batch.add(hexp(rf[0]), xform(here, rf[1], 1.012))
				continue
			if water.has(k):
				batch.add(hexp("hex_water"), xform(here, 0.0, 1.012))
				if rng.randf() < 0.25:
					batch.add(hexp("waterlily_A" if rng.randf() < 0.5 else "waterplant_A"), xform(here + Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5), rng.randf() * 6.0))
				continue
			batch.add(hexp("hex_grass"), xform(here, 0.0, 1.012))
			if occupied.has(k):
				continue
			var near_path := false
			for d in DIRS:
				if used.has(key(q + d.x, r + d.y)):
					near_path = true
			var edge := absf(here.z) > 9.0 or absf(here.x) > 18.0
			var roll := rng.randf()
			var deco := ""
			if r <= -5:
				deco = ["mountain_A_grass_trees", "mountain_B_grass", "mountain_C", "mountain_A", "hills_A_trees"][rng.randi() % 5]
			elif k in mountains:
				deco = ["mountain_A", "mountain_C", "mountain_B_grass"][rng.randi() % 3]
			elif edge and roll < 0.55:
				deco = ["trees_A_large", "trees_B_large", "hills_B_trees", "trees_A_medium"][rng.randi() % 4]
			elif not near_path and roll < 0.42:
				deco = ["trees_A_medium", "trees_B_medium", "trees_A_small", "tree_single_A", "tree_single_B", "hill_single_A", "rock_single_A"][rng.randi() % 7]
			elif near_path and roll < 0.18:
				deco = ["tree_single_A", "tree_single_B", "rock_single_C", "barrel", "sack", "crate_A_big"][rng.randi() % 6]
			if deco != "":
				batch.add(hexp(deco), xform(here, (rng.randi() % 6) * PI / 3.0))
	batch.build(root, scene)

	# ground skirt under the map
	var skirt := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	skirt.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("3f6a2e")
	skirt.material_override = gm
	skirt.position.y = -1.02
	root.add_child(skirt)

	# tile markers
	for n in path_nodes:
		var t: Array = TYPE[n["type"]]
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.56
		tor.outer_radius = 0.68
		tor.rings = 32
		ring.mesh = tor
		var m := StandardMaterial3D.new()
		m.albedo_color = t[0]
		m.emission_enabled = true
		m.emission = t[0]
		m.emission_energy_multiplier = 1.4
		ring.material_override = m
		ring.position = n["p"] + Vector3(0, 0.05, 0)
		root.add_child(ring)
		var ic := Label3D.new()
		ic.text = t[1]
		ic.font = font_bold
		ic.font_size = 64
		ic.pixel_size = 0.006
		ic.outline_size = 18
		ic.outline_modulate = Color(0.06, 0.05, 0.12)
		ic.modulate = Color.WHITE
		ic.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ic.position = n["p"] + Vector3(0, 0.95, 0)
		root.add_child(ic)
		markers.append({"ring": m, "ic": ic, "base": n["p"], "node": n})

	place_label(root, "Posada del Grifo", tavern_pos + Vector3(0, 2.5, 0))
	place_label(root, "Mina de las Runas", mine_pos + Vector3(0, 2.6, 0))
	place_label(root, "Fortaleza del Dragón", castle_pos + Vector3(0, 4.7, 0))

	for i in 7:
		var cl: Node3D = scene(hexp("cloud_big" if i % 2 else "cloud_small")).instantiate()
		cl.position = Vector3(-26 + i * 8.5, 9 + rng.randf() * 2, -16 + rng.randf() * 14)
		cl.scale = Vector3.ONE * (1.0 + rng.randf() * 0.6)
		root.add_child(cl)
		clouds.append(cl)
	root.add_child(fireflies(Vector3(46, 5, 26), Color("fff0b0"), 140))
	root.add_child(smoke(tavern_pos + Vector3(0.25, 2.2, -0.2)))


func place_label(parent: Node3D, text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font_head
	l.font_size = 48
	l.pixel_size = 0.008
	l.outline_size = 14
	l.outline_modulate = Color(0.05, 0.04, 0.1, 0.9)
	l.modulate = Color("ffe2a0")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	parent.add_child(l)


func glow_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	return m


func fireflies(box: Vector3, c: Color, amount := 120, y0 := 0.4) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box * 0.5
	p.position.y = y0 + box.y * 0.5
	p.gravity = Vector3.ZERO
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var fm := glow_material(c * Color(1.6, 1.6, 1.6))
	fm.albedo_texture = soft_dot()
	q.material = fm
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 1))
	g.add_point(0.7, Color(1, 1, 1, 0.8))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = g
	return p


func smoke(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.position = at
	p.gravity = Vector3(0.1, 0.5, -0.1)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.4
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_dot()
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.85, 0.9, 0.5))
	g.set_color(1, Color(0.85, 0.85, 0.9, 0.0))
	p.color_ramp = g
	return p


func soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


# ---------------------------------------------------------------- interiors
func room(batch: Batch, floor_name: String, w: float, d: float, back: Array, side: Array) -> void:
	var x := -w / 2 + 2
	while x < w / 2:
		var z := -d / 2 + 2
		while z < d / 2:
			batch.add(dngp(floor_name), xform(Vector3(x, 0, z)))
			z += 4
		x += 4
	var i := 0
	x = -w / 2 + 2
	while x < w / 2:
		batch.add(dngp(back[i % back.size()]), xform(Vector3(x, 0, -d / 2 - 0.5)))
		x += 4
		i += 1
	i = 0
	var z2 := -d / 2 + 2
	while z2 < d / 2:
		batch.add(dngp(side[i % side.size()]), xform(Vector3(-w / 2 - 0.5, 0, z2), PI / 2))
		batch.add(dngp(side[(i + 1) % side.size()]), xform(Vector3(w / 2 + 0.5, 0, z2), -PI / 2))
		z2 += 4
		i += 1
	batch.add(dngp("wall_corner"), xform(Vector3(-w / 2 - 0.5, 0, -d / 2 - 0.5), PI / 2))
	batch.add(dngp("wall_corner"), xform(Vector3(w / 2 + 0.5, 0, -d / 2 - 0.5)))


func torch(parent: Node3D, at: Vector3, c := Color("ff9a3c"), energy := 2.4, rng_dist := 13.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng_dist
	l.omni_attenuation = 1.4
	l.position = at
	parent.add_child(l)
	var f := CPUParticles3D.new()
	f.amount = 16
	f.lifetime = 0.6
	f.position = at + Vector3(0, -0.1, 0)
	f.gravity = Vector3(0, 2.2, 0)
	f.initial_velocity_min = 0.1
	f.initial_velocity_max = 0.4
	f.spread = 20.0
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var m := glow_material(Color(1, 0.6, 0.2) * Color(2.2, 2.2, 2.2, 1))
	m.albedo_texture = soft_dot()
	q.material = m
	f.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.85, 0.5, 1))
	g.set_color(1, Color(1, 0.3, 0.05, 0))
	f.color_ramp = g
	parent.add_child(f)
	torches.append({"light": l, "base": energy, "ph": randf() * 6.0})


func interior_env(bg: Color, ambient: Color, ambient_energy: float, fog: Color) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = 0.02
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95
	env.adjustment_contrast = 1.08
	return env


func add_piece(batch: Batch, n: String, x: float, z: float, rot := 0.0, s := 1.0, y := 0.0) -> void:
	batch.add(dngp(n), xform(Vector3(x, y, z), rot, s))


func build_tavern() -> void:
	var root := Node3D.new()
	add_child(root)
	roots["tavern"] = root
	envs["tavern"] = interior_env(Color("120b08"), Color("ffcf9a"), 0.35, Color("1a0f08"))
	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color("ffb070")
	key_light.light_energy = 0.45
	key_light.shadow_enabled = true
	root.add_child(key_light)
	key_light.look_at_from_position(Vector3(-6, 12, 8), Vector3.ZERO)
	var b := Batch.new()
	room(b, "floor_wood_large", 16, 12, ["wall_window_closed", "wall_shelves", "wall", "wall_window_closed"], ["wall", "wall_shelves", "wall_window_closed"])
	add_piece(b, "table_long_decorated_A", -3.5, -1, PI / 2, 0.9)
	add_piece(b, "table_medium_tablecloth_decorated_B", 3.5, -0.5, 0, 0.9)
	var seats := [[-5.4, -1], [-1.6, -1], [-3.5, -3.1], [-3.5, 1.1]]
	for i in seats.size():
		add_piece(b, "stool" if i % 2 else "chair", seats[i][0], seats[i][1], i * 1.57, 0.9)
	var chairs := [[2.2, -0.5], [4.8, -0.5], [3.5, -1.9]]
	for i in chairs.size():
		add_piece(b, "chair", chairs[i][0], chairs[i][1], -i * 1.4, 0.9)
	add_piece(b, "keg", -6.4, -4.4, 0.3, 0.85)
	add_piece(b, "barrel_large", -4.5, -4.6, 0, 0.8)
	add_piece(b, "barrel_small_stack", 6.3, -4.6, -0.4, 0.8)
	add_piece(b, "shelves", 1.5, -5.2, 0, 1)
	add_piece(b, "crates_stacked", 6.4, 2.6, 0.5, 0.8)
	add_piece(b, "candle_triple", -3.5, -1, 0, 0.9, 1.7)
	add_piece(b, "banner_patternA_red", -3, -5.6, 0, 1)
	add_piece(b, "banner_shield_blue", 4, -5.6, 0, 1)
	add_piece(b, "torch_mounted", -7.6, -2, PI / 2, 1, 2.4)
	add_piece(b, "torch_mounted", 7.6, -2, -PI / 2, 1, 2.4)
	add_piece(b, "torch_mounted", 0, -5.6, 0, 1, 2.4)
	add_piece(b, "plate_food_A", 3.5, -0.5, 0, 0.7, 1.75)
	add_piece(b, "bottle_A_green", 4.1, -0.2, 0, 0.8, 1.75)
	b.build(root, scene)
	torch(root, Vector3(-7.2, 3.2, -2), Color("ff9a3c"), 1.8)
	torch(root, Vector3(7.2, 3.2, -2), Color("ff9a3c"), 1.8)
	torch(root, Vector3(0, 3.2, -5.2), Color("ff9a3c"), 1.8)
	torch(root, Vector3(-3.5, 2.6, -1), Color("ffc070"), 1.3, 8.0)
	root.add_child(fireflies(Vector3(14, 3.5, 10), Color("ffc890"), 70, 0.5))
	spawn["tavern"] = {"from": Vector3(0, 0, 7), "to": Vector3(0, 0, 2.2), "cam": Vector3(0, 1.6, -1), "dist": 15.0}


func build_dungeon() -> void:
	var root := Node3D.new()
	add_child(root)
	roots["dungeon"] = root
	envs["dungeon"] = interior_env(Color("05060c"), Color("5a6aa8"), 0.25, Color("05060c"))
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("8aa0ff")
	moon.light_energy = 0.3
	moon.shadow_enabled = true
	root.add_child(moon)
	moon.look_at_from_position(Vector3(6, 14, 6), Vector3.ZERO)
	var b := Batch.new()
	room(b, "floor_tile_large", 20, 16, ["wall_cracked", "wall_arched", "wall", "wall_arched", "wall_cracked"], ["wall", "wall_cracked", "wall_arched", "wall"])
	add_piece(b, "floor_tile_large_rocks", -6, 6)
	add_piece(b, "floor_dirt_large", 6, 6)
	for p in [[-5, -2], [5, -2], [-5, 3], [5, 3]]:
		add_piece(b, "pillar_decorated", p[0], p[1], 0, 0.8)
	add_piece(b, "floor_tile_big_spikes", 6, 6, 0, 0.9)
	add_piece(b, "rubble_large", -6, -6.6, 0, 0.55)
	add_piece(b, "barrel_large", 8, -6, 0, 0.7)
	add_piece(b, "trunk_large_A", -8, 1, 1.2, 0.9)
	add_piece(b, "coin_stack_large", -1.8, -5.6, 0, 0.8)
	add_piece(b, "coin_stack_large", 1.9, -5.4, 1, 0.7)
	add_piece(b, "sword_shield", 7.5, -7, 0, 1, 2.6)
	add_piece(b, "banner_patternA_red", -3.5, -7.6, 0, 1)
	add_piece(b, "banner_patternA_red", 3.5, -7.6, 0, 1)
	for p in [[-9.6, -4], [9.6, -4], [-9.6, 4], [9.6, 4]]:
		add_piece(b, "torch_mounted", p[0], p[1], PI / 2 if p[0] < 0 else -PI / 2, 1, 2.4)
	b.build(root, scene)
	chest = scene(dngp("chest_gold")).instantiate()
	chest.position = Vector3(0, 0, -5.5)
	chest.scale = Vector3.ONE * 1.1
	root.add_child(chest)
	torch(root, Vector3(-9.2, 3.2, -4), Color("ff8a3c"), 2.6, 14.0)
	torch(root, Vector3(9.2, 3.2, -4), Color("ff8a3c"), 2.6, 14.0)
	torch(root, Vector3(0, 2.2, -4.2), Color("ffd36a"), 2.0, 9.0)
	torch(root, Vector3(-9.2, 3.2, 4), Color("6aa8ff"), 1.6, 12.0)
	root.add_child(fireflies(Vector3(18, 4, 14), Color("9fd0ff"), 80, 0.3))
	spawn["dungeon"] = {"from": Vector3(0, 0, 9), "to": Vector3(0, 0, 4.6), "cam": Vector3(0, 1.4, -1.5), "dist": 18.0}


func set_mode(m: String) -> void:
	mode = m
	for k in roots:
		roots[k].visible = k == m
	world_env.environment = envs[m]



# ---------------------------------------------------------------- bosses
func boss_alive(n: int) -> bool:
	return path_nodes[n].has("boss") and bosses[path_nodes[n]["boss"]]["hp"] > 0


func mini_alive(n: int) -> bool:
	return path_nodes[n].has("mini") and bosses[path_nodes[n]["mini"]]["hp"] > 0


## The boss or miniboss still standing on square n ("" if none).
func foe_at(n: int) -> String:
	if boss_alive(n):
		return path_nodes[n]["boss"]
	if mini_alive(n):
		return path_nodes[n]["mini"]
	return ""


func foe_name(id: String) -> String:
	return BOSS[id]["name"] if BOSS.has(id) else MINI[id]["name"]


func build_minis() -> void:
	for id in MINI:
		var m: Dictionary = MINI[id]
		var node := -1
		for i in path_nodes.size():
			if path_nodes[i]["q"] == m["node"].x and path_nodes[i]["r"] == m["node"].y:
				node = i
		path_nodes[node]["mini"] = id
		var model: Node3D = scene("res://assets/minis/%s.glb" % m["model"]).instantiate()
		var anim: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		if anim.has_animation("Idle"):
			anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		var pos := hpos(m["hex"].x, m["hex"].y)
		model.position = pos
		model.scale = Vector3.ONE * 0.62
		var tgt: Vector3 = path_nodes[node]["p"]
		model.rotation.y = atan2(tgt.x - pos.x, tgt.z - pos.z)
		model.visible = false
		roots["board"].add_child(model)
		var lbl := Label3D.new()
		lbl.font = font_head
		lbl.font_size = 36
		lbl.pixel_size = 0.008
		lbl.outline_size = 12
		lbl.outline_modulate = Color(0.06, 0.02, 0.1)
		lbl.modulate = Color("d4b4ff")
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.position = pos + Vector3(0, 2.0, 0)
		lbl.visible = false
		roots["board"].add_child(lbl)
		bosses[id] = {"node": node, "hp": m["hp"], "max": m["hp"], "model": model, "anim": anim, "label": lbl, "home": pos, "mini": true, "awake": false}
		boss_label(id)


func reveal_mini(id: String) -> void:
	var b: Dictionary = bosses[id]
	if b["awake"]:
		return
	b["awake"] = true
	b["model"].visible = true
	b["label"].visible = true
	burst(b["home"] + Vector3(0, 0.4, 0), Color("b48cff"))
	boss_anim(id, "Spawn_Ground_Skeletons")
	await get_tree().create_timer(1.6).timeout
	boss_anim(id, "Idle")


func burst(at: Vector3, c: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 36
	p.lifetime = 1.0
	p.explosiveness = 0.9
	p.position = at
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -3, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.25, 0.25)
	var m := glow_material(c * Color(1.8, 1.8, 1.8, 1))
	m.albedo_texture = soft_dot()
	q.material = m
	p.mesh = q
	roots["board"].add_child(p)
	p.emitting = true
	get_tree().create_timer(1.8).timeout.connect(p.queue_free)


func mini_curse(id: String) -> String:
	var b: Dictionary = bosses[id]
	var was_hidden: bool = not b["awake"]
	await reveal_mini(id)
	boss_anim(id, "Spellcast_Summon")
	say("%s%s despierta al verte pasar y lanza una maldición. Tira el dado…" % ["¡Un minijefe oculto! " if was_hidden else "", foe_name(id)])
	await get_tree().create_timer(1.0).timeout
	var raw := randi_range(1, 6)
	var luck: int = attrs["suerte"]
	var v := mini(6, raw + luck)
	lbl_dice.visible = true
	for k in 10:
		lbl_dice.text = str(randi_range(1, 6))
		await get_tree().create_timer(0.055).timeout
	lbl_dice.text = str(raw) if luck == 0 else "%d + %d" % [raw, luck]
	await get_tree().create_timer(0.9).timeout
	lbl_dice.visible = false
	var out := "stay"
	var txt := ""
	if v <= 4 and items.has("escudo"):
		items.erase("escudo")
		txt = "¡tu escudo para la maldición! No te pasa nada."
		burst(hero.position + Vector3(0, 1.0, 0), Color("9fd6ff"))
		v = 0
	elif v <= 2:
		if stars > 0:
			stars -= 1
			txt = "te roba 1 estrella."
		else:
			txt = "quería robarte una estrella, pero no tienes. Se ríe de ti."
		play("Hit_A")
	elif v <= 4:
		txt = "te empuja 2 casillas atrás y se acaba tu turno."
		out = "push"
	elif v == 5:
		txt = "te congela: te quedas aquí."
		out = "stop"
	else:
		stars += 1
		txt = "¡le caes bien! Te regala 1 estrella."
		play("Cheer")
	boss_anim(id, "Taunt" if v < 6 else "Cheer")
	if v > 0:
		burst(hero.position + Vector3(0, 1.0, 0), Color("ffd84a") if v == 6 else Color("b48cff"))
	update_stats()
	say("%s · dado %s: %s" % [foe_name(id), str(raw) if luck == 0 else "%d+%d" % [raw, luck], txt])
	await get_tree().create_timer(1.4).timeout
	boss_anim(id, "Idle")
	if out == "push":
		for i in 2:
			if trail.is_empty():
				break
			var back: int = trail.pop_back()
			await walk_to(path_nodes[back]["p"], 0.38)
			hero_at = back
		play("Idle")
	return out


func tint_model(root: Node, tint: Color, glow := false) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(i)
			if m is StandardMaterial3D:
				var d: StandardMaterial3D = m.duplicate()
				d.albedo_color = d.albedo_color * tint
				if glow:
					d.emission_enabled = true
					d.emission = Color(0.2, 0.5, 0.9)
					d.emission_energy_multiplier = 0.35
					d.metallic = 0.3
					d.roughness = 0.25
				mi.set_surface_override_material(i, d)


func make_dragon() -> Node3D:
	# placeholder dragon built from simple shapes until a real dragon model is added
	var root := Node3D.new()
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("c22f45")
	red.roughness = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("7a1b26")
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("f2c14e")
	gold.metallic = 0.6
	gold.roughness = 0.3
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color("ffd34a")
	eye.emission_enabled = true
	eye.emission = Color("ffb300")
	eye.emission_energy_multiplier = 3.0
	var part := func(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3, parent: Node3D) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		parent.add_child(mi)
		return mi
	var body := CapsuleMesh.new()
	body.radius = 0.55
	body.height = 1.9
	part.call(body, red, Vector3(0, 1.0, 0), Vector3(PI / 2, 0, 0), root)
	var belly := CapsuleMesh.new()
	belly.radius = 0.42
	belly.height = 1.5
	part.call(belly, gold, Vector3(0, 0.85, 0.12), Vector3(PI / 2, 0, 0), root)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.22
	neck.bottom_radius = 0.34
	neck.height = 1.1
	part.call(neck, red, Vector3(0, 1.75, 0.75), Vector3(-0.6, 0, 0), root)
	var head := BoxMesh.new()
	head.size = Vector3(0.62, 0.48, 0.8)
	part.call(head, red, Vector3(0, 2.25, 1.15), Vector3.ZERO, root)
	var snout := BoxMesh.new()
	snout.size = Vector3(0.46, 0.28, 0.5)
	part.call(snout, dark, Vector3(0, 2.12, 1.6), Vector3.ZERO, root)
	var horn := CylinderMesh.new()
	horn.top_radius = 0.0
	horn.bottom_radius = 0.09
	horn.height = 0.55
	for sx in [-1, 1]:
		part.call(horn, gold, Vector3(0.2 * sx, 2.62, 0.95), Vector3(-0.6, 0, 0.3 * sx), root)
		var e := SphereMesh.new()
		e.radius = 0.07
		e.height = 0.14
		part.call(e, eye, Vector3(0.24 * sx, 2.36, 1.48), Vector3.ZERO, root)
		var leg := CylinderMesh.new()
		leg.top_radius = 0.16
		leg.bottom_radius = 0.2
		leg.height = 0.8
		part.call(leg, red, Vector3(0.38 * sx, 0.4, 0.5), Vector3.ZERO, root)
		part.call(leg, red, Vector3(0.38 * sx, 0.4, -0.5), Vector3.ZERO, root)
		# wing: a flat triangle fan, double sided
		var pivot := Node3D.new()
		pivot.position = Vector3(0.35 * sx, 1.45, -0.1)
		root.add_child(pivot)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts := [Vector3(0, 0, 0.5), Vector3(1.9 * sx, 0.9, 0.2), Vector3(1.7 * sx, 0.2, -0.4), Vector3(2.0 * sx, -0.2, -0.9), Vector3(1.1 * sx, -0.1, -0.9), Vector3(0, 0, -0.6)]
		for k in range(1, pts.size() - 1):
			st.add_vertex(pts[0])
			st.add_vertex(pts[k])
			st.add_vertex(pts[k + 1])
		st.generate_normals()
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color("8f1d2a")
		wm.cull_mode = BaseMaterial3D.CULL_DISABLED
		part.call(st.commit(), wm, Vector3.ZERO, Vector3.ZERO, pivot)
		root.set_meta("wing%d" % (0 if sx < 0 else 1), pivot)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.02
	tail.bottom_radius = 0.3
	tail.height = 1.6
	part.call(tail, red, Vector3(0, 0.75, -1.55), Vector3(-1.2, 0, 0), root)
	return root


func build_bosses() -> void:
	for id in BOSS:
		var b: Dictionary = BOSS[id]
		var node := -1
		for i in path_nodes.size():
			if path_nodes[i].get("boss", "") == id:
				node = i
		var model: Node3D
		var anim: AnimationPlayer = null
		if b["model"] != "":
			model = load_hero({"id": b["model"], "show": b["show"]})
			anim = model.find_children("*", "AnimationPlayer", true, false)[0]
			tint_model(model, b["tint"], id == "golem")
			for n in ["Idle", "2H_Melee_Idle"]:
				if anim.has_animation(n):
					anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			anim.play("Idle")
		else:
			model = make_dragon()
		var pos := hpos(b["hex"].x, b["hex"].y)
		if id == "dragon":
			pos += Vector3(0, 2.6, 0)
		model.position = pos
		model.scale = Vector3.ONE * b["scale"]
		var tgt: Vector3 = path_nodes[node]["p"]
		model.rotation.y = atan2(tgt.x - pos.x, tgt.z - pos.z)
		roots["board"].add_child(model)
		var lbl := Label3D.new()
		lbl.font = font_head
		lbl.font_size = 44
		lbl.pixel_size = 0.008
		lbl.outline_size = 14
		lbl.outline_modulate = Color(0.08, 0.02, 0.04)
		lbl.modulate = Color("ffb59a")
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.position = pos + Vector3(0, 3.4 if id != "dragon" else 2.4, 0)
		roots["board"].add_child(lbl)
		bosses[id] = {"node": node, "hp": b["hp"], "max": b["hp"], "model": model, "anim": anim, "label": lbl, "home": pos}
		boss_label(id)


func boss_label(id: String) -> void:
	var b: Dictionary = bosses[id]
	var hearts := ""
	for i in b["max"]:
		hearts += "♥" if i < b["hp"] else "♡"
	b["label"].text = "%s\n%s" % [foe_name(id), hearts]


func boss_anim(id: String, n: String) -> void:
	var a: AnimationPlayer = bosses[id]["anim"]
	if a and a.has_animation(n):
		a.play(n, 0.2)


func roll_d100() -> int:
	var tens := randi_range(0, 9)
	var units := randi_range(0, 9)
	var v := tens * 10 + units
	if v == 0:
		v = 100
	d100.visible = true
	var l1: Label = d100.get_child(0).get_child(0)
	var l2: Label = d100.get_child(1).get_child(0)
	for k in 14:
		l1.text = "%d0" % randi_range(0, 9)
		l2.text = str(randi_range(0, 9))
		await get_tree().create_timer(0.06).timeout
	l1.text = "%d0" % tens
	l2.text = str(units)
	d100.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(d100, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.1).timeout
	d100.visible = false
	return v


func boss_fight(id: String) -> void:
	busy = true
	btn_act.disabled = true
	var b: Dictionary = bosses[id]
	hero_yaw_goal = atan2(b["home"].x - hero.position.x, b["home"].z - hero.position.z)
	var is_mini: bool = b.get("mini", false)
	if not is_mini and not boss_met.has(id):
		boss_met[id] = true
		var old := [goal, dist_goal]
		cine = true
		goal = b["home"] + Vector3(0, 1.2, 0)
		dist_goal = 10.0
		boss_anim(id, "Cheer")
		narrator.speak("boss_" + id, lines["boss_" + id]["text"], lines["boss_" + id]["who"])
		await narrator.done
		cine = false
		dist_goal = old[1]
	boss_anim(id, "Taunt" if is_mini else "Cheer")
	say(("¡%s te reta a un duelo! " if is_mini else "¡%s te cierra el paso! ") % foe_name(id) + "Los dados de porcentaje deciden el desafío…")
	await get_tree().create_timer(1.0).timeout
	var v: int = await roll_d100()
	var tier: Array = TIERS[3]
	for t in TIERS:
		if v <= t[0]:
			tier = t
			break
	var mates := team()
	var dmg: int = tier[2] * (2 if v == 100 else 1) + attrs["fuerza"] + mates.size()
	if fire:
		dmg *= 2
	var extra := ""
	if not mates.is_empty():
		extra += " (+%d por atacar en equipo)" % mates.size()
	if attrs["fuerza"] > 0:
		extra += " (con tu fuerza)"
	if fire:
		extra += " ¡La espada de fuego lo duplica!"
	say("%d: desafío de nivel %s. Si aciertas, %d de daño%s." % [v, ["Aprendiz", "Experto", "Genio", "Maestro"][tier[1]], dmg, extra])
	await get_tree().create_timer(1.2).timeout
	var c := draw(["riddle", "logic", "math", "skill"][randi() % 4], tier[1])
	var good: bool = await ask(c, tier[1])
	if good:
		fire = false
		play(hero_def.get("atk", "1H_Melee_Attack_Chop"))
		await get_tree().create_timer(0.45).timeout
		boss_anim(id, "Hit_A")
		damage_pop(b["home"] + Vector3(0, 2.6, 0), "-%d" % dmg)
		b["hp"] = maxi(0, b["hp"] - dmg)
		boss_label(id)
		await get_tree().create_timer(0.8).timeout
		play("Idle")
		if b["hp"] == 0:
			await boss_defeated(id)
			return
		say("¡Golpe! %s pierde %d %s; le quedan %d. +15 de experiencia.%s" % [foe_name(id), dmg, "corazón" if dmg == 1 else "corazones", b["hp"], gain_xp(15)])
		busy = false
		btn_act.disabled = false
		rolls_used = 0
		update_stats()
		offer("Atacar otra vez", boss_fight.bind(id))
		return
	boss_anim(id, MINI[id]["atk"] if is_mini else "2H_Melee_Attack_Chop")
	await get_tree().create_timer(0.5).timeout
	play("Hit_A")
	if is_mini and stars > 0:
		stars -= 1
		update_stats()
	# minibosses take half a heart; bosses hit harder the higher the challenge level
	var halves: int = 1 if is_mini else tier[1] + 1
	if hurt(halves):
		await get_tree().create_timer(0.6).timeout
		boss_anim(id, "Idle")
		await fall()
		return
	say("¡%s te golpea! Pierdes %s." % [foe_name(id), "medio corazón" if halves == 1 else ("%d corazones" % (halves / 2) if halves % 2 == 0 else "%d corazón y medio" % (halves / 2))])
	await get_tree().create_timer(1.3).timeout
	busy = false
	btn_act.disabled = false
	after_question(false, "", true)
	boss_anim(id, "Idle")


func damage_pop(at: Vector3, txt: String) -> void:
	var l := Label3D.new()
	l.text = txt
	l.font = font_epic
	l.font_size = 96
	l.pixel_size = 0.01
	l.outline_size = 22
	l.modulate = Color("ffe08a")
	l.outline_modulate = Color("5a1208")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	roots["board"].add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", at + Vector3(0, 1.4, 0), 1.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.tween_callback(l.queue_free)


func boss_defeated(id: String) -> void:
	var b: Dictionary = bosses[id]
	var reward := 2 if b.get("mini", false) else 3
	boss_anim(id, "Death_C_Skeletons" if b.get("mini", false) else "Death_A")
	stars += reward
	var xpw := 30 if b.get("mini", false) else 60
	say("¡Has vencido a %s! +%d estrellas y %d de experiencia.%s" % [foe_name(id), reward, xpw, gain_xp(xpw)])
	update_stats()
	play("Cheer")
	await get_tree().create_timer(1.4).timeout
	var tw := create_tween()
	tw.tween_property(b["model"], "scale", Vector3.ONE * 0.01, 0.6)
	tw.parallel().tween_property(b["label"], "modulate:a", 0.0, 0.6)
	await tw.finished
	b["model"].visible = false
	b["label"].visible = false
	busy = false
	btn_act.disabled = false
	if id == "dragon":
		victory()
		return
	end_turn()


func victory() -> void:
	play("Cheer")
	say("¡Habéis vencido al Dragón Carmesí y salvado el reino! Total: %d estrellas." % stars)
	cine = true
	cine_spin = 0.12
	goal = castle_pos + Vector3(0, 2.0, 0)
	dist_goal = 22.0
	msg.visible = false
	narrator.speak("final", lines["final"]["text"], lines["final"]["who"])
	await narrator.done
	cine = false
	cine_spin = 0.0
	msg.visible = true
	offer("Jugar otra vez", func(): get_tree().reload_current_scene())


# ---------------------------------------------------------------- quests
func quest_at(n: int) -> String:
	for id in QUEST_SPOTS:
		var spot: Vector2i = QUEST_SPOTS[id]["node"]
		if path_nodes[n]["q"] == spot.x and path_nodes[n]["r"] == spot.y:
			return id
	return ""


func npc(parent: Node3D, model: String, show: Array, tint: Color, pos: Vector3, look_at: Vector3, sc: float, name: String) -> Node3D:
	var m: Node3D = load_hero({"id": model, "show": show})
	tint_model(m, tint)
	m.position = pos
	m.scale = Vector3.ONE * sc
	m.rotation.y = atan2(look_at.x - pos.x, look_at.z - pos.z)
	parent.add_child(m)
	var a: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	a.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	a.play("Idle")
	var l := Label3D.new()
	l.text = "!  " + name
	l.font = font_head
	l.font_size = 36
	l.pixel_size = 0.008 if sc < 0.6 else 0.012
	l.outline_size = 12
	l.outline_modulate = Color(0.1, 0.05, 0.0)
	l.modulate = Color("ffd27a")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 2.4 * sc / 0.52 * 0.55 + 0.4, 0)
	parent.add_child(l)
	m.set_meta("label", l)
	return m


func build_npcs() -> void:
	for id in QUEST_SPOTS:
		var spot: Dictionary = QUEST_SPOTS[id]
		var giver: Dictionary = quests[id]["giver"]
		var node_p := hpos(spot["node"].x, spot["node"].y)
		npcs[id] = npc(roots["board"], spot["model"], spot["show"], spot["tint"], hpos(spot["npc"].x, spot["npc"].y), node_p, 0.5, giver["name"].split(",")[0])
	npcs["posada"] = npc(roots["tavern"], "Barbarian", ["Mug", "Barbarian_Cape"], Color(1.15, 0.95, 0.85), Vector3(1.5, 0, -3.6), Vector3(0, 0, 2), 0.72, "Doña Petra")
	var bru := npc(roots["dungeon"], "Barbarian", ["1H_Axe", "Barbarian_Hat"], Color(1.0, 0.9, 0.7), Vector3(-3.2, 0, 1.5), Vector3(0, 0, 4.6), 0.72, "Brunilda")
	bru.scale = Vector3(0.8, 0.62, 0.8)
	npcs["mina"] = bru
	var shop_p: Vector3 = Vector3.ZERO
	for n in path_nodes:
		if n["type"] == "shop":
			shop_p = n["p"]
	var rem := npc(roots["board"], "Rogue", ["Rogue_Cape"], Color(0.8, 1.15, 0.85), hpos(SHOP_NPC.x, SHOP_NPC.y), shop_p, 0.5, "Remigio")
	var rl: Label3D = rem.get_meta("label")
	rl.text = "◈  Remigio · tienda"
	rl.modulate = Color("8ff0b4")


func test_label(t: Dictionary) -> String:
	if t.has("pay"):
		return "Pagar %d ★" % t["pay"]
	if t.has("roll"):
		return "Tirada de %s: %d+ (bono +%d)" % [ATTR_NAME[t["roll"]], t["target"], 10 + attrs[t["roll"]] * 10]
	if t.has("game"):
		return "Reto de habilidad"
	return {"riddle": "Adivinanza", "logic": "Acertijo", "math": "Problema", "skill": "Reto de habilidad"}[t["card"]]


func reward_text(rw: Dictionary) -> String:
	var parts := ["%d ★" % rw["stars"]]
	if rw.has("item"):
		parts.append(ITEM_NAME[rw["item"]])
	if rw.has("attr"):
		parts.append("+1 de %s" % ATTR_NAME[rw["attr"]])
	return "Recompensa: " + ", ".join(parts) + "."


func run_quest(id: String) -> void:
	busy = true
	btn_act.disabled = true
	var q: Dictionary = quests[id]
	var chapters: Array = q.get("chapters", [])
	while true:
		var chap: int = qprog.get(id, 0)
		var part: Dictionary = chapters[chap] if chapters.size() > 0 else q
		var giver: Dictionary = part.get("giver", q["giver"])
		var zone := "Misión · %s" % q["zone"]
		if chapters.size() > 0:
			zone += " · Capítulo %d de %d" % [chap + 1, chapters.size()]
		var title: String = q["title"] + (": " + part["title"] if chapters.size() > 0 else "")
		var opts := []
		for c in part["choices"]:
			opts.append({"label": c["label"], "test": test_label(c["test"]), "disabled": c["test"].has("pay") and stars < c["test"]["pay"]})
		var rw_txt := reward_text(q["reward"])
		if chapters.size() > 0 and chap < chapters.size() - 1:
			rw_txt = "Cada capítulo superado os acerca al final. " + rw_txt.replace("Recompensa:", "Recompensa final:")
		questbox.show_intro(zone, title, giver["name"], part["text"], opts, rw_txt)
		narrator.speak("q_%s_%d" % [id, chap], part["text"])
		var k: int = await questbox.chosen
		narrator.stop()
		var ch: Dictionary = part["choices"][k]
		var clip := "q_%s_%d_%d_" % [id, chap, k]
		var t: Dictionary = ch["test"]
		var ok := false
		var paid := false
		var notes := []
		if t.has("pay"):
			stars -= int(t["pay"])
			ok = true
			paid = true
		elif t.has("roll"):
			var v: int = await roll_d100()
			var bonus: int = 10 + attrs[t["roll"]] * 10 + team().size() * 10
			ok = v + bonus >= int(t["target"])
			notes.append("Tirada: %d + %d = %d (necesitabais %d)" % [v, bonus, v + bonus, t["target"]])
		else:
			var c := draw(t["card"])
			if t.has("game"):
				c["game"] = GAME_FOR.get(t["game"], "memoria")
			ok = await ask(c, level)
		if ok and chapters.size() > 0 and chap < chapters.size() - 1:
			qprog[id] = chap + 1
			notes.append("Capítulo %d superado. +15 de experiencia.%s" % [chap + 1, gain_xp(15)])
			questbox.show_result(true, "¡Capítulo superado!", ch["win"], notes, "Siguiente capítulo")
			narrator.speak(clip + "si", ch["win"])
			await questbox.closed
			narrator.stop()
			continue
		if ok:
			var rw: Dictionary = q["reward"]
			if not paid:
				stars += int(rw["stars"])
				notes.append("+%d ★" % rw["stars"])
			if rw.has("item"):
				if items.size() < MAX_ITEMS:
					items.append(rw["item"])
					notes.append("Objeto: %s" % ITEM_NAME[rw["item"]])
				else:
					stars += int(ITEMS[rw["item"]][0])
					notes.append("Tu bolsa está llena: cambias el objeto (%s) por %d ★" % [ITEM_NAME[rw["item"]], ITEMS[rw["item"]][0]])
			if rw.has("attr"):
				attrs[rw["attr"]] += 1
				relics.append(rw.get("relic", ""))
				notes.append("%s: +1 de %s" % [rw.get("relic", "Reliquia"), ATTR_NAME[rw["attr"]]])
			var rxp: int = int(rw.get("xp", 30))
			notes.append("+%d de experiencia.%s" % [rxp, gain_xp(rxp)])
			quests_done[id] = true
			quest_done_fx(id)
			play("Cheer")
		else:
			notes.append("La misión sigue pendiente: podéis volver a intentarlo. +2 de experiencia.%s" % gain_xp(2))
			if chapters.size() > 0:
				notes.append("No perdéis los capítulos ya superados.")
		update_stats()
		questbox.show_result(ok, "¡Misión cumplida!" if ok else "No ha salido bien", ch["win"] if ok else ch.get("lose", ""), notes, "Continuar")
		if ok or ch.get("lose", "") != "":
			narrator.speak(clip + ("si" if ok else "no"), ch["win"] if ok else ch["lose"])
		await questbox.closed
		narrator.stop()
		break
	busy = false
	btn_act.disabled = false
	play("Idle")
	if mode == "board":
		end_turn("¡Misión cumplida!" if quests_done.has(id) else "Fin del turno.")
	else:
		interior_offer()


func quest_done_fx(id: String) -> void:
	if npcs.has(id):
		var l: Label3D = npcs[id].get_meta("label")
		l.text = l.text.replace("!  ", "✓  ")
		l.modulate = Color("4fd18b")
	if QUEST_SPOTS.has(id):
		var spot: Vector2i = QUEST_SPOTS[id]["node"]
		for m in markers:
			if m["node"]["q"] == spot.x and m["node"]["r"] == spot.y:
				m["ring"].albedo_color = Color("6b6f80")
				m["ring"].emission = Color("6b6f80")
				m["ic"].text = "✓"

# ---------------------------------------------------------------- hero
func load_hero(def: Dictionary) -> Node3D:
	var path := "res://assets/heroes/%s.glb" % def["id"]
	var h: Node3D = scene(path).instantiate()
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		for acc in ACCESSORY:
			if acc in mi.name:
				mi.visible = def["show"].has(String(mi.name))
				break
	return h


func use_hero(def: Dictionary) -> void:
	var old := hero
	hero = load_hero(def)
	hero_def = def
	if old:
		old.queue_free()
	roots[mode].add_child(hero)
	hero_anim = hero.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["Idle", "Walking_A"]:
		if hero_anim.has_animation(n):
			hero_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	apply_scale()
	if mode == "board":
		hero.position = path_nodes[hero_at]["p"] + Vector3(0, 0.02, 0)
		goal = hero.position
	img_hero.texture = load("res://assets/art/%s.jpg" % def["art"])
	lbl_name.text = "%s · %s" % [def["name"], def["title"]]
	play("Cheer")
	await get_tree().create_timer(1.6).timeout
	play("Idle")


func apply_scale() -> void:
	# KayKit adventurers are about 2.4 units tall
	hero.scale = Vector3.ONE * (0.52 if mode == "board" else 0.72)


func play(n: String) -> void:
	if hero_anim and hero_anim.has_animation(n):
		hero_anim.play(n, 0.25)


func walk_to(p: Vector3, dur: float) -> void:
	var d := p - hero.position
	hero_yaw_goal = atan2(d.x, d.z)
	play("Walking_A")
	var tw := create_tween()
	tw.tween_property(hero, "position", Vector3(p.x, hero.position.y, p.z), dur)
	await tw.finished


# ---------------------------------------------------------------- cards
func draw(cat: String, lvl := -1) -> Dictionary:
	if lvl < 0:
		lvl = level
	if cat == "skill":
		return {"cat": "skill", "game": ["memoria", "simon", "faroles"][randi() % 3]}
	var src: Array = bank[cat][lvl]
	var dk := "%s%d" % [cat, lvl]
	if not decks.has(dk) or decks[dk].is_empty():
		var idx := range(src.size())
		idx.shuffle()
		decks[dk] = idx
	var c: Dictionary = src[decks[dk].pop_back()].duplicate(true)
	c["cat"] = cat
	if cat == "logic":
		with_opts(c, lvl)
	return c


func with_opts(c: Dictionary, lvl: int) -> void:
	var a: String = c["a"]
	var d := []
	if c.has("o"):
		d = c["o"].duplicate()
		d.shuffle()
	else:
		var re := RegEx.new()
		re.compile("\\d+")
		var m := re.search(a)
		if m:
			var v := int(m.get_string())
			var pool := [v + 1, v - 1, v + 2, v - 2, v * 2, v + 10, v - 10]
			pool.shuffle()
			for x in pool:
				var t := a.replace(m.get_string(), str(x))
				if x > 1 and t != a and not d.has(t):
					d.append(t)
	if d.size() < 3:
		var others := []
		for x in bank["logic"][lvl]:
			others.append(x["a"])
		others.shuffle()
		for x in others:
			if d.size() >= 3:
				break
			if x != a and not d.has(x):
				d.append(x)
	var opts := [a]
	opts.append_array(d.slice(0, 3))
	opts.shuffle()
	c["opts"] = opts
	c["correct"] = opts.find(a)


func update_stats() -> void:
	var dots := ""
	for i in 3:
		dots += "●" if i >= rolls_used else "○"
	lbl_stats.text = "%s · %d ★ · Tiradas %s" % [["Aprendiz", "Experto", "Genio", "Maestro"][level], stars, dots]
	if lbl_xp:
		var need := xp_need(hero_lv)
		lbl_xp.text = "Nv %d   FUE %d · SAB %d · SUE %d" % [hero_lv, attrs["fuerza"], attrs["sabiduria"], attrs["suerte"]]
		bar_xp.value = 100.0 if hero_lv >= MAX_LV else 100.0 * xp / need
		bar_xp.tooltip_text = "Experiencia %d / %d" % [xp, need]
		btn_bag.text = "Bolsa  %d/%d" % [items.size(), MAX_ITEMS]
		draw_hearts()
		if players.size() > 1:
			refresh_strip()


func max_hp() -> int:
	return max_hp_for(hero_lv)


func max_hp_for(lv: int) -> int:
	return 2 * (3 + (lv - 1) / 3)


func draw_hearts() -> void:
	var n := max_hp() / 2
	while hearts_box.get_child_count() < n:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(26, 26)
		for k in 2:
			var holder := Control.new()
			holder.clip_contents = true
			holder.size = Vector2(26, 28)
			var l := Label.new()
			l.text = "♥"
			l.add_theme_font_size_override("font_size", 24)
			l.add_theme_color_override("font_color", Color(1, 1, 1, 0.22) if k == 0 else Color("ff4d5e"))
			l.position = Vector2(0, -4)
			holder.add_child(l)
			cell.add_child(holder)
		hearts_box.add_child(cell)
	for i in hearts_box.get_child_count():
		var cell: Control = hearts_box.get_child(i)
		cell.visible = i < n
		var fill := clampi(hp - i * 2, 0, 2)
		cell.get_child(1).size.x = 13.0 * fill
	hearts_box.tooltip_text = "Vida: %s de %d corazones" % [str(hp / 2.0).replace(".5", " y medio").replace(".0", ""), n]


## Takes half hearts away. Returns true when the hero falls.
func hurt(halves: int) -> bool:
	hp = maxi(0, hp - halves)
	damage_pop(hero.position + Vector3(0, 2.2, 0), "-%s♥" % ("½" if halves == 1 else str(halves / 2.0).replace(".5", "½").replace(".0", "")))
	update_stats()
	return hp == 0


func heal(halves: int) -> void:
	hp = mini(max_hp(), hp + halves)
	update_stats()


## The hero has no hearts left. An Elixir de vida lifts them at once; otherwise, with no companion on
## the same square (cooperative play is still to come), Doña Petra carries them to the inn.
func fall() -> void:
	busy = true
	btn_act.disabled = true
	play("Death_A")
	say("¡%s se queda sin corazones y cae al suelo!" % hero_def["name"])
	await get_tree().create_timer(2.0).timeout
	if items.has("elixir"):
		items.erase("elixir")
		burst(hero.position + Vector3(0, 1.0, 0), Color("ff7a9a"))
		heal(4)
		play("Cheer")
		say("¡El Elixir de vida brilla y %s se levanta con 2 corazones!" % hero_def["name"])
		await get_tree().create_timer(1.6).timeout
	elif players.size() > 1 and not team_alive().is_empty():
		fallen = true
		mark_fallen(hero, true)
		busy = false
		btn_act.disabled = false
		end_turn("%s ha caído. Un compañero puede levantarle llegando a su casilla o usando un portal." % hero_def["name"])
		return
	else:
		await rescue_at_inn()
		return
	play("Idle")
	busy = false
	btn_act.disabled = false
	end_turn()


## Doña Petra carries a fallen hero to the inn: they lose 2 stars and come back with half their hearts.
func rescue_at_inn() -> void:
	busy = true
	btn_act.disabled = true
	var lost := mini(stars, 2)
	stars -= lost
	fallen = false
	mark_fallen(hero, false)
	await fade_to(1.0)
	var inn := 0
	for i in path_nodes.size():
		if path_nodes[i]["type"] == "tavern":
			inn = i
	hero_at = inn
	trail.clear()
	hero.position = path_nodes[inn]["p"]
	hp = maxi(2, max_hp() / 2)
	update_stats()
	play("Idle")
	await fade_to(0.0)
	place_heroes()
	var note := "Doña Petra te ha recogido y curado en la posada (pierdes %d ★). Vuelves con %d corazones." % [lost, hp / 2]
	play("Idle")
	busy = false
	btn_act.disabled = false
	end_turn(note)


func xp_need(lv: int) -> int:
	return 30 + lv * 20


## Adds experience and returns a note for the message ("¡Subes al nivel 3!") when the hero levels up.
func gain_xp(n: int) -> String:
	if hero_lv >= MAX_LV:
		return ""
	xp += n
	var ups := 0
	while hero_lv < MAX_LV and xp >= xp_need(hero_lv):
		xp -= xp_need(hero_lv)
		hero_lv += 1
		ups += 1
		hp = mini(max_hp(), hp + 2)
	lv_pending += ups
	update_stats()
	return " ¡Subes al nivel %d!" % hero_lv if ups > 0 else ""


func level_up() -> void:
	while lv_pending > 0:
		var rows := []
		for id in ATTR_INFO:
			rows.append({"id": id, "name": "%s   (tienes %d, pasarás a %d)" % [ATTR_NAME[id], attrs[id], attrs[id] + 1], "desc": ATTR_INFO[id][1], "button": "Mejorar"})
		modal.open("¡%s sube al nivel %d!" % [hero_def["name"], hero_lv - lv_pending + 1], "Te has hecho más fuerte. Elige en qué quieres mejorar:", rows, "", load("res://assets/art/%s.jpg" % hero_def["art"]))
		narrator.speak("nivel", "")
		var id: String = await modal.picked
		modal.visible = false
		narrator.stop()
		attrs[id] += 1
		lv_pending -= 1
		burst(hero.position + Vector3(0, 1.2, 0), Color("ffd84a"))
		update_stats()
		say("¡%s mejora! Ahora tienes %d de %s." % [hero_def["name"], attrs[id], ATTR_NAME[id]])


# ---------------------------------------------------------------- flow
func say(t: String) -> void:
	lbl_msg.text = t
	_on_resize.call_deferred()


func offer(label := "", fn := Callable()) -> void:
	# a hero who starts the turn in front of a boss or miniboss has to fight it
	if label == "" and not fn.is_valid() and mode == "board" and not fallen and not path_nodes.is_empty():
		var foe := foe_at(hero_at)
		if foe != "":
			label = "¡A la lucha!"
			fn = boss_fight.bind(foe)
	offer_fn = fn
	btn_act.text = label if label != "" else "Tirar el dado"
	_on_resize.call_deferred()
	if lv_pending > 0 and not modal.visible:
		level_up.call_deferred()


## Opens a question with the hero's bonuses and bag, and waits for the answer.
func ask(c: Dictionary, lvl: int) -> bool:
	qpanel.open(c, lvl, attrs["sabiduria"] * 5.0, items)
	return await qpanel.finished


func on_act() -> void:
	if offer_fn.is_valid():
		var f := offer_fn
		offer()
		f.call()
	else:
		roll_dice()


func roll_dice() -> void:
	if busy or mode != "board":
		return
	busy = true
	btn_act.disabled = true
	var v := randi_range(1, 6)
	var shown := str(v)
	if next_roll == -1:
		var v2 := randi_range(1, 6)
		shown = "%d + %d" % [v, v2]
		v += v2
	elif next_roll > 0:
		v = next_roll
		shown = str(v)
	var how: String = ["", " con el dado doble", " con el dado trucado"][0 if next_roll == 0 else (1 if next_roll == -1 else 2)]
	next_roll = 0
	last_roll = v
	rolls_used += 1
	update_stats()
	lbl_dice.visible = true
	for k in 10:
		lbl_dice.text = str(randi_range(1, 6))
		await get_tree().create_timer(0.055).timeout
	lbl_dice.text = shown
	lbl_dice.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(lbl_dice, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	say("¡Has sacado un %d%s!" % [v, how])
	await get_tree().create_timer(0.8).timeout
	lbl_dice.visible = false
	var n := hero_at
	for s in v:
		var nx: Array = path_nodes[n]["next"]
		if nx.is_empty():
			break
		var to: int = nx[0]
		if nx.size() > 1:
			play("Idle")
			to = await choose_branch(n)
		await walk_to(path_nodes[to]["p"], 0.43)
		trail.append(n)
		n = to
		hero_at = n
		if s < v - 1:
			await revive_here()
		if boss_alive(n):
			break
		if s < v - 1 and path_nodes[n]["type"] == "shop":
			play("Idle")
			await open_shop()
		if s < v - 1 and mini_alive(n):
			var res: String = await mini_curse(path_nodes[n]["mini"])
			if res == "push":
				busy = false
				btn_act.disabled = false
				end_turn()
				return
			if res == "stop":
				break
	play("Idle")
	busy = false
	btn_act.disabled = false
	landed(n)


func landed(n: int) -> void:
	place_heroes()
	await revive_here()
	if mini_alive(n):
		var id: String = path_nodes[n]["mini"]
		if not bosses[id]["awake"]:
			say("¡Sorpresa! Esta casilla escondía a %s." % foe_name(id))
			await reveal_mini(id)
		await boss_fight(id)
		return
	var t: String = path_nodes[n]["type"]
	match t:
		"tavern":
			say("Estás en la puerta de la Posada del Grifo. ¿Entras?")
			offer("Entrar en la posada", enter.bind("tavern"))
		"dungeon":
			say("La entrada de la mina huele a humedad… y a tesoro. ¿Bajas?")
			offer("Bajar a la mazmorra", enter.bind("dungeon"))
		"boss":
			if boss_alive(n):
				await boss_fight(path_nodes[n]["boss"])
			else:
				say("El camino está libre: ya vencisteis a %s." % BOSS[path_nodes[n]["boss"]]["name"])
				end_turn_or_continue()
		"riddle", "logic", "math", "skill":
			busy = true
			btn_act.disabled = true
			var good: bool = await ask(draw(t), level)
			busy = false
			btn_act.disabled = false
			after_question(good, t)
		"shop":
			busy = true
			btn_act.disabled = true
			await open_shop()
			busy = false
			btn_act.disabled = false
			say("Sales de la tienda de Remigio. ¡Tira el dado!")
			end_turn_or_continue()
		"quest":
			var qid := quest_at(n)
			if qid != "" and not quests_done.has(qid):
				await run_quest(qid)
			else:
				say("Aquí ya no queda nada por hacer.")
				end_turn_or_continue()
		"star":
			stars += 1
			play("Cheer")
			say("¡Una estrella! Ya tienes %d." % stars)
			end_turn_or_continue()
		_:
			say("Casilla de %s." % TYPE_NAME.get(t, t))
			end_turn_or_continue()


func after_question(good: bool, cat := "", xp_wrong := true) -> void:
	if good:
		stars += 1
		play("Cheer")
		var amount := 15 if cat == "skill" else 10
		var up := gain_xp(amount)
		var coop := ""
		var mates := team()
		if not mates.is_empty():
			var names := []
			for i in mates:
				players[i]["stars"] += 1
				gain_xp_other(i, amount)
				names.append(players[i]["hero_def"]["name"])
			coop = " ¡Habéis cooperado: %s también gana%s 1 ★!" % [" y ".join(names), "n" if names.size() > 1 else ""]
		update_stats()
		if rolls_used < 3:
			say("¡Muy bien! +1 estrella y %d de experiencia.%s%s Puedes volver a tirar (%d de 3)." % [amount, up, coop, rolls_used + 1])
			offer()
		else:
			end_turn("¡Muy bien! +1 estrella y %d de experiencia.%s%s Ya has usado tus 3 tiradas." % [amount, up, coop])
		return
	play("Hit_A")
	var up := gain_xp(2) if xp_wrong else ""
	var tried := (" +2 de experiencia por intentarlo." if xp_wrong else "") + up
	# in front of a boss or miniboss you hold your ground: next turn you face it again
	var foe := foe_at(hero_at)
	if foe != "":
		end_turn("¡Vaya! No retrocedes: sigues frente a %s y en tu próximo turno volverás a luchar.%s" % [foe_name(foe), tried])
		return
	var steps := mini(2, trail.size())
	if steps == 0:
		end_turn("¡Vaya! Esta vez no ha salido bien.%s" % tried)
		return
	if items.has("escudo"):
		items.erase("escudo")
		burst(hero.position + Vector3(0, 1.0, 0), Color("9fd6ff"))
		end_turn("¡Tu escudo te protege y no retrocedes!%s" % tried)
		return
	say("¡Vaya! Retrocedes %d casilla%s.%s" % [steps, "" if steps == 1 else "s", tried])
	busy = true
	btn_act.disabled = true
	await get_tree().create_timer(0.8).timeout
	for i in steps:
		if trail.is_empty():
			break
		var back: int = trail.pop_back()
		await walk_to(path_nodes[back]["p"], 0.38)
		hero_at = back
	play("Idle")
	place_heroes()
	busy = false
	btn_act.disabled = false
	end_turn("Fin del turno.")


func end_turn_or_continue() -> void:
	end_turn()


## Ends the turn. With several players the next one (in order) takes over.
func end_turn(note := "") -> void:
	rolls_used = 0
	if note != "":
		say(note)
	if players.size() <= 1:
		update_stats()
		offer()
		return
	busy = true
	btn_act.disabled = true
	await get_tree().create_timer(1.6 if note != "" else 0.6).timeout
	save_player()
	load_player((turn + 1) % players.size())
	place_heroes()
	busy = false
	btn_act.disabled = false
	if fallen:
		await fallen_turn()
		return
	var foe := foe_at(hero_at) if mode == "board" else ""
	say("¡Turno de %s! %s" % [hero_def["name"], "Sigues frente a %s: ¡a la lucha!" % foe_name(foe) if foe != "" else "Tira el dado."])
	play("Cheer")
	get_tree().create_timer(1.4).timeout.connect(func(): play("Idle"))
	offer()


func back_to_start() -> void:
	hero_at = 0
	hero.position = path_nodes[0]["p"]
	play("Idle")
	say("De vuelta en la salida.")


func choose_branch(n: int) -> int:
	for c in box_choices.get_children():
		c.queue_free()
	box_choices.visible = true
	_on_resize.call_deferred()
	var opts: Array = path_nodes[n]["next"]
	for i in opts.size():
		var to: int = opts[i]
		var b := big_button("Camino de la Mina" if path_nodes[to]["branch"] == "A" else "Camino del Pueblo")
		b.pressed.connect(func(): branch_chosen.emit(to))
		box_choices.add_child(b)
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.75
		cyl.bottom_radius = 0.75
		cyl.height = 6.0
		cyl.cap_top = false
		cyl.cap_bottom = false
		beam.mesh = cyl
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(1, 0.85, 0.3, 0.25)
		beam.material_override = m
		beam.position = path_nodes[to]["p"] + Vector3(0, 3, 0)
		roots["board"].add_child(beam)
		beacons.append(beam)
	say("¡Un cruce! Elige por dónde seguir.")
	var chosen: int = await branch_chosen
	box_choices.visible = false
	for b in beacons:
		b.queue_free()
	beacons.clear()
	return chosen


func enter(where: String) -> void:
	if busy:
		return
	busy = true
	await fade_to(1.0)
	hero.reparent(roots[where], false)
	set_mode(where)
	apply_scale()
	var sp: Dictionary = spawn[where]
	hero.position = sp["from"]
	hero_yaw = PI
	hero_yaw_goal = PI
	yaw = 0.0
	pitch = 1.0
	dist = sp["dist"]
	dist_goal = sp["dist"]
	target = sp["cam"]
	goal = sp["cam"]
	box_visit.visible = false
	await fade_to(0.0)
	await walk_to(sp["to"], 1.4)
	play("Idle")
	busy = false
	btn_exit.visible = true
	interior_offer()


func interior_offer() -> void:
	if mode == "tavern":
		if not quests_done.has("posada"):
			heal(max_hp())
			say("La Posada del Grifo huele a pan caliente y recuperas todos tus corazones… pero Doña Petra parece preocupada.")
			offer("Hablar con Doña Petra", run_quest.bind("posada"))
		else:
			heal(max_hp())
			say("La Posada del Grifo está tranquila. Doña Petra os sirve tarta y recuperas todos tus corazones.")
			offer("Salir", leave)
	elif mode == "dungeon":
		if not quests_done.has("mina"):
			say("En la mazmorra os espera Brunilda, la enana minera, frente a una puerta con runas.")
			offer("Hablar con Brunilda", run_quest.bind("mina"))
		elif not chest_opened:
			say("La puerta de las runas está abierta. Al fondo brilla un cofre dorado…")
			offer("Abrir el cofre", open_chest)
		else:
			offer("Salir", leave)


func open_chest() -> void:
	if busy:
		return
	busy = true
	await walk_to(chest.position + Vector3(0, 0, 2.4), 1.3)
	hero_yaw_goal = PI
	play("Interact")
	await get_tree().create_timer(0.7).timeout
	coins(chest.position + Vector3(0, 1.6, 0))
	await get_tree().create_timer(0.5).timeout
	play("Cheer")
	chest_opened = true
	stars += 5
	update_stats()
	say("¡Tesoro! Has encontrado 5 estrellas.")
	await get_tree().create_timer(1.6).timeout
	play("Idle")
	busy = false
	offer("Salir", leave)


func coins(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 1.6
	p.explosiveness = 0.95
	p.position = at
	p.direction = Vector3(0, 1, 0.3)
	p.spread = 50.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -12, 0)
	p.angular_velocity_min = 200
	p.angular_velocity_max = 500
	var c := CylinderMesh.new()
	c.top_radius = 0.14
	c.bottom_radius = 0.14
	c.height = 0.04
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffd34a")
	m.metallic = 0.6
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = Color("ffb300")
	m.emission_energy_multiplier = 1.2
	c.material = m
	p.mesh = c
	roots["dungeon"].add_child(p)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)


func leave() -> void:
	if busy:
		return
	busy = true
	await fade_to(1.0)
	var where := mode
	hero.reparent(roots["board"], false)
	set_mode("board")
	apply_scale()
	for i in path_nodes.size():
		if path_nodes[i]["type"] == where:
			hero_at = i
	hero.position = path_nodes[hero_at]["p"]
	yaw = 0.35
	pitch = 0.95
	dist_goal = 15.0
	box_visit.visible = true
	btn_exit.visible = false
	await fade_to(0.0)
	play("Idle")
	busy = false
	offer()
	say("De vuelta en el camino. ¡Tira el dado!")


func fade_to(a: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, 0.45)
	await tw.finished


# ---------------------------------------------------------------- players and turns
func new_player(def: Dictionary) -> Dictionary:
	var h := load_hero(def)
	roots["board"].add_child(h)
	h.scale = Vector3.ONE * 0.52
	h.position = path_nodes[0]["p"] + Vector3(0, 0.02, 0)
	var a: AnimationPlayer = h.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["Idle", "Walking_A"]:
		if a.has_animation(n):
			a.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	a.play("Idle")
	var tag := Label3D.new()
	tag.text = def["name"]
	tag.font = font_head
	tag.font_size = 30
	tag.pixel_size = 0.016
	tag.outline_size = 10
	tag.outline_modulate = Color(0.05, 0.03, 0.1)
	tag.modulate = Color("ffe2a0")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, 3.0, 0)
	tag.name = "tag"
	h.add_child(tag)
	return {"hero_def": def, "hero": h, "hero_anim": a, "hero_at": 0, "hero_yaw": 0.0, "hero_yaw_goal": 0.0, "stars": 0,
		"items": [], "relics": [], "attrs": {"fuerza": 0, "sabiduria": 0, "suerte": 0}, "hero_lv": 1, "xp": 0, "hp": 6,
		"lv_pending": 0, "next_roll": 0, "fire": false, "trail": [], "last_roll": 0, "fallen": false}


func save_player() -> void:
	if players.is_empty():
		return
	for f in PFIELDS:
		players[turn][f] = get(f)


func load_player(i: int) -> void:
	turn = i
	for f in PFIELDS:
		set(f, players[i][f])
	img_hero.texture = load("res://assets/art/%s.jpg" % hero_def["art"])
	lbl_name.text = "%s · %s" % [hero_def["name"], hero_def["title"]]
	if mode == "board":
		goal = hero.position
	update_stats()


## Reads a field of any player (the globals for the one playing now).
func pget(i: int, f: String) -> Variant:
	return get(f) if i == turn else players[i][f]


## Other players standing on my square, still on their feet.
func team() -> Array:
	var out := []
	if mode != "board":
		return out
	for i in players.size():
		if i != turn and not players[i]["fallen"] and players[i]["hero_at"] == hero_at:
			out.append(i)
	return out


func team_alive() -> Array:
	var out := []
	for i in players.size():
		if i != turn and not players[i]["fallen"]:
			out.append(i)
	return out


func gain_xp_other(i: int, n: int) -> void:
	var d: Dictionary = players[i]
	if d["hero_lv"] >= MAX_LV:
		return
	d["xp"] += n
	while d["hero_lv"] < MAX_LV and d["xp"] >= xp_need(d["hero_lv"]):
		d["xp"] -= xp_need(d["hero_lv"])
		d["hero_lv"] += 1
		d["lv_pending"] += 1
		d["hp"] = mini(max_hp_for(d["hero_lv"]), d["hp"] + 2)


## Heroes sharing a square stand around it instead of on top of each other.
func place_heroes() -> void:
	if players.size() < 2:
		return
	var by_node := {}
	for i in players.size():
		var at: int = pget(i, "hero_at")
		if not by_node.has(at):
			by_node[at] = []
		by_node[at].append(i)
	for at in by_node:
		var list: Array = by_node[at]
		for k in list.size():
			var i: int = list[k]
			var h: Node3D = pget(i, "hero")
			if h.get_parent() != roots["board"]:
				continue
			var off := Vector3.ZERO
			if list.size() > 1:
				var ang := TAU * k / list.size() + 0.4
				off = Vector3(cos(ang), 0, sin(ang)) * 0.55
			var tw := create_tween()
			tw.tween_property(h, "position", path_nodes[at]["p"] + off + Vector3(0, 0.02, 0), 0.35)
	refresh_strip()


func mark_fallen(h: Node3D, down: bool) -> void:
	var a: AnimationPlayer = h.find_children("*", "AnimationPlayer", true, false)[0]
	a.play("Death_A" if down else "Idle", 0.25)
	var tag: Label3D = h.get_node("tag")
	var n: String = tag.text.replace("✚ ", "")
	tag.text = "✚ " + n if down else n
	tag.modulate = Color("ff8a8a") if down else Color("ffe2a0")
	refresh_strip()


## Fallen companions on the current square get back up (2 hearts) thanks to the hero who arrives.
func revive_here() -> void:
	if mode != "board" or fallen:
		return
	for i in players.size():
		if i == turn or not players[i]["fallen"] or players[i]["hero_at"] != hero_at:
			continue
		var d: Dictionary = players[i]
		d["fallen"] = false
		d["hp"] = 4
		mark_fallen(d["hero"], false)
		burst(d["hero"].position + Vector3(0, 1.0, 0), Color("ff7a9a"))
		play("Interact")
		var up := gain_xp(10)
		say("¡%s ayuda a %s a levantarse! Vuelve con 2 corazones. +10 de experiencia por ayudar.%s" % [hero_def["name"], d["hero_def"]["name"], up])
		await get_tree().create_timer(1.8).timeout
		play("Idle")


## Turn of a fallen hero: wait for help or go to the inn.
func fallen_turn() -> void:
	if team_alive().is_empty():
		say("Todos los héroes han caído. Doña Petra os recoge a todos.")
		await get_tree().create_timer(1.6).timeout
		await rescue_at_inn()
		return
	var n: int = await pick_options("%s está en el suelo. ¿Qué hace?" % hero_def["name"], ["Esperar ayuda", "Ir a la posada (−2 ★)"], false)
	if n == 0:
		end_turn("%s espera a que un compañero venga a ayudarle." % hero_def["name"])
	else:
		await rescue_at_inn()


func refresh_strip() -> void:
	if not picker:
		return
	for c in picker.get_children():
		picker.remove_child(c)
		c.queue_free()
	for i in players.size():
		var def: Dictionary = pget(i, "hero_def")
		var pc := PanelContainer.new()
		var sb := box_style(Color(0.05, 0.06, 0.14, 0.85), gold if i == turn else Color(1, 1, 1, 0.15), 12, 3 if i == turn else 1)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 4
		sb.content_margin_bottom = 2
		pc.add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		pc.add_child(col)
		var t := TextureRect.new()
		t.texture = load("res://assets/art/%s.jpg" % def["art"])
		t.custom_minimum_size = Vector2(64, 64)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if pget(i, "fallen"):
			t.modulate = Color(0.5, 0.4, 0.4)
		col.add_child(t)
		var l := Label.new()
		l.text = "%s%d★ ♥%s" % ["✚ " if pget(i, "fallen") else "", pget(i, "stars"), str(pget(i, "hp") / 2.0).replace(".5", "½").replace(".0", "")]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", font_bold)
		l.add_theme_font_size_override("font_size", 14)
		col.add_child(l)
		picker.add_child(pc)
	_on_resize.call_deferred()


# ---------------------------------------------------------------- choosing the party
func choose_party() -> void:
	party_ui.visible = true
	var chosen := []
	var row: HBoxContainer = party_ui.get_node("col/row")
	var info: Label = party_ui.get_node("col/info")
	var go: Button = party_ui.get_node("col/go")
	for c in row.get_children():
		row.remove_child(c)
		c.queue_free()
	var badges := []
	for def in HEROES:
		var cell := VBoxContainer.new()
		var b := TextureButton.new()
		b.texture_normal = load("res://assets/art/%s.jpg" % def["art"])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		b.custom_minimum_size = Vector2(150, 150)
		cell.add_child(b)
		var n := Label.new()
		n.text = def["name"]
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_font_override("font", font_head)
		n.add_theme_font_size_override("font_size", 26)
		cell.add_child(n)
		var badge := Label.new()
		badge.add_theme_font_override("font", font_epic)
		badge.add_theme_font_size_override("font_size", 54)
		badge.add_theme_color_override("font_color", Color("ffd27a"))
		badge.add_theme_color_override("font_outline_color", Color("2a1204"))
		badge.add_theme_constant_override("outline_size", 14)
		badge.position = Vector2(8, -6)
		b.add_child(badge)
		badges.append([def, badge, b])
		row.add_child(cell)
	var paint := func():
		for x in badges:
			var k: int = chosen.find(x[0])
			x[1].text = str(k + 1) if k >= 0 else ""
			x[2].modulate = Color.WHITE if k >= 0 else Color(0.55, 0.55, 0.65)
		go.disabled = chosen.is_empty()
		info.text = "Tocad los héroes que vais a jugar, en el orden de los turnos (de 1 a 4 jugadores)." if chosen.is_empty() else "%d jugador%s: %s" % [chosen.size(), "" if chosen.size() == 1 else "es", ", ".join(chosen.map(func(d): return d["name"]))]
	for x in badges:
		var def: Dictionary = x[0]
		x[2].pressed.connect(func():
			if chosen.has(def):
				chosen.erase(def)
			elif chosen.size() < 4:
				chosen.append(def)
			paint.call())
	paint.call()
	await go.pressed
	party_ui.visible = false
	# replace the title-screen hero with the party
	if hero:
		hero.queue_free()
	players.clear()
	for def in chosen:
		players.append(new_player(def))
	load_player(0)
	place_heroes()


func build_party_ui() -> void:
	party_ui = Control.new()
	party_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(party_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.07, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	party_ui.add_child(shade)
	var col := VBoxContainer.new()
	col.name = "col"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	party_ui.add_child(col)
	var t := Label.new()
	t.text = "¿Quién juega?"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", font_epic)
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color("ffd27a"))
	col.add_child(t)
	var info := Label.new()
	info.name = "info"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 22)
	col.add_child(info)
	var row := HBoxContainer.new()
	row.name = "row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var go := big_button("  ¡A jugar!  ")
	go.name = "go"
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(go)
	party_ui.visible = false


# ---------------------------------------------------------------- shop and bag
func open_shop() -> void:
	hero_yaw_goal = atan2(hpos(SHOP_NPC.x, SHOP_NPC.y).x - hero.position.x, hpos(SHOP_NPC.x, SHOP_NPC.y).z - hero.position.z)
	if stars < 2:
		narrator.speak("tienda_pobre", "")
		say("Remigio el buhonero te enseña sus cosas, pero no tienes estrellas suficientes.")
		await get_tree().create_timer(2.2).timeout
		return
	narrator.speak("tienda", "")
	while true:
		var rows := []
		for id in ITEMS:
			var it: Array = ITEMS[id]
			rows.append({"id": id, "name": ITEM_NAME[id], "desc": it[2], "button": "%d ★" % it[0], "enabled": stars >= it[0] and items.size() < MAX_ITEMS})
		var bag := "Tu bolsa está vacía." if items.is_empty() else "En tu bolsa: " + ", ".join(items.map(func(x): return ITEM_NAME[x]))
		modal.open("La tienda de Remigio", "%s · %d ★ · objetos %d/%d. %s" % [hero_def["name"], stars, items.size(), MAX_ITEMS, bag], rows, "Salir de la tienda", load("res://assets/art/merchant.jpg") if ResourceLoader.exists("res://assets/art/merchant.jpg") else null)
		var r: Array = await _modal_result()
		if r[0] == "":
			break
		var id: String = r[0]
		if stars >= ITEMS[id][0] and items.size() < MAX_ITEMS:
			stars -= int(ITEMS[id][0])
			items.append(id)
			coins_at(hero.position + Vector3(0, 1.4, 0))
			update_stats()
	narrator.stop()
	modal.visible = false


## Waits for either a row (returns [id]) or the close button (returns [""]).
func _modal_result() -> Array:
	var out := []
	var f1 := func(id): out.append(id)
	var f2 := func(): out.append("")
	modal.picked.connect(f1, CONNECT_ONE_SHOT)
	modal.closed.connect(f2, CONNECT_ONE_SHOT)
	while out.is_empty():
		await get_tree().process_frame
	if modal.picked.is_connected(f1):
		modal.picked.disconnect(f1)
	if modal.closed.is_connected(f2):
		modal.closed.disconnect(f2)
	return out


func open_bag() -> void:
	if busy or modal.visible:
		return
	var rows := []
	var seen := {}
	for id in items:
		if seen.has(id):
			continue
		seen[id] = true
		var when: String = ITEMS[id][1]
		var n := items.count(id)
		var can := when == "r" and mode == "board" and offer_fn.is_null()
		var btn := "Usar" if when == "r" else ("En preguntas" if when == "q" else "Automático")
		rows.append({"id": id, "name": ITEM_NAME[id] + (" ×%d" % n if n > 1 else ""), "desc": ITEMS[id][2], "button": btn, "enabled": can})
	var rel := "" if relics.is_empty() else " Reliquias: " + ", ".join(relics.filter(func(x): return x != "")) + "."
	modal.open("Bolsa de %s" % hero_def["name"], ("Llevas %d de %d objetos." % [items.size(), MAX_ITEMS] if not items.is_empty() else "Tu bolsa está vacía. Compra objetos en la tienda de Remigio (◈) o gánalos en las misiones.") + rel, rows, "Cerrar", load("res://assets/art/%s.jpg" % hero_def["art"]))
	var r: Array = await _modal_result()
	modal.visible = false
	if r[0] != "":
		use_item(r[0])


func use_item(id: String) -> void:
	match id:
		"doble":
			items.erase(id)
			next_roll = -1
			say("Dado doble preparado: tu próxima tirada suma dos dados.")
		"pocion":
			if hp >= max_hp():
				say("Ya tienes todos los corazones: guarda la poción para luego.")
				return
			items.erase(id)
			heal(2)
			burst(hero.position + Vector3(0, 1.0, 0), Color("ff7a9a"))
			say("Te bebes la poción: recuperas 1 corazón.")
		"espada":
			items.erase(id)
			fire = true
			say("¡La espada arde! Tu próximo golpe acertado hará el doble de daño.")
		"trucado":
			var n: int = await pick_options("¿Qué número quieres sacar?", ["1", "2", "3", "4", "5", "6"])
			if n < 0:
				return
			items.erase(id)
			next_roll = n + 1
			say("Dado trucado: tu próxima tirada será un %d." % next_roll)
		"portal":
			var dest := ["tavern", "dungeon", "shop"]
			var labels := ["Posada del Grifo", "Entrada de la mina", "Tienda de Remigio"]
			var who := []
			for i in players.size():
				if i != turn:
					who.append(i)
					labels.append("Junto a " + players[i]["hero_def"]["name"])
			var n: int = await pick_options("¿Adónde quieres viajar?", labels)
			if n < 0:
				return
			items.erase(id)
			var to := 0
			if n >= 3:
				to = players[who[n - 3]]["hero_at"]
			else:
				for i in path_nodes.size():
					if path_nodes[i]["type"] == dest[n]:
						to = i
			burst(hero.position + Vector3(0, 1.0, 0), Color("9fd6ff"))
			trail.append(hero_at)
			hero_at = to
			hero.position = path_nodes[to]["p"]
			burst(hero.position + Vector3(0, 1.0, 0), Color("9fd6ff"))
			update_stats()
			landed(to)
			return
	update_stats()


## Shows a row of big buttons and returns the index chosen (or -1 for «Cancelar»).
func pick_options(question: String, labels: Array, can_cancel := true) -> int:
	for c in box_choices.get_children():
		c.queue_free()
	box_choices.visible = true
	var out := []
	for i in labels.size():
		var b := big_button(labels[i])
		b.custom_minimum_size.x = 96 if labels[i].length() < 3 else 0
		b.pressed.connect(func(): out.append(i))
		box_choices.add_child(b)
	if can_cancel:
		var c := Button.new()
		c.text = "Cancelar"
		c.custom_minimum_size = Vector2(0, 64)
		c.pressed.connect(func(): out.append(-1))
		box_choices.add_child(c)
	say(question)
	_on_resize.call_deferred()
	while out.is_empty():
		await get_tree().process_frame
	box_choices.visible = false
	return out[0]


func coins_at(at: Vector3) -> void:
	burst(at, Color("ffd34a"))


# ---------------------------------------------------------------- title and intro
const SHOTS := [
	{"at": "castle", "dist": 20.0, "yaw": 0.9, "pitch": 1.02, "spin": 0.05},
	{"at": "dragon", "dist": 9.0, "yaw": 1.7, "pitch": 1.12, "spin": 0.08},
	{"at": "troll", "dist": 9.0, "yaw": 0.4, "pitch": 1.08, "spin": 0.06, "then": "golem", "then_at": 0.5},
	{"at": "esbirro", "dist": 8.0, "yaw": -0.4, "pitch": 1.1, "spin": 0.08},
	{"at": "hero", "dist": 9.0, "yaw": -0.6, "pitch": 1.0, "spin": 0.1},
]


func shot_pos(k: String) -> Vector3:
	if k == "castle":
		return castle_pos + Vector3(0, 2.0, 0)
	if k == "hero":
		return hero.position + Vector3(0, 0.8, 0)
	return bosses[k]["home"] + Vector3(0, 1.2, 0)


func set_hud(on: bool) -> void:
	for n in hud:
		n.visible = on
	box_visit.visible = on and mode == "board"
	_on_resize.call_deferred()


## ES GAMES logo on black, then the title over the board.
func show_splash() -> void:
	set_hud(false)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/art/esgames.jpg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.modulate.a = 0.0
	bg.add_child(logo)
	var tw := create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 0.8)
	tw.tween_interval(1.8)
	tw.tween_property(logo, "modulate:a", 0.0, 0.6)
	tw.tween_property(bg, "color:a", 0.0, 0.7)
	await tw.finished
	bg.queue_free()


func show_title() -> void:
	set_hud(false)
	cine = true
	cine_spin = 0.06
	goal = Vector3(0, 0, 0)
	dist_goal = 30.0
	pitch = 0.85
	title_ui.visible = true


func start_game(with_intro: bool) -> void:
	title_ui.visible = false
	await choose_party()
	if with_intro:
		await play_intro()
	cine = false
	cine_spin = 0.0
	yaw = 0.35
	pitch = 0.95
	dist_goal = 15.0
	set_hud(true)
	refresh_strip()
	if players.size() > 1:
		say("¡Bienvenidos al reino! Empieza %s. Si compartís casilla, cooperáis: ganáis juntos y podéis levantar a un compañero caído." % hero_def["name"])
	else:
		say("¡Bienvenido al reino, %s! Tira el dado para avanzar por el camino." % hero_def["name"])
	offer()


func play_intro() -> void:
	skip_intro = false
	for b in bars:
		b.visible = true
	btn_skip.visible = true
	_on_resize()
	for k in SHOTS.size():
		if skip_intro:
			break
		var sh: Dictionary = SHOTS[k]
		goal = shot_pos(sh["at"])
		dist_goal = sh["dist"]
		cine_spin = sh["spin"]
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(self, "yaw", sh["yaw"], 2.2)
		tw.parallel().tween_property(self, "pitch", sh["pitch"], 2.2)
		var shown := false
		if sh["at"] == "esbirro" and not bosses["esbirro"]["awake"]:
			bosses["esbirro"]["model"].visible = true
			boss_anim("esbirro", "Spawn_Ground_Skeletons")
			shown = true
		var id := "intro_%d" % (k + 1)
		narrator.speak(id, lines[id]["text"], lines[id]["who"])
		if sh.has("then"):
			var nxt: String = sh["then"]
			var dur := 6.0
			if narrator.player.stream and narrator.player.playing:
				dur = narrator.player.stream.get_length()
			get_tree().create_timer(dur * sh["then_at"]).timeout.connect(func():
				if not skip_intro:
					goal = shot_pos(nxt))
		await narrator.done
		if shown:
			bosses["esbirro"]["model"].visible = false
		if not skip_intro:
			await get_tree().create_timer(0.35).timeout
	for b in bars:
		b.visible = false
	btn_skip.visible = false


func build_title() -> void:
	title_ui = Control.new()
	title_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(title_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.07, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ui.add_child(shade)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_ui.add_child(col)
	var mark := TextureRect.new()
	mark.texture = load("res://assets/art/esgames_mark.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(220, 110)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pres := Label.new()
	pres.text = "presenta"
	pres.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pres.add_theme_font_override("font", font_head)
	pres.add_theme_font_size_override("font_size", 24)
	pres.add_theme_color_override("font_color", Color("e9d7b0"))
	col.add_child(mark)
	col.add_child(pres)
	var t := Label.new()
	t.text = "El Camino de los Enigmas"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", font_epic)
	t.add_theme_font_size_override("font_size", 92)
	t.add_theme_color_override("font_color", Color("ffd27a"))
	t.add_theme_color_override("font_outline_color", Color("2a1204"))
	t.add_theme_constant_override("outline_size", 18)
	col.add_child(t)
	var sub := Label.new()
	sub.text = "Un reino de adivinanzas, acertijos y retos. Solo una mente despierta lo salvará."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	sub.add_theme_constant_override("outline_size", 6)
	col.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	var go := big_button("  Empezar la aventura  ")
	go.pressed.connect(start_game.bind(true))
	row.add_child(go)
	var quick := Button.new()
	quick.text = "Jugar sin la historia"
	quick.custom_minimum_size = Vector2(0, 64)
	quick.add_theme_font_size_override("font_size", 22)
	quick.pressed.connect(start_game.bind(false))
	row.add_child(quick)
	title_ui.visible = false
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		ui.add_child(bar)
		bars.append(bar)
	btn_skip = Button.new()
	btn_skip.text = "Saltar  ▸▸"
	btn_skip.custom_minimum_size = Vector2(150, 52)
	btn_skip.add_theme_font_size_override("font_size", 22)
	btn_skip.visible = false
	btn_skip.pressed.connect(func():
		skip_intro = true
		narrator.stop())
	ui.add_child(btn_skip)


# ---------------------------------------------------------------- per frame
func _process(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if bosses.has("dragon") and bosses["dragon"]["model"].visible:
		var dm: Node3D = bosses["dragon"]["model"]
		var f := sin(t * 2.6) * 0.35
		dm.get_meta("wing0").rotation.z = f
		dm.get_meta("wing1").rotation.z = -f
		dm.position.y = bosses["dragon"]["home"].y + sin(t * 1.3) * 0.15
	if hero:
		hero_yaw += wrapf(hero_yaw_goal - hero_yaw, -PI, PI) * minf(1.0, dt * 10.0)
		hero.rotation.y = hero_yaw
		if mode == "board" and not cine:
			goal = hero.position + Vector3(0, 0.6, 0)
	if cine:
		yaw += cine_spin * dt
	if mode == "board":
		for i in markers.size():
			markers[i]["ic"].position.y = 0.95 + sin(t * 2.2 + i) * 0.08
			markers[i]["ring"].emission_energy_multiplier = 1.1 + sin(t * 3.0 + i) * 0.4
		for i in clouds.size():
			clouds[i].position.x += dt * (0.25 + i * 0.03)
			if clouds[i].position.x > 30:
				clouds[i].position.x = -30
	for tr in torches:
		tr["light"].light_energy = tr["base"] * (1.0 + sin(t * 13.0 + tr["ph"]) * 0.08 + sin(t * 23.0 + tr["ph"] * 2.0) * 0.06)
	target = target.lerp(goal, minf(1.0, dt * 3.0))
	dist += (dist_goal - dist) * minf(1.0, dt * 4.0)
	var sp := sin(pitch)
	var cp := cos(pitch)
	cam.position = target + Vector3(dist * sp * sin(yaw), dist * cp, dist * sp * cos(yaw))
	cam.look_at(target)


func _unhandled_input(e: InputEvent) -> void:
	# testing shortcuts on a keyboard: 1 riddle, 2 logic, 3 problem, 4-6 skill games
	if e is InputEventKey and e.pressed and not busy and mode == "board":
		var k: int = e.keycode - KEY_1
		if e.keycode == KEY_0:
			stars += 10
			update_stats()
			busy = true
			await open_shop()
			busy = false
			return
		if e.keycode == KEY_L:
			gain_xp(60)
			offer()
			return
		if k == 8:
			run_quest("invierno")
			return
		if k == 7:
			for id in MINI:
				if bosses[id]["hp"] > 0:
					hero_at = bosses[id]["node"]
					hero.position = path_nodes[hero_at]["p"]
					landed(hero_at)
					return
		if k == 6:
			for id in bosses:
				if bosses[id]["hp"] > 0:
					hero_at = bosses[id]["node"]
					hero.position = path_nodes[hero_at]["p"]
					boss_fight(id)
					return
		if k >= 0 and k <= 5 and not busy:
			busy = true
			var c := draw(["riddle", "logic", "math", "skill", "skill", "skill"][k])
			if k >= 3:
				c["game"] = ["memoria", "simon", "faroles"][k - 3]
			var good: bool = await ask(c, level)
			busy = false
			after_question(good, c["cat"])
			return
	if e is InputEventScreenTouch:
		if e.pressed:
			touches[e.index] = e.position
		else:
			touches.erase(e.index)
		pinch0 = 0.0
	elif e is InputEventScreenDrag:
		touches[e.index] = e.position
		if touches.size() == 2:
			var pts: Array = touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if pinch0 > 0.0:
				dist_goal = clampf(dist_goal * pinch0 / d, 6.0, 34.0)
			pinch0 = d
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) and touches.size() < 2:
		yaw -= e.relative.x * 0.006
		pitch = clampf(pitch - e.relative.y * 0.004, 0.55, 1.35)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist_goal = clampf(dist_goal * 0.9, 6.0, 34.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist_goal = clampf(dist_goal * 1.1, 6.0, 34.0)


# ---------------------------------------------------------------- UI
func box_style(bg: Color, border: Color, radius := 16, bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func big_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_override("font", font_head)
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", Color("2b1a05"))
	b.add_theme_color_override("font_hover_color", Color("2b1a05"))
	b.add_theme_color_override("font_pressed_color", Color("2b1a05"))
	b.add_theme_color_override("font_disabled_color", Color(0.17, 0.1, 0.02, 0.5))
	var n := box_style(Color("f2c14e"), Color("1a1222"), 18, 3)
	n.shadow_color = Color("a8761c")
	n.shadow_offset = Vector2(0, 5)
	n.shadow_size = 1
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("focus", n)
	var p: StyleBoxFlat = n.duplicate()
	p.bg_color = Color("e0aa35")
	b.add_theme_stylebox_override("pressed", p)
	var d: StyleBoxFlat = n.duplicate()
	d.bg_color = Color(0.95, 0.76, 0.3, 0.55)
	b.add_theme_stylebox_override("disabled", d)
	return b


func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var th := Theme.new()
	th.default_font = font_body
	th.default_font_size = 22
	th.set_stylebox("normal", "Button", box_style(panel_bg, Color(0.95, 0.76, 0.3, 0.45), 14, 1))
	th.set_stylebox("hover", "Button", box_style(Color(0.1, 0.12, 0.25, 0.9), gold, 14, 1))
	th.set_stylebox("pressed", "Button", box_style(Color(0.15, 0.13, 0.3, 0.95), gold, 14, 2))
	th.set_stylebox("focus", "Button", box_style(Color(0, 0, 0, 0), gold, 14, 2))
	th.set_stylebox("panel", "PanelContainer", box_style(panel_bg, Color(0.95, 0.76, 0.3, 0.45), 16, 1))
	th.set_color("font_color", "Button", ink)
	th.set_color("font_color", "Label", ink)
	ui.theme = th

	# hero card
	var card := PanelContainer.new()
	card.position = Vector2(24, 18)
	ui.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	img_hero = TextureRect.new()
	img_hero.custom_minimum_size = Vector2(72, 72)
	img_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(img_hero)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	lbl_name = Label.new()
	lbl_name.add_theme_font_override("font", font_head)
	lbl_name.add_theme_font_size_override("font_size", 32)
	lbl_name.add_theme_color_override("font_color", Color("ffe2a0"))
	col.add_child(lbl_name)
	lbl_stats = Label.new()
	lbl_stats.add_theme_font_size_override("font_size", 19)
	lbl_stats.add_theme_color_override("font_color", Color("c9cde0"))
	col.add_child(lbl_stats)
	hearts_box = HBoxContainer.new()
	hearts_box.add_theme_constant_override("separation", 2)
	hearts_box.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(hearts_box)
	var lv := OptionButton.new()
	for name in ["Aprendiz · 6 a 8 años", "Experto · 8 a 10 años", "Genio · 10 a 13 años", "Maestro · adultos"]:
		lv.add_item(name)
	lv.selected = level
	lv.add_theme_font_size_override("font_size", 17)
	lv.item_selected.connect(func(i):
		level = i
		update_stats())
	col.add_child(lv)
	lbl_xp = Label.new()
	lbl_xp.add_theme_font_override("font", font_bold)
	lbl_xp.add_theme_font_size_override("font_size", 17)
	lbl_xp.add_theme_color_override("font_color", Color("ffe7b8"))
	col.add_child(lbl_xp)
	bar_xp = ProgressBar.new()
	bar_xp.show_percentage = false
	bar_xp.custom_minimum_size = Vector2(0, 8)
	var xfill := StyleBoxFlat.new()
	xfill.bg_color = Color("8fd6ff")
	xfill.set_corner_radius_all(4)
	var xbg := StyleBoxFlat.new()
	xbg.bg_color = Color(1, 1, 1, 0.12)
	xbg.set_corner_radius_all(4)
	bar_xp.add_theme_stylebox_override("fill", xfill)
	bar_xp.add_theme_stylebox_override("background", xbg)
	col.add_child(bar_xp)
	hud.append(card)

	# hero picker
	picker = HBoxContainer.new()
	picker.add_theme_constant_override("separation", 8)
	ui.add_child(picker)
	hud.append(picker)

	btn_bag = Button.new()
	btn_bag.custom_minimum_size = Vector2(150, 50)
	btn_bag.add_theme_font_size_override("font_size", 20)
	btn_bag.pressed.connect(open_bag)
	ui.add_child(btn_bag)
	hud.append(btn_bag)
	btn_voice = Button.new()
	btn_voice.text = "🔊 Voz"
	btn_voice.custom_minimum_size = Vector2(110, 50)
	btn_voice.add_theme_font_size_override("font_size", 20)
	btn_voice.pressed.connect(func():
		narrator.set_muted(not narrator.muted)
		btn_voice.text = "🔇 Sin voz" if narrator.muted else "🔊 Voz")
	ui.add_child(btn_voice)

	# bottom-left: places
	box_visit = HBoxContainer.new()
	box_visit.add_theme_constant_override("separation", 8)
	ui.add_child(box_visit)
	for pair in [["Entrar en la posada", "tavern"], ["Bajar a la mazmorra", "dungeon"]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func():
			if not busy:
				enter(pair[1]))
		box_visit.add_child(b)

	# message
	var msg_panel := PanelContainer.new()
	msg_panel.custom_minimum_size = Vector2(560, 0)
	msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(msg_panel)
	msg = msg_panel
	hud.append(msg_panel)
	lbl_msg = Label.new()
	lbl_msg.text = "¡Bienvenidos al reino! Tirad el dado para avanzar por el camino."
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.custom_minimum_size = Vector2(540, 0)
	lbl_msg.add_theme_font_size_override("font_size", 21)
	msg_panel.add_child(lbl_msg)

	# main action
	btn_act = big_button("Tirar el dado")
	btn_act.pressed.connect(on_act)
	ui.add_child(btn_act)
	hud.append(btn_act)

	# fork choices
	box_choices = HBoxContainer.new()
	box_choices.add_theme_constant_override("separation", 16)
	box_choices.visible = false
	ui.add_child(box_choices)

	# dice
	lbl_dice = Label.new()
	lbl_dice.add_theme_font_override("font", font_epic)
	lbl_dice.add_theme_font_size_override("font_size", 150)
	lbl_dice.add_theme_color_override("font_color", Color("ffe08a"))
	lbl_dice.add_theme_color_override("font_outline_color", Color("5a3208"))
	lbl_dice.add_theme_constant_override("outline_size", 24)
	lbl_dice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_dice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_dice.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_dice.pivot_offset = Vector2(640, 300)
	lbl_dice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_dice.visible = false
	ui.add_child(lbl_dice)

	d100 = HBoxContainer.new()
	d100.add_theme_constant_override("separation", 18)
	d100.visible = false
	d100.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(d100)
	for i in 2:
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("7a1b26") if i == 0 else Color("2d4f9e")
		sb.border_color = Color("f2c14e")
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(28)
		sb.content_margin_left = 26
		sb.content_margin_right = 26
		pc.add_theme_stylebox_override("panel", sb)
		pc.custom_minimum_size = Vector2(150, 140)
		var l := Label.new()
		l.add_theme_font_override("font", font_epic)
		l.add_theme_font_size_override("font_size", 92)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pc.add_child(l)
		d100.add_child(pc)

	btn_exit = Button.new()
	btn_exit.text = "Salir"
	btn_exit.custom_minimum_size = Vector2(150, 56)
	btn_exit.add_theme_font_size_override("font_size", 22)
	btn_exit.visible = false
	btn_exit.pressed.connect(func():
		if not busy:
			offer()
			leave())
	ui.add_child(btn_exit)

	qpanel = preload("res://question_panel.gd").new()
	ui.add_child(qpanel)
	qpanel.setup({"head": font_head, "bold": font_bold, "epic": font_epic, "body": font_body})
	questbox = preload("res://quest_box.gd").new()
	ui.add_child(questbox)
	questbox.setup({"head": font_head, "bold": font_bold, "epic": font_epic, "body": font_body})
	modal = preload("res://modal_box.gd").new()
	ui.add_child(modal)
	modal.setup({"head": font_head, "bold": font_bold, "epic": font_epic, "body": font_body})
	qpanel.item_used.connect(func(_id): update_stats())
	ui.move_child(qpanel, -1)
	narrator = preload("res://narrator.gd").new()
	ui.add_child(narrator)
	narrator.setup({"head": font_head, "bold": font_bold, "epic": font_epic, "body": font_body})
	build_title()
	build_party_ui()
	ui.move_child(btn_voice, -1)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	update_stats()


func _on_resize() -> void:
	# place the HUD by hand so it always hugs the screen edges
	var sz := get_viewport().get_visible_rect().size
	var m := 24.0
	lbl_dice.pivot_offset = sz * 0.5
	picker.reset_size()
	picker.position = Vector2(sz.x - picker.size.x - m, 18)
	btn_exit.reset_size()
	btn_exit.position = Vector2(m, sz.y - btn_exit.size.y - m)
	box_visit.reset_size()
	box_visit.position = Vector2(m, sz.y - box_visit.size.y - m)
	btn_act.reset_size()
	btn_act.position = Vector2(sz.x - btn_act.size.x - m, sz.y - btn_act.size.y - m - 6)
	msg.reset_size()
	msg.position = Vector2((sz.x - msg.size.x) * 0.5, sz.y - msg.size.y - 104)
	d100.reset_size()
	d100.pivot_offset = d100.size * 0.5
	d100.position = Vector2((sz.x - d100.size.x) * 0.5, sz.y * 0.13)
	box_choices.reset_size()
	box_choices.position = (sz - box_choices.size) * 0.5
	btn_bag.reset_size()
	btn_bag.position = Vector2(sz.x - btn_bag.size.x - m, picker.position.y + picker.size.y + 10)
	btn_voice.reset_size()
	btn_voice.position = Vector2(btn_bag.position.x - btn_voice.size.x - 10, btn_bag.position.y)
	if not btn_bag.visible:
		btn_voice.position = Vector2(sz.x - btn_voice.size.x - m, 18)
	var bh := sz.y * 0.085
	if bars.size() == 2:
		bars[0].position = Vector2.ZERO
		bars[0].size = Vector2(sz.x, bh)
		bars[1].position = Vector2(0, sz.y - bh)
		bars[1].size = Vector2(sz.x, bh)
		btn_skip.reset_size()
		btn_skip.position = Vector2(sz.x - btn_skip.size.x - m, sz.y - btn_skip.size.y - 12)

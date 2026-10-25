extends Node3D
## El Camino de los Enigmas: demo del reino en Godot.
## Builds the hex board, the tavern and the dungeon from KayKit pieces, and runs the dice walk.

signal branch_chosen(index: int)

const HEROES := [
	{"id": "Knight", "name": "Auron", "title": "El Caballero", "art": "caballero", "show": ["1H_Sword", "Badge_Shield", "Knight_Helmet", "Knight_Cape"]},
	{"id": "Barbarian", "name": "Ragnar", "title": "El Bárbaro", "art": "barbaro", "show": ["2H_Axe", "Barbarian_Hat", "Barbarian_Cape"]},
	{"id": "Mage", "name": "Ignara", "title": "La Archimaga", "art": "maga", "show": ["2H_Staff", "Mage_Hat", "Mage_Cape"]},
	{"id": "Rogue", "name": "Sylwen", "title": "La Arquera", "art": "arquera", "show": ["1H_Crossbow", "Rogue_Cape"]},
	{"id": "Rogue_Hooded", "name": "Vex", "title": "El Asesino", "art": "ninja", "show": ["Knife", "Knife_Offhand", "Rogue_Cape"]},
]
const ACCESSORY := ["Sword", "Shield", "Axe", "Mug", "Spellbook", "Wand", "Staff", "Crossbow", "Knife", "Throwable", "Helmet", "Hat", "Cape"]
const HX := 2.0
const HZ := 1.7320508
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const ROAD := {"A": [3, 0], "B": [3, 1], "C": [3, 2], "D": [3, 1, 5], "M": [3]}
const TYPE := {
	"start": [Color("f4efe2"), "▶"], "riddle": [Color("8b5bd6"), "?"], "logic": [Color("13917e"), "◆"], "math": [Color("e2602f"), "+"],
	"skill": [Color("2f6fe0"), "✦"], "star": [Color("e9a917"), "★"], "quest": [Color("d08a2a"), "!"], "fork": [Color("ffd84a"), "⇆"],
	"tavern": [Color("ffb347"), "⌂"], "dungeon": [Color("9b5cff"), "☗"], "boss": [Color("c8323f"), "☠"],
}
const TYPE_NAME := {"riddle": "adivinanza", "logic": "acertijo", "math": "problema", "skill": "reto de habilidad", "star": "estrella", "quest": "misión", "fork": "cruce", "start": "salida"}

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
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.far = 300.0
	add_child(cam)
	world_env = WorldEnvironment.new()
	add_child(world_env)
	build_path()
	build_board()
	build_tavern()
	build_dungeon()
	build_ui()
	set_mode("board")
	await use_hero(HEROES[0])
	target = goal


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
	for a in [[-7, 0, "start"], [-6, 0, "riddle"], [-5, 0, "tavern"], [-4, 0, "math"], [-3, 0, "fork"]]:
		main.append(add_node(a[0], a[1], a[2]))
	var A := []
	for a in [[-2, -1, "logic"], [-1, -2, "star"], [0, -2, "dungeon"], [1, -2, "skill"], [1, -1, "riddle"]]:
		A.append(add_node(a[0], a[1], a[2], "A"))
	var B := []
	for a in [[-3, 1, "star"], [-3, 2, "quest"], [-2, 2, "math"], [-1, 2, "logic"], [0, 1, "skill"]]:
		B.append(add_node(a[0], a[1], a[2], "B"))
	var tail := []
	for a in [[1, 0, "riddle"], [2, 0, "star"], [3, 0, "math"], [4, 0, "quest"], [5, 0, "boss"]]:
		tail.append(add_node(a[0], a[1], a[2]))
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
		markers.append({"ring": m, "ic": ic, "base": n["p"]})

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
	for b in picker.get_children():
		b.modulate = Color.WHITE if b.get_meta("id") == def["id"] else Color(0.6, 0.6, 0.7)
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


# ---------------------------------------------------------------- flow
func say(t: String) -> void:
	lbl_msg.text = t
	_on_resize.call_deferred()


func offer(label := "", fn := Callable()) -> void:
	offer_fn = fn
	btn_act.text = label if label != "" else "Tirar el dado"
	_on_resize.call_deferred()


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
	lbl_dice.visible = true
	for k in 10:
		lbl_dice.text = str(randi_range(1, 6))
		await get_tree().create_timer(0.055).timeout
	lbl_dice.text = str(v)
	lbl_dice.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(lbl_dice, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	say("¡Has sacado un %d!" % v)
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
		n = to
		hero_at = n
	play("Idle")
	busy = false
	btn_act.disabled = false
	landed(n)


func landed(n: int) -> void:
	var t: String = path_nodes[n]["type"]
	match t:
		"tavern":
			say("Estás en la puerta de la Posada del Grifo. ¿Entras?")
			offer("Entrar en la posada", enter.bind("tavern"))
		"dungeon":
			say("La entrada de la mina huele a humedad… y a tesoro. ¿Bajas?")
			offer("Bajar a la mazmorra", enter.bind("dungeon"))
		"boss":
			say("¡La Fortaleza del Dragón! Aquí empezaría la batalla final.")
			play("Cheer")
			offer("Volver a la salida", back_to_start)
		_:
			say("Casilla de %s. En el juego completo, aquí saldría la pregunta." % TYPE_NAME.get(t, t))
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
	if where == "tavern":
		say("La Posada del Grifo huele a pan caliente y a tarta. Aquí descansaréis, compraréis y aceptaréis misiones.")
		offer("Salir", leave)
	else:
		say("La mazmorra de la mina. Al fondo brilla un cofre dorado…")
		offer("Abrir el cofre", open_chest)


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
	say("¡Tesoro! Has encontrado 5 estrellas y una llave rúnica.")
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
	await fade_to(0.0)
	play("Idle")
	busy = false
	offer()
	say("De vuelta en el camino. ¡Tira el dado!")


func fade_to(a: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, 0.45)
	await tw.finished


# ---------------------------------------------------------------- per frame
func _process(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if hero:
		hero_yaw += wrapf(hero_yaw_goal - hero_yaw, -PI, PI) * minf(1.0, dt * 10.0)
		hero.rotation.y = hero_yaw
		if mode == "board":
			goal = hero.position + Vector3(0, 0.6, 0)
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
	var hint := Label.new()
	hint.text = "Arrastra para girar la cámara · pellizca para acercar"
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("c9cde0"))
	col.add_child(hint)

	# hero picker
	picker = HBoxContainer.new()
	picker.add_theme_constant_override("separation", 8)
	ui.add_child(picker)
	for def in HEROES:
		var b := TextureButton.new()
		b.texture_normal = load("res://assets/art/%s.jpg" % def["art"])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		b.custom_minimum_size = Vector2(76, 76)
		b.set_meta("id", def["id"])
		b.tooltip_text = "%s, %s" % [def["name"], def["title"]]
		b.pressed.connect(func():
			if not busy:
				use_hero(def))
		picker.add_child(b)

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

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func _on_resize() -> void:
	# place the HUD by hand so it always hugs the screen edges
	var sz := get_viewport().get_visible_rect().size
	var m := 24.0
	lbl_dice.pivot_offset = sz * 0.5
	picker.reset_size()
	picker.position = Vector2(sz.x - picker.size.x - m, 18)
	box_visit.reset_size()
	box_visit.position = Vector2(m, sz.y - box_visit.size.y - m)
	btn_act.reset_size()
	btn_act.position = Vector2(sz.x - btn_act.size.x - m, sz.y - btn_act.size.y - m - 6)
	msg.reset_size()
	msg.position = Vector2((sz.x - msg.size.x) * 0.5, sz.y - msg.size.y - 104)
	box_choices.reset_size()
	box_choices.position = (sz - box_choices.size) * 0.5

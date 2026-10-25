extends Control
## Question and skill-challenge window: riddles and problems are typed, logic is multiple choice,
## skill games are played against the clock. Emits `finished(ok)` once the player closes the result.

signal finished(ok: bool)

const CAT_NAME := {"riddle": "Adivinanza", "logic": "Acertijo", "math": "Problema", "skill": "Reto de habilidad"}
const LEVEL_NAME := ["Aprendiz", "Experto", "Genio", "Maestro"]
const SKILL_SECS := {"memoria": [60, 70, 90, 100], "simon": [60, 70, 95, 110], "faroles": [60, 75, 90, 120]}
const GAME_NAME := {"memoria": "Runas gemelas", "simon": "Secuencia de runas", "faroles": "Faroles mágicos"}
const GEM := [Color("ff5d6c"), Color("4fd18b"), Color("5aa9ff"), Color("f2c14e"), Color("b48cff"), Color("ff9a4d")]
const ARTICLES := ["el", "la", "los", "las", "un", "una", "unos", "unas", "lo", "tu", "mi", "su", "es", "son"]

var fonts := {}
var card: Dictionary
var level := 2
var time_left := 60.0
var total := 60.0
var running := false
var answered := false
var ok := false
var web := false

var panel: PanelContainer
var box: VBoxContainer
var lbl_cat: Label
var lbl_time: Label
var bar: ProgressBar
var lbl_q: Label
var content: VBoxContainer
var result: VBoxContainer
var line: LineEdit

# skill game state
var game := {}


func setup(f: Dictionary) -> void:
	fonts = f
	web = OS.has_feature("web")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.075, 0.16, 0.96)
	sb.border_color = Color("f2c14e")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	lbl_cat = Label.new()
	lbl_cat.add_theme_font_override("font", fonts["head"])
	lbl_cat.add_theme_font_size_override("font_size", 30)
	lbl_cat.add_theme_color_override("font_color", Color("f2c14e"))
	lbl_cat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lbl_cat)
	lbl_time = Label.new()
	lbl_time.add_theme_font_override("font", fonts["bold"])
	lbl_time.add_theme_font_size_override("font_size", 28)
	head.add_child(lbl_time)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("f2c14e")
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)
	lbl_q = Label.new()
	lbl_q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_q.add_theme_font_size_override("font_size", 28)
	lbl_q.custom_minimum_size = Vector2(820, 0)
	box.add_child(lbl_q)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	box.add_child(content)
	result = VBoxContainer.new()
	result.add_theme_constant_override("separation", 8)
	box.add_child(result)
	visible = false
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	panel.reset_size()
	var sz := get_viewport().get_visible_rect().size
	var top := 24.0 if card.get("cat", "") in ["riddle", "math"] and web else (sz.y - panel.size.y) * 0.5
	panel.position = Vector2((sz.x - panel.size.x) * 0.5, maxf(16.0, top))


func open(c: Dictionary, lvl: int) -> void:
	card = c
	level = lvl
	answered = false
	ok = false
	for n in content.get_children():
		n.queue_free()
	for n in result.get_children():
		n.queue_free()
	game = {}
	var cat: String = c["cat"]
	lbl_cat.text = "%s · %s" % [CAT_NAME[cat] if cat != "skill" else GAME_NAME[c["game"]], LEVEL_NAME[lvl]]
	total = 60.0 if cat != "skill" else float(SKILL_SECS[c["game"]][lvl])
	time_left = total
	match cat:
		"riddle", "math":
			lbl_q.text = c["q"]
			_typed_ui()
		"logic":
			lbl_q.text = c["q"]
			_choice_ui()
		"skill":
			match c["game"]:
				"memoria":
					_memory_ui()
				"simon":
					_simon_ui()
				_:
					_lights_ui()
	visible = true
	running = true
	_place.call_deferred()


func _process(dt: float) -> void:
	if not visible:
		return
	if running:
		time_left = maxf(0.0, time_left - dt)
		lbl_time.text = "%d s" % ceili(time_left)
		lbl_time.add_theme_color_override("font_color", Color("ff7a7a") if time_left < 10 else Color("f4efe2"))
		bar.value = 100.0 * time_left / total
		if time_left <= 0.0:
			_finish(false, true)
			return
	if web and running and card.get("cat", "") in ["riddle", "math"]:
		if JavaScriptBridge.eval("window.gdAnsSubmit === true", true):
			JavaScriptBridge.eval("window.gdAnsSubmit = false;", true)
			_submit_typed(str(JavaScriptBridge.eval("(document.getElementById('gd-ans') || {}).value || ''", true)))


# ---------------------------------------------------------------- typed answers
func _typed_ui() -> void:
	var hint := Label.new()
	hint.add_theme_font_size_override("font_size", 19)
	hint.add_theme_color_override("font_color", Color("c9cde0"))
	var a: String = card["a"]
	if card["cat"] == "math":
		if a.contains(":"):
			hint.text = "Escribe la hora con dos puntos, por ejemplo 17:45."
		elif _has_decimal(a):
			hint.text = "Escribe solo el número, con decimales si hace falta (por ejemplo 12,50)."
		else:
			hint.text = "Escribe solo el número, sin unidades."
	else:
		hint.text = "Escribe tu respuesta. No importan las mayúsculas ni las tildes."
	content.add_child(hint)
	if web:
		var ph := "Tu respuesta" if card["cat"] == "riddle" else "Solo el número"
		var mode := "text" if card["cat"] == "riddle" or a.contains(":") else "decimal"
		JavaScriptBridge.eval("""
(function () {
  var w = document.getElementById('gd-ansbox');
  if (!w) {
    w = document.createElement('div'); w.id = 'gd-ansbox';
    w.style.cssText = 'position:fixed;left:50%%;bottom:max(14px,env(safe-area-inset-bottom));transform:translateX(-50%%);display:flex;gap:8px;z-index:20;width:min(86vw,560px)';
    var i = document.createElement('input'); i.id = 'gd-ans'; i.autocomplete = 'off'; i.setAttribute('autocapitalize', 'off'); i.setAttribute('aria-label', 'Tu respuesta');
    i.style.cssText = 'flex:1;min-width:0;font:600 20px system-ui,sans-serif;padding:10px 14px;border-radius:12px;border:2px solid #f2c14e;background:#0d1126;color:#f4efe2;outline:none';
    i.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); window.gdAnsSubmit = true; } });
    var b = document.createElement('button'); b.textContent = 'Responder';
    b.style.cssText = 'font:700 19px system-ui,sans-serif;padding:0 18px;min-height:46px;border-radius:12px;border:2px solid #1a1222;background:#f2c14e;color:#2b1a05';
    b.addEventListener('click', function () { window.gdAnsSubmit = true; });
    w.appendChild(i); w.appendChild(b); document.body.appendChild(w);
  }
  var inp = document.getElementById('gd-ans'); inp.value = ''; inp.placeholder = '%s'; inp.inputMode = '%s';
  w.style.display = 'flex'; window.gdAnsSubmit = false;
  setTimeout(function () { try { inp.focus(); } catch (e) {} }, 50);
})();
""" % [ph, mode], true)
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		line = LineEdit.new()
		line.placeholder_text = "Tu respuesta"
		line.custom_minimum_size = Vector2(520, 56)
		line.add_theme_font_size_override("font_size", 24)
		line.text_submitted.connect(_submit_typed)
		row.add_child(line)
		var b := Button.new()
		b.text = "Responder"
		b.custom_minimum_size = Vector2(180, 56)
		b.pressed.connect(func(): _submit_typed(line.text))
		row.add_child(b)
		content.add_child(row)
		line.grab_focus.call_deferred()


func _hide_web_input() -> void:
	if web:
		JavaScriptBridge.eval("var w = document.getElementById('gd-ansbox'); if (w) w.style.display = 'none'; var i = document.getElementById('gd-ans'); if (i) i.blur();", true)


func _submit_typed(text: String) -> void:
	if not running or text.strip_edges() == "":
		return
	card["typed"] = text.strip_edges()
	_finish(check_typed(card, text), false)


func _has_decimal(s: String) -> bool:
	var re := RegEx.new()
	re.compile("\\d,\\d")
	return re.search(s) != null


static func strip_accents(s: String) -> String:
	var src := "áàäâãéèëêíìïîóòöôõúùüûñç"
	var dst := "aaaaaeeeeiiiiooooouuuunc"
	var out := ""
	for ch in s.to_lower():
		var i := src.find(ch)
		out += dst[i] if i >= 0 else ch
	return out


static func norm_t(s: String) -> String:
	var t := strip_accents(s)
	var re := RegEx.new()
	re.compile("[^a-z0-9 ]")
	t = re.sub(t, " ", true)
	var words := []
	for w in t.split(" ", false):
		if not ARTICLES.has(w):
			words.append(w)
	return " ".join(words)


static func sing(w: String) -> String:
	if w.ends_with("es"):
		return w.substr(0, w.length() - 2)
	if w.ends_with("s"):
		return w.substr(0, w.length() - 1)
	return w


static func lev(a: String, b: String) -> int:
	var d := []
	for j in b.length() + 1:
		d.append(j)
	for i in range(1, a.length() + 1):
		var prev: int = d[0]
		d[0] = i
		for j in range(1, b.length() + 1):
			var t: int = d[j]
			d[j] = mini(mini(d[j] + 1, d[j - 1] + 1), prev + (0 if a[i - 1] == b[j - 1] else 1))
			prev = t
	return d[b.length()]


static func check_typed(c: Dictionary, text: String) -> bool:
	var a: String = c["a"]
	if c["cat"] == "math":
		var re := RegEx.new()
		re.compile("(\\d{1,2}):(\\d{2})")
		var tm := re.search(a)
		if tm:
			var re2 := RegEx.new()
			re2.compile("(\\d{1,2})\\D*(\\d{2})")
			var m := re2.search(text)
			if not m:
				return false
			return (int(tm.get_string(1)) * 60 + int(tm.get_string(2))) % 720 == (int(m.get_string(1)) * 60 + int(m.get_string(2))) % 720
		var num := RegEx.new()
		num.compile("\\d+(?:[.,]\\d+)?")
		var want := num.search(a)
		var got := num.search(text)
		if not want or not got:
			return false
		return absf(float(want.get_string().replace(",", ".")) - float(got.get_string().replace(",", "."))) < 0.005
	var g := norm_t(text)
	if g == "":
		return false
	var keys := [norm_t(a)]
	for x in c.get("alt", []):
		keys.append(norm_t(x))
	for k in keys:
		if k == "":
			continue
		if g == k or sing(g) == sing(k):
			return true
		if k.length() >= 4 and lev(g, k) <= (2 if k.length() >= 7 else 1):
			return true
		for w in g.split(" ", false):
			if w == k or (w.length() > 2 and sing(w) == sing(k)):
				return true
	return false


# ---------------------------------------------------------------- multiple choice
func _choice_ui() -> void:
	var opts: Array = card["opts"]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for i in opts.size():
		var b := Button.new()
		b.text = opts[i]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(405, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func():
			if running:
				card["chosen"] = i
				_finish(i == card["correct"], false))
		grid.add_child(b)


# ---------------------------------------------------------------- skill: memory
func _memory_ui() -> void:
	var dims: Array = [[3, 4, 6], [4, 4, 8], [4, 5, 10], [4, 6, 12]][level]
	lbl_q.text = "Encuentra todas las parejas de runas antes de que se acabe el tiempo."
	var deck := []
	for i in dims[2]:
		deck.append_array([i, i])
	deck.shuffle()
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 20)
	content.add_child(info)
	var grid := GridContainer.new()
	grid.columns = dims[1]
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	game = {"deck": deck, "open": [], "done": {}, "pairs": dims[2], "btns": [], "info": info, "lock": false}
	for k in deck.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(84, 74)
		b.add_theme_font_override("font", fonts["epic"])
		b.add_theme_font_size_override("font_size", 40)
		b.pressed.connect(_memory_tap.bind(k))
		grid.add_child(b)
		game["btns"].append(b)
		_memory_face(k, false)
	_memory_info()


func _memory_face(k: int, up: bool) -> void:
	var b: Button = game["btns"][k]
	var v: int = game["deck"][k]
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	if up:
		sb.bg_color = GEM[v % 6].darkened(0.15 if v < 6 else 0.45)
		sb.border_color = Color.WHITE
		b.text = "ABCDEFGHIJKL"[v]
	else:
		sb.bg_color = Color("2a2148")
		sb.border_color = Color("f2c14e")
		b.text = "?"
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color.WHITE)


func _memory_info() -> void:
	game["info"].text = "Parejas: %d de %d" % [game["done"].size() / 2, game["pairs"]]


func _memory_tap(k: int) -> void:
	if not running or game["lock"] or game["done"].has(k) or game["open"].has(k):
		return
	_memory_face(k, true)
	game["open"].append(k)
	if game["open"].size() < 2:
		return
	var a: int = game["open"][0]
	var b: int = game["open"][1]
	game["open"] = []
	if game["deck"][a] == game["deck"][b]:
		game["done"][a] = true
		game["done"][b] = true
		game["btns"][a].disabled = true
		game["btns"][b].disabled = true
		_memory_info()
		if game["done"].size() == game["deck"].size():
			_finish(true, false)
		return
	game["lock"] = true
	await get_tree().create_timer(0.75).timeout
	if not is_instance_valid(self) or not running:
		return
	_memory_face(a, false)
	_memory_face(b, false)
	game["lock"] = false


# ---------------------------------------------------------------- skill: sequence
func _simon_ui() -> void:
	var n := 4 if level < 3 else 6
	var target: int = [4, 5, 7, 8][level]
	lbl_q.text = "Mira la secuencia de runas y repítela en el mismo orden. Cada ronda se alarga una runa hasta llegar a %d. Si te equivocas, la vuelves a ver." % target
	var seq := []
	for i in target:
		seq.append(randi() % n)
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 22)
	content.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 2 if n == 4 else 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	game = {"seq": seq, "len": 1, "pos": 0, "target": target, "btns": [], "info": info, "playing": false, "speed": [0.65, 0.56, 0.48, 0.42][level]}
	for k in n:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 100)
		b.add_theme_font_override("font", fonts["epic"])
		b.add_theme_font_size_override("font_size", 44)
		b.text = "ABCDEF"[k]
		var sb := StyleBoxFlat.new()
		sb.bg_color = GEM[k].darkened(0.45)
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(3)
		sb.border_color = GEM[k]
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_simon_tap.bind(k))
		grid.add_child(b)
		game["btns"].append(b)
	_simon_play.call_deferred()


func _simon_flash(k: int, secs: float) -> void:
	var b: Button = game["btns"][k]
	b.modulate = Color(2.2, 2.2, 2.2)
	await get_tree().create_timer(secs).timeout
	if is_instance_valid(b):
		b.modulate = Color.WHITE


func _simon_play() -> void:
	game["playing"] = true
	game["info"].text = "Ronda %d de %d: mira bien…" % [game["len"], game["target"]]
	await get_tree().create_timer(0.6).timeout
	for i in game["len"]:
		if not running:
			return
		await _simon_flash(game["seq"][i], game["speed"])
		await get_tree().create_timer(0.14).timeout
	game["pos"] = 0
	game["playing"] = false
	game["info"].text = "Ronda %d de %d: ¡tu turno!" % [game["len"], game["target"]]


func _simon_tap(k: int) -> void:
	if not running or game["playing"]:
		return
	_simon_flash(k, 0.2)
	if k != game["seq"][game["pos"]]:
		game["info"].text = "¡Uy! Esa no era. Mira otra vez."
		_simon_play()
		return
	game["pos"] += 1
	if game["pos"] < game["len"]:
		return
	if game["len"] >= game["target"]:
		_finish(true, false)
		return
	game["len"] += 1
	_simon_play()


# ---------------------------------------------------------------- skill: lights
func _lights_ui() -> void:
	var n: int = [3, 4, 4, 5][level]
	var presses: int = [3, 4, 6, 8][level]
	lbl_q.text = "Enciende todos los faroles. Al tocar uno cambian él y sus vecinos de arriba, abajo y los lados."
	var on := []
	for i in n * n:
		on.append(true)
	game = {"n": n, "on": on, "btns": []}
	var picks := range(n * n)
	picks.shuffle()
	for i in presses:
		_lights_toggle(picks[i])
	if not on.has(false):
		_lights_toggle(randi() % (n * n))
	var grid := GridContainer.new()
	grid.columns = n
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for k in n * n:
		var b := Button.new()
		b.custom_minimum_size = Vector2(84, 74)
		b.pressed.connect(func():
			if running:
				_lights_toggle(k)
				_lights_draw()
				if not game["on"].has(false):
					_finish(true, false))
		grid.add_child(b)
		game["btns"].append(b)
	_lights_draw()


func _lights_toggle(k: int) -> void:
	var n: int = game["n"]
	var on: Array = game["on"]
	for x in [k, k - n, k + n, k - 1 if k % n > 0 else -1, k + 1 if k % n < n - 1 else -1]:
		if x >= 0 and x < n * n:
			on[x] = not on[x]


func _lights_draw() -> void:
	for k in game["btns"].size():
		var b: Button = game["btns"][k]
		var lit: bool = game["on"][k]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(37)
		sb.set_border_width_all(3)
		sb.bg_color = Color("ffd34a") if lit else Color("1d1a2e")
		sb.border_color = Color("fff1b8") if lit else Color("4a4466")
		sb.shadow_color = Color(1, 0.8, 0.3, 0.6) if lit else Color(0, 0, 0, 0)
		sb.shadow_size = 10 if lit else 0
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)


# ---------------------------------------------------------------- result
func _finish(success: bool, timeout: bool) -> void:
	if not running:
		return
	running = false
	ok = success
	_hide_web_input()
	for b in content.find_children("*", "BaseButton", true, false):
		b.disabled = true
	if card["cat"] == "logic":
		var opts_btns: Array = content.find_children("*", "Button", true, false)
		for i in opts_btns.size():
			var mark := Color("4fd18b") if i == card["correct"] else (Color("ff7a7a") if i == card.get("chosen", -1) else Color(0, 0, 0, 0))
			if mark.a > 0:
				var sb := StyleBoxFlat.new()
				sb.bg_color = mark.darkened(0.6)
				sb.border_color = mark
				sb.set_border_width_all(3)
				sb.set_corner_radius_all(14)
				opts_btns[i].add_theme_stylebox_override("disabled", sb)
				opts_btns[i].add_theme_color_override("font_disabled_color", Color.WHITE)
	var v := Label.new()
	v.add_theme_font_override("font", fonts["epic"])
	v.add_theme_font_size_override("font_size", 44)
	v.add_theme_color_override("font_color", Color("4fd18b") if success else Color("ff7a7a"))
	if card["cat"] == "skill":
		v.text = "¡Reto superado!" if success else "Se acabó el tiempo"
	else:
		v.text = "¡Correcto!" if success else ("Se acabó el tiempo" if timeout else "No es correcto")
	result.add_child(v)
	if card["cat"] != "skill":
		var sol := Label.new()
		sol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sol.custom_minimum_size = Vector2(820, 0)
		sol.add_theme_font_size_override("font_size", 22)
		var txt := "Respuesta: %s" % card["a"]
		if card.has("typed"):
			txt = "Has escrito «%s». %s" % [card["typed"], txt]
		if card.has("e"):
			txt += "\n" + str(card["e"])
		sol.text = txt
		result.add_child(sol)
	var cont := Button.new()
	cont.text = "Continuar"
	cont.custom_minimum_size = Vector2(220, 58)
	cont.add_theme_font_override("font", fonts["head"])
	cont.add_theme_font_size_override("font_size", 28)
	cont.pressed.connect(func():
		visible = false
		finished.emit(ok))
	result.add_child(cont)
	_place.call_deferred()
	cont.grab_focus.call_deferred()

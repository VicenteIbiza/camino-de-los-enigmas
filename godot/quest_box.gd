extends Control
## Quest window: shows the giver's story and three ways to solve it, then the outcome.
## The game logic lives in main.gd; this only displays and reports the player's choice.

signal chosen(index: int)
signal closed

var fonts := {}
var panel: PanelContainer
var lbl_zone: Label
var lbl_title: Label
var lbl_giver: Label
var lbl_text: Label
var box: VBoxContainer
var content: VBoxContainer


func setup(f: Dictionary) -> void:
	fonts = f
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.14, 0.97)
	sb.border_color = Color("d08a2a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	lbl_zone = _label(18, Color("f0aa46"), fonts["bold"])
	lbl_title = _label(36, Color("ffd27a"), fonts["head"])
	lbl_giver = _label(20, Color("c9cde0"), fonts["body"])
	lbl_text = _label(23, Color("f4efe2"), fonts["body"])
	lbl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_text.custom_minimum_size = Vector2(900, 0)
	lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_title.custom_minimum_size = Vector2(900, 0)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	box.add_child(content)
	visible = false
	get_viewport().size_changed.connect(_place)


func _label(size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font)
	box.add_child(l)
	return l


func _place() -> void:
	panel.reset_size()
	var sz := get_viewport().get_visible_rect().size
	panel.position = ((sz - panel.size) * 0.5).max(Vector2(16, 16))


func _clear() -> void:
	for n in content.get_children():
		n.queue_free()


func show_intro(zone: String, title: String, giver: String, text: String, choices: Array, reward: String) -> void:
	_clear()
	lbl_zone.text = zone.to_upper()
	lbl_title.text = title
	lbl_giver.text = giver
	lbl_text.text = "«%s»" % text
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	for i in choices.size():
		var c: Dictionary = choices[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(292, 92)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "%s\n%s" % [c["label"], c["test"]]
		b.add_theme_font_size_override("font_size", 19)
		b.disabled = c.get("disabled", false)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.1, 0.2, 0.95)
		sb.border_color = Color("d08a2a")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.pressed.connect(func():
			visible = false
			chosen.emit(i))
		row.add_child(b)
	var note := Label.new()
	note.text = reward
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(900, 0)
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color("c9cde0"))
	content.add_child(note)
	visible = true
	_place.call_deferred()


func show_result(ok: bool, headline: String, text: String, notes: Array, button: String) -> void:
	_clear()
	lbl_text.text = text
	var v := Label.new()
	v.text = headline
	v.add_theme_font_override("font", fonts["epic"])
	v.add_theme_font_size_override("font_size", 44)
	v.add_theme_color_override("font_color", Color("4fd18b") if ok else Color("ff7a7a"))
	content.add_child(v)
	content.move_child(v, 0)
	for n in notes:
		var l := Label.new()
		l.text = "• " + n
		l.add_theme_font_override("font", fonts["bold"])
		l.add_theme_font_size_override("font_size", 21)
		l.add_theme_color_override("font_color", Color("ffe7b8"))
		content.add_child(l)
	var b := Button.new()
	b.text = button
	b.custom_minimum_size = Vector2(260, 58)
	b.add_theme_font_override("font", fonts["head"])
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(func():
		visible = false
		closed.emit())
	content.add_child(b)
	visible = true
	_place.call_deferred()

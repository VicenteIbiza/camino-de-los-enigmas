extends Control
## Small modal window with a list of rows (name, description, button). Used for the shop, the bag
## and the level-up choice. Reports the chosen row with `picked(id)`, or `closed` from the close button.

signal picked(id: String)
signal closed

var fonts := {}
var panel: PanelContainer
var box: VBoxContainer
var lbl_title: Label
var lbl_sub: Label
var img: TextureRect
var rows: VBoxContainer
var foot: HBoxContainer


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
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	panel.add_child(top)
	img = TextureRect.new()
	img.custom_minimum_size = Vector2(110, 110)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(img)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	top.add_child(box)
	lbl_title = Label.new()
	lbl_title.add_theme_font_override("font", fonts["head"])
	lbl_title.add_theme_font_size_override("font_size", 34)
	lbl_title.add_theme_color_override("font_color", Color("ffd27a"))
	box.add_child(lbl_title)
	lbl_sub = Label.new()
	lbl_sub.add_theme_font_override("font", fonts["bold"])
	lbl_sub.add_theme_font_size_override("font_size", 19)
	lbl_sub.add_theme_color_override("font_color", Color("c9cde0"))
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sub.custom_minimum_size = Vector2(760, 0)
	box.add_child(lbl_sub)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(780, 0)
	scroll.name = "scroll"
	box.add_child(scroll)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	foot = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(foot)
	visible = false
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	var sz := get_viewport().get_visible_rect().size
	var scroll: ScrollContainer = box.get_node("scroll")
	scroll.custom_minimum_size.y = 0
	rows.reset_size()
	scroll.custom_minimum_size.y = minf(rows.get_combined_minimum_size().y, sz.y - 250.0)
	panel.reset_size()
	panel.position = ((sz - panel.size) * 0.5).max(Vector2(12, 12))


## rows: [{id, name, desc, button, enabled}]
func open(title: String, sub: String, list: Array, close_label := "Cerrar", tex: Texture2D = null) -> void:
	for n in rows.get_children():
		rows.remove_child(n)
		n.queue_free()
	for n in foot.get_children():
		foot.remove_child(n)
		n.queue_free()
	lbl_title.text = title
	lbl_sub.text = sub
	img.texture = tex
	img.visible = tex != null
	for r in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 14
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		pc.add_theme_stylebox_override("panel", sb)
		pc.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var n := Label.new()
		n.text = r["name"]
		n.add_theme_font_override("font", fonts["head"])
		n.add_theme_font_size_override("font_size", 24)
		n.add_theme_color_override("font_color", Color("ffe7b8"))
		col.add_child(n)
		var d := Label.new()
		d.text = r.get("desc", "")
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(540, 0)
		d.add_theme_font_size_override("font_size", 17)
		d.add_theme_color_override("font_color", Color("c9cde0"))
		col.add_child(d)
		var b := Button.new()
		b.text = r.get("button", "Elegir")
		b.custom_minimum_size = Vector2(150, 52)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_override("font", fonts["bold"])
		b.add_theme_font_size_override("font_size", 20)
		b.disabled = not r.get("enabled", true)
		var id: String = r["id"]
		b.pressed.connect(func(): picked.emit(id))
		row.add_child(b)
		rows.add_child(pc)
	if close_label != "":
		var c := Button.new()
		c.text = close_label
		c.custom_minimum_size = Vector2(200, 54)
		c.add_theme_font_override("font", fonts["head"])
		c.add_theme_font_size_override("font_size", 26)
		c.pressed.connect(func():
			visible = false
			closed.emit())
		foot.add_child(c)
	visible = true
	_place.call_deferred()

extends Control
## Narrator: plays the recorded voice clips (godot/audio/voz) with optional subtitles that are
## revealed in step with the voice. Emits `done` when a line ends, is skipped or is stopped.

signal done

const DIR := "res://audio/voz/%s.ogg"

var fonts := {}
var muted := false
var player: AudioStreamPlayer
var panel: PanelContainer
var lbl_who: Label
var lbl_text: Label
var tween: Tween
var token := 0
var active := false


func setup(f: Dictionary) -> void:
	fonts = f
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player = AudioStreamPlayer.new()
	player.volume_db = 1.5
	add_child(player)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.08, 0.78)
	sb.border_color = Color(0.95, 0.76, 0.3, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	lbl_who = Label.new()
	lbl_who.add_theme_font_override("font", fonts["head"])
	lbl_who.add_theme_font_size_override("font_size", 24)
	lbl_who.add_theme_color_override("font_color", Color("f2c14e"))
	col.add_child(lbl_who)
	lbl_text = Label.new()
	lbl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_text.custom_minimum_size = Vector2(900, 0)
	lbl_text.add_theme_font_size_override("font_size", 26)
	lbl_text.add_theme_color_override("font_color", Color("f7f1e3"))
	lbl_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	lbl_text.add_theme_constant_override("outline_size", 4)
	col.add_child(lbl_text)
	panel.visible = false
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	panel.reset_size()
	var sz := get_viewport().get_visible_rect().size
	panel.position = Vector2((sz.x - panel.size.x) * 0.5, sz.y - panel.size.y - sz.y * 0.13)


func has_clip(id: String) -> bool:
	return ResourceLoader.exists(DIR % id)


## Says a line. With `who` set, the text is shown as a subtitle; otherwise only the voice plays
## (for windows that already show the text). Without a clip or when muted, the subtitle stays up
## long enough to be read.
func speak(id: String, text: String, who := "") -> void:
	stop()
	token += 1
	var my := token
	active = true
	# the clip length sets the pace even if the browser is slow to start the sound
	var secs := 2.5 + text.length() * 0.06
	if not muted and has_clip(id):
		var s: AudioStream = load(DIR % id)
		player.stream = s
		player.play()
		secs = s.get_length() + 0.3
	elif who == "":
		_ended.call_deferred(my)
		return
	else:
		secs += 1.0
	get_tree().create_timer(secs).timeout.connect(_ended.bind(my))
	if who != "":
		lbl_who.text = who
		lbl_text.text = text
		lbl_text.visible_ratio = 0.0
		panel.visible = true
		panel.modulate.a = 0.0
		_place.call_deferred()
		tween = create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.25)
		tween.parallel().tween_property(lbl_text, "visible_ratio", 1.0, maxf(0.5, secs * 0.92))


func _ended(my: int) -> void:
	if my != token or not active:
		return
	active = false
	panel.visible = false
	done.emit()


func stop() -> void:
	if tween:
		tween.kill()
	player.stop()
	panel.visible = false
	token += 1
	if active:
		active = false
		done.emit()


## Muting silences the voice but keeps the subtitles, so the story still advances at its pace.
func set_muted(m: bool) -> void:
	muted = m
	if m:
		player.stop()

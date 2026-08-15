extends CanvasLayer
class_name BaseMenuUI

var vbox: VBoxContainer
var title_label: Label
var sub_label: Label
var container: Container

var title_image: TextureRect

func build_base_ui(title_text: String, sub_text: String, title_color: Color, use_panel: bool = false, title_image_path: String = "") -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.70)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	if use_panel:
		var center_wrapper := CenterContainer.new()
		center_wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(center_wrapper)
		
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(640, 320)
		center_wrapper.add_child(panel)
		container = panel
	else:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(center)
		container = center

	vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16 if use_panel else 24)
	container.add_child(vbox)

	if title_image_path != "" and ResourceLoader.exists(title_image_path):
		title_image = TextureRect.new()
		title_image.texture = load(title_image_path)
		title_image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		title_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vbox.add_child(title_image)
	else:
		title_label = Label.new()
		title_label.text = title_text
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 32 if use_panel else 56)
		title_label.add_theme_color_override("font_color", title_color)
		vbox.add_child(title_label)

	sub_label = Label.new()
	sub_label.text = sub_text
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 14 if use_panel else 18)
	sub_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(sub_label)

func make_styled_button(label: String, color: Color, size: Vector2, font_size: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = size
	btn.text = label
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.4)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", style)

	var style_hover := style.duplicate()
	style_hover.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("hover", style_hover)

	return btn

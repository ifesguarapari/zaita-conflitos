extends CanvasLayer

signal weapon_requested(weapon: StringName)
signal item_requested(item: StringName)

const SKULL_TEXTURE: Texture2D = preload("res://assets/props/black-skull.svg")
const PISTOL_TEXTURE: Texture2D = preload("res://assets/props/pistol.png")
const SHOTGUN_TEXTURE: Texture2D = preload("res://assets/props/shotgun.png")
const MACHINEGUN_TEXTURE: Texture2D = preload("res://assets/props/machinegun.png")
const SHIELD_TEXTURE: Texture2D = preload("res://assets/props/shield.png")
const TURRET_TEXTURE: Texture2D = preload("res://assets/props/rotarygun.png")

const HUD_SCALE := 0.5
const ENABLED_FILL := Color(1.0, 1.0, 1.0, 0.72)
const DISABLED_FILL := Color(0.68, 0.68, 0.68, 0.5)
const BORDER_COLOR := Color(0.0, 0.0, 0.0, 0.92)
const ACTIVE_BORDER_COLOR := Color(0.42, 0.0, 0.0, 0.95)
const CHARGE_BAR_SIZE := Vector2(126.0, 14.0)
const CHARGE_BAR_FILL := Color(1.0, 0.08, 0.12, 0.95)
const CHARGE_BAR_TRACK := Color(0.0, 0.0, 0.0, 0.24)

@export var shotgun_unlock_cost: int = 10
@export var machinegun_unlock_cost: int = 30
@export var shotgun_charge_capacity: int = 10
@export var machinegun_charge_capacity: int = 30
@export var shield_cost: int = 20
@export var turret_cost: int = 40

var hud_root: Control
var skulls_label: Label
var weapon_charge_bar: Control
var weapon_charge_track: Panel
var weapon_charge_fill: Panel
var hud_font: Font
var cards := {}
var selected_placement: StringName = &""
var displayed_skulls: int = 0
var displayed_weapon: StringName = &"pistol"
var displayed_unlocked_weapons := {
	&"pistol": true,
	&"shotgun": false,
	&"machinegun": false
}
var displayed_weapon_charges := {
	&"shotgun": 0,
	&"machinegun": 0
}


func _ready() -> void:
	_prepare_font()

	var old_panel := get_node_or_null("Panel")
	if old_panel != null:
		old_panel.visible = false

	var existing_root := get_node_or_null("PropHud") as Control
	if existing_root != null:
		hud_root = existing_root
		_bind_hud()
	else:
		_build_hud()

	show_placement_mode(&"")


func update_display(skulls: int, current_weapon: StringName, unlocked_weapons: Dictionary, weapon_charges: Dictionary = {}) -> void:
	displayed_skulls = skulls
	displayed_weapon = current_weapon
	displayed_unlocked_weapons = unlocked_weapons.duplicate()
	displayed_weapon_charges = weapon_charges.duplicate()

	if skulls_label != null:
		skulls_label.text = str(skulls)

	_set_card_cost(&"shotgun", shotgun_unlock_cost)
	_set_card_cost(&"machinegun", machinegun_unlock_cost)
	_set_card_cost(&"shield", shield_cost)
	_set_card_cost(&"turret", turret_cost)

	_update_card_state(&"pistol", false, current_weapon == &"pistol")
	_update_card_state(
		&"shotgun",
		not _weapon_has_charge(&"shotgun") and skulls < shotgun_unlock_cost,
		current_weapon == &"shotgun" and _weapon_has_charge(&"shotgun")
	)
	_update_card_state(
		&"machinegun",
		not _weapon_has_charge(&"machinegun") and skulls < machinegun_unlock_cost,
		current_weapon == &"machinegun" and _weapon_has_charge(&"machinegun")
	)
	_update_card_state(&"shield", skulls < shield_cost, selected_placement == &"shield")
	_update_card_state(&"turret", skulls < turret_cost, selected_placement == &"turret")
	_update_weapon_charge_bar()


func show_placement_mode(item: StringName) -> void:
	selected_placement = item
	update_display(displayed_skulls, displayed_weapon, displayed_unlocked_weapons, displayed_weapon_charges)


func show_skull_delta(amount: int) -> void:
	if hud_root == null or skulls_label == null or amount == 0:
		return

	var delta_label := Label.new()
	if amount > 0:
		delta_label.text = "+%d" % amount
	else:
		delta_label.text = "-%d" % abs(amount)
	_apply_label_style(delta_label, 42, true)
	delta_label.add_theme_color_override("font_color", Color.BLACK if amount > 0 else Color(0.55, 0.02, 0.02))
	delta_label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.85))
	delta_label.add_theme_constant_override("shadow_offset_x", 2)
	delta_label.add_theme_constant_override("shadow_offset_y", 2)
	hud_root.add_child(delta_label)

	var start_position := hud_root.get_global_transform().affine_inverse() * (skulls_label.global_position + Vector2(14.0, -4.0))
	delta_label.position = start_position
	delta_label.scale = Vector2.ONE * 0.7
	var end_offset := Vector2(0.0, -52.0) if amount > 0 else Vector2(0.0, 52.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(delta_label, "position", start_position + end_offset, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(delta_label, "scale", Vector2.ONE * 1.42, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(delta_label, "modulate:a", 0.0, 0.75).set_delay(0.08)
	tween.chain().tween_callback(delta_label.queue_free)


func show_weapon_charge_delta(weapon: StringName, amount: int) -> void:
	if hud_root == null or amount == 0:
		return

	var delta_label := Label.new()
	delta_label.text = "-%d" % abs(amount) if amount < 0 else "+%d" % amount
	_apply_label_style(delta_label, 32, true)
	delta_label.add_theme_color_override("font_color", Color(0.85, 0.02, 0.03))
	delta_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.9, 0.9, 0.78))
	delta_label.add_theme_constant_override("shadow_offset_x", 2)
	delta_label.add_theme_constant_override("shadow_offset_y", 2)
	hud_root.add_child(delta_label)

	var start_position := _weapon_charge_delta_position(weapon)
	delta_label.position = start_position
	delta_label.scale = Vector2.ONE * 0.62

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(delta_label, "position", start_position + Vector2(0.0, 42.0), 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(delta_label, "scale", Vector2.ONE * 1.08, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(delta_label, "modulate:a", 0.0, 0.62).set_delay(0.06)
	tween.chain().tween_callback(delta_label.queue_free)


func update_child_status(_child_name: String, _alive: bool) -> void:
	pass


func _prepare_font() -> void:
	hud_font = SystemFont.new()
	hud_font.font_names = PackedStringArray(["Noto Sans", "DejaVu Sans", "Arial"])


func _bind_hud() -> void:
	cards.clear()
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.position = Vector2(18.0, 24.0)
	hud_root.size = Vector2(510.0, 465.0)
	hud_root.scale = Vector2.ONE * HUD_SCALE

	skulls_label = hud_root.get_node("Stack/SkullPanel/SkullRow/SkullsLabel") as Label
	_apply_label_style(skulls_label, 66, true)
	_prepare_texture_rect(hud_root.get_node("Stack/SkullPanel/SkullRow/SkullIcon") as TextureRect)

	_bind_card(&"pistol", hud_root.get_node("Stack/WeaponsRow/PistolCard") as Control, true)
	_bind_card(&"shotgun", hud_root.get_node("Stack/WeaponsRow/ShotgunCard") as Control, true)
	_bind_card(&"machinegun", hud_root.get_node("Stack/WeaponsRow/MachinegunCard") as Control, true)
	_bind_card(&"shield", hud_root.get_node("Stack/ItemsRow/ShieldCard") as Control, false)
	_bind_card(&"turret", hud_root.get_node("Stack/ItemsRow/TurretCard") as Control, false)
	_bind_weapon_charge_bar()


func _bind_card(card_id: StringName, card: Control, is_weapon: bool) -> void:
	var button := card.get_node("Button") as Button
	var icon := card.get_node("Margin/Content/Icon") as TextureRect
	var small_skull := card.get_node("Margin/Content/CostRow/SmallSkull") as TextureRect
	var cost_label := card.get_node("Margin/Content/CostRow/CostLabel") as Label

	_prepare_texture_rect(icon)
	_prepare_texture_rect(small_skull)
	_apply_label_style(cost_label, 32, false)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _transparent_style())
	button.add_theme_stylebox_override("hover", _transparent_style())
	button.add_theme_stylebox_override("pressed", _transparent_style())
	button.add_theme_stylebox_override("disabled", _transparent_style())

	if is_weapon:
		button.pressed.connect(func() -> void: weapon_requested.emit(card_id))
	else:
		button.pressed.connect(func() -> void: item_requested.emit(card_id))

	cards[card_id] = {
		"card": card,
		"background": card.get_node("Background") as Panel,
		"button": button,
		"icon": icon,
		"skull": small_skull,
		"cost_label": cost_label,
		"cost": int(cost_label.text)
	}


func _prepare_texture_rect(texture_rect: TextureRect) -> void:
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.name = "PropHud"
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.position = Vector2(18.0, 24.0)
	hud_root.size = Vector2(510.0, 465.0)
	hud_root.custom_minimum_size = Vector2(510.0, 465.0)
	hud_root.scale = Vector2.ONE * HUD_SCALE
	add_child(hud_root)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 42)
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.add_child(stack)

	stack.add_child(_create_skull_panel())

	var weapons_row := HBoxContainer.new()
	weapons_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	weapons_row.add_theme_constant_override("separation", 20)
	stack.add_child(weapons_row)
	weapons_row.add_child(_create_card(&"pistol", PISTOL_TEXTURE, 0, true))
	weapons_row.add_child(_create_card(&"shotgun", SHOTGUN_TEXTURE, shotgun_unlock_cost, true))
	weapons_row.add_child(_create_card(&"machinegun", MACHINEGUN_TEXTURE, machinegun_unlock_cost, true))

	var items_row := HBoxContainer.new()
	items_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_row.alignment = BoxContainer.ALIGNMENT_CENTER
	items_row.add_theme_constant_override("separation", 24)
	stack.add_child(items_row)
	items_row.add_child(_create_card(&"shield", SHIELD_TEXTURE, shield_cost, false))
	items_row.add_child(_create_card(&"turret", TURRET_TEXTURE, turret_cost, false))
	hud_root.add_child(_create_weapon_charge_bar())
	_bind_weapon_charge_bar()


func _create_skull_panel() -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(490.0, 108.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_style(ENABLED_FILL, BORDER_COLOR, 5, 34))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 28.0
	row.offset_right = -28.0
	row.offset_top = 10.0
	row.offset_bottom = -10.0
	panel.add_child(row)

	skulls_label = Label.new()
	skulls_label.text = "0"
	skulls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skulls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skulls_label.custom_minimum_size = Vector2(220.0, 86.0)
	_apply_label_style(skulls_label, 66, true)
	row.add_child(skulls_label)

	var skull_icon := TextureRect.new()
	skull_icon.texture = SKULL_TEXTURE
	skull_icon.custom_minimum_size = Vector2(86.0, 86.0)
	skull_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	skull_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skull_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skull_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(skull_icon)

	return panel


func _create_card(card_id: StringName, texture: Texture2D, cost: int, is_weapon: bool) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(150.0, 150.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := Panel.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", _make_style(ENABLED_FILL, BORDER_COLOR, 5, 32))
	card.add_child(background)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)

	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(112.0, 88.0)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	content.add_child(icon)

	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 8)
	content.add_child(cost_row)

	var small_skull := TextureRect.new()
	small_skull.texture = SKULL_TEXTURE
	small_skull.custom_minimum_size = Vector2(38.0, 38.0)
	small_skull.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	small_skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	small_skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	small_skull.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cost_row.add_child(small_skull)

	var cost_label := Label.new()
	cost_label.text = str(cost)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label_style(cost_label, 32, false)
	cost_row.add_child(cost_label)

	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_theme_stylebox_override("normal", _transparent_style())
	button.add_theme_stylebox_override("hover", _transparent_style())
	button.add_theme_stylebox_override("pressed", _transparent_style())
	button.add_theme_stylebox_override("disabled", _transparent_style())
	card.add_child(button)

	if is_weapon:
		button.pressed.connect(func() -> void: weapon_requested.emit(card_id))
	else:
		button.pressed.connect(func() -> void: item_requested.emit(card_id))

	cards[card_id] = {
		"card": card,
		"background": background,
		"button": button,
		"icon": icon,
		"skull": small_skull,
		"cost_label": cost_label,
		"cost": cost
	}
	return card


func _create_weapon_charge_bar() -> Control:
	var bar := Control.new()
	bar.name = "WeaponChargeBar"
	bar.visible = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = CHARGE_BAR_SIZE
	bar.size = CHARGE_BAR_SIZE

	var track := Panel.new()
	track.name = "Track"
	track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.add_theme_stylebox_override("panel", _make_style(CHARGE_BAR_TRACK, Color.TRANSPARENT, 0, 7))
	bar.add_child(track)

	var fill := Panel.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2.ZERO
	fill.size = CHARGE_BAR_SIZE
	fill.add_theme_stylebox_override("panel", _make_style(CHARGE_BAR_FILL, Color.TRANSPARENT, 0, 7))
	track.add_child(fill)
	return bar


func _bind_weapon_charge_bar() -> void:
	weapon_charge_bar = hud_root.get_node_or_null("WeaponChargeBar") as Control
	if weapon_charge_bar == null:
		weapon_charge_bar = _create_weapon_charge_bar()
		hud_root.add_child(weapon_charge_bar)
	weapon_charge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_charge_bar.custom_minimum_size = CHARGE_BAR_SIZE
	weapon_charge_bar.size = CHARGE_BAR_SIZE
	weapon_charge_track = weapon_charge_bar.get_node("Track") as Panel
	weapon_charge_fill = weapon_charge_track.get_node("Fill") as Panel
	weapon_charge_track.clip_contents = true
	weapon_charge_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_charge_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_charge_track.add_theme_stylebox_override("panel", _make_style(CHARGE_BAR_TRACK, Color.TRANSPARENT, 0, 7))
	weapon_charge_fill.add_theme_stylebox_override("panel", _make_style(CHARGE_BAR_FILL, Color.TRANSPARENT, 0, 7))


func _update_card_state(card_id: StringName, disabled: bool, active: bool) -> void:
	if not cards.has(card_id):
		return

	var data: Dictionary = cards[card_id]
	var background: Panel = data["background"]
	var button: Button = data["button"]
	var icon: TextureRect = data["icon"]
	var small_skull: TextureRect = data["skull"]
	var cost_label: Label = data["cost_label"]

	button.disabled = disabled
	var fill := DISABLED_FILL if disabled else ENABLED_FILL
	var border := ACTIVE_BORDER_COLOR if active else BORDER_COLOR
	var border_width := 7 if active else 5
	background.add_theme_stylebox_override("panel", _make_style(fill, border, border_width, 32))
	var tint := Color(0.45, 0.45, 0.45, 0.72) if disabled else Color.WHITE
	icon.modulate = tint
	small_skull.modulate = tint
	cost_label.modulate = Color(0.35, 0.35, 0.35, 0.85) if disabled else Color.BLACK


func _set_card_cost(card_id: StringName, cost: int) -> void:
	if not cards.has(card_id):
		return

	var data: Dictionary = cards[card_id]
	data["cost"] = cost
	var cost_label: Label = data["cost_label"]
	cost_label.text = str(cost)


func _update_weapon_charge_bar() -> void:
	if weapon_charge_bar == null or weapon_charge_fill == null:
		return

	if displayed_weapon != &"shotgun" and displayed_weapon != &"machinegun":
		weapon_charge_bar.visible = false
		return

	var remaining := _weapon_charge_remaining(displayed_weapon)
	var capacity := _weapon_charge_capacity(displayed_weapon)
	if remaining <= 0 or capacity <= 0 or not cards.has(displayed_weapon):
		weapon_charge_bar.visible = false
		return

	weapon_charge_bar.visible = true
	weapon_charge_bar.size = CHARGE_BAR_SIZE
	weapon_charge_track.size = CHARGE_BAR_SIZE
	var fill_ratio := clampf(float(remaining) / float(capacity), 0.0, 1.0)
	weapon_charge_fill.size = Vector2(CHARGE_BAR_SIZE.x * fill_ratio, CHARGE_BAR_SIZE.y)

	var card: Control = cards[displayed_weapon]["card"]
	var card_size := card.size
	if card_size.x <= 1.0 or card_size.y <= 1.0:
		card_size = card.custom_minimum_size
	var card_origin: Vector2 = hud_root.get_global_transform().affine_inverse() * card.global_position
	weapon_charge_bar.position = card_origin + Vector2((card_size.x - CHARGE_BAR_SIZE.x) * 0.5, card_size.y + 10.0)


func _weapon_charge_delta_position(weapon: StringName) -> Vector2:
	if weapon_charge_bar != null and weapon_charge_bar.visible:
		return weapon_charge_bar.position + Vector2(CHARGE_BAR_SIZE.x * 0.5 - 14.0, -20.0)
	if cards.has(weapon):
		var card: Control = cards[weapon]["card"]
		var card_size := card.size
		if card_size.x <= 1.0 or card_size.y <= 1.0:
			card_size = card.custom_minimum_size
		var card_origin: Vector2 = hud_root.get_global_transform().affine_inverse() * card.global_position
		return card_origin + Vector2(card_size.x * 0.5 - 14.0, card_size.y + 4.0)
	return Vector2(200.0, 280.0)


func _weapon_has_charge(weapon: StringName) -> bool:
	return _weapon_charge_remaining(weapon) > 0


func _weapon_charge_remaining(weapon: StringName) -> int:
	return int(displayed_weapon_charges.get(weapon, 0))


func _weapon_charge_capacity(weapon: StringName) -> int:
	match weapon:
		&"shotgun":
			return shotgun_charge_capacity
		&"machinegun":
			return machinegun_charge_capacity
		_:
			return 1


func _make_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _apply_label_style(label: Label, font_size: int, is_bold: bool) -> void:
	if hud_font != null:
		label.add_theme_font_override("font", hud_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.42))
	label.add_theme_constant_override("outline_size", 2 if is_bold else 1)


func _transparent_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	return style

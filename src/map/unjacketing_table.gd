extends Node3D

var isInteractable: bool = false
var interactableText: String = "Examine Table"

@onready var tableCamera: Camera3D = $StaticBody3D/Camera3D
@onready var fossil_surface: MeshInstance3D = $FossilSurface
@onready var minigame_viewport: SubViewport = $MinigameViewport
@onready var fossil_image_rect: TextureRect = $MinigameViewport/FossilImage

## The fossil-in-rock image — always fully visible, pixels get erased within the mask region
@export var fossil_texture: Texture2D

## Same dimensions as fossil_texture. White pixels = erasable, black/transparent = not erasable.
@export var erase_mask_texture: Texture2D

## Must match the PlaneMesh size in the scene
@export var plane_size: Vector2 = Vector2(0.8, 0.8)

# Camera transition
var _tableCameraTargetTransform: Transform3D
var _player: CharacterBody3D = null
var _inTableView: bool = false

# Minigame state
var _minigame_active: bool = false
var _snapped_fossil = null
var _fossil_image: Image
var _fossil_image_texture: ImageTexture
var _erase_mask: Array[bool]  # flat [y * width + x], true = erasable
var _total_erasable_pixels: int = 0
var _erased_pixels: int = 0
var _brush_complete_percentage = 0.995

# Brush pressure
var _brush_hold_time: float = 0.0
const MIN_BRUSH_RADIUS := 8.0
const MAX_BRUSH_RADIUS := 40.0
const BRUSH_GROWTH_RATE := 30.0  # pixels per second

func _ready() -> void:
	if tableCamera == null:
		push_error("UnjacketTable: could not find Camera3D at $StaticBody3D/Camera3D")
		return
	_tableCameraTargetTransform = tableCamera.global_transform
	fossil_surface.visible = false
	_setup_viewport_material()
	_setup_minigame_image()

func _setup_viewport_material() -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = minigame_viewport.get_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fossil_surface.material_override = mat

func _setup_minigame_image() -> void:
	if not fossil_texture:
		return
	_fossil_image = fossil_texture.get_image()
	_fossil_image.convert(Image.FORMAT_RGBA8)
	_fossil_image_texture = ImageTexture.create_from_image(_fossil_image)
	fossil_image_rect.texture = _fossil_image_texture
	_bake_erase_mask()

func _bake_erase_mask() -> void:
	var w = _fossil_image.get_width()
	var h = _fossil_image.get_height()
	_erase_mask.resize(w * h)
	_erase_mask.fill(false)
	_total_erasable_pixels = 0

	if not erase_mask_texture:
		push_warning("UnjacketTable: no erase_mask_texture set — no pixels will be erasable")
		return

	var mask_image = erase_mask_texture.get_image()
	mask_image.resize(w, h)  # ensure same dimensions as fossil image

	for y in range(h):
		for x in range(w):
			# treat any pixel with brightness > 0.5 as erasable
			if mask_image.get_pixel(x, y).get_luminance() > 0.5:
				_erase_mask[y * w + x] = true
				_total_erasable_pixels += 1

func on_fossil_snapped(fossil) -> void:
	_snapped_fossil = fossil
	fossil.hide()
	fossil_surface.visible = true
	isInteractable = true

func interact() -> void:
	var playerCamera = get_tree().get_first_node_in_group("player_camera")
	if playerCamera == null:
		return

	# Camera3D -> LandingAnimation -> HeadPosition -> CharacterBody3D (player)
	_player = playerCamera.get_parent().get_parent().get_parent()

	tableCamera.global_transform = playerCamera.global_transform
	tableCamera.make_current()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_inTableView = true
	isInteractable = false

	_player.set_process(false)
	_player.set_physics_process(false)
	_player.set_process_input(false)
	
	minecraft_f1(true)

	var tween = create_tween()
	tween.tween_property(tableCamera, "global_transform", _tableCameraTargetTransform, 0.8)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): _minigame_active = true)

func minecraft_f1(on: bool) -> void:
	if on:
		$Label3D.hide()
		_player.get_node("%InteractText").hide()
	else:
		$Label3D.show()
		_player.get_node("%InteractText").show()

func _input(event: InputEvent) -> void:
	if _inTableView and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_exit_table_view()

func _process(delta: float) -> void:
	if not _minigame_active:
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_brush_hold_time += delta
		var radius = clamp(MIN_BRUSH_RADIUS + _brush_hold_time * BRUSH_GROWTH_RATE, MIN_BRUSH_RADIUS, MAX_BRUSH_RADIUS)
		var uv = _get_surface_uv_from_mouse()
		if uv.x >= 0.0:
			_erase_at_uv(uv, radius)
	else:
		_brush_hold_time = 0.0

func _get_surface_uv_from_mouse() -> Vector2:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = tableCamera.project_ray_origin(mouse_pos)
	var ray_dir = tableCamera.project_ray_normal(mouse_pos)

	var plane_normal = fossil_surface.global_transform.basis.y
	var plane_point = fossil_surface.global_position
	var plane = Plane(plane_normal, plane_normal.dot(plane_point))

	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return Vector2(-1.0, -1.0)

	var local = fossil_surface.to_local(hit)
	var uv_x = local.x / plane_size.x + 0.5
	var uv_z = local.z / plane_size.y + 0.5

	return Vector2(clamp(uv_x, 0.0, 1.0), clamp(uv_z, 0.0, 1.0))

func _erase_at_uv(uv: Vector2, radius: float) -> void:
	var img_w = _fossil_image.get_width()
	var img_h = _fossil_image.get_height()
	var px = int(uv.x * img_w)
	var py = int(uv.y * img_h)
	var r = int(radius)

	for x in range(px - r, px + r + 1):
		for y in range(py - r, py + r + 1):
			if (x - px) * (x - px) + (y - py) * (y - py) > r * r:
				continue
			if x < 0 or x >= img_w or y < 0 or y >= img_h:
				continue
			var idx = y * img_w + x
			if not _erase_mask[idx]:
				continue
			var color = _fossil_image.get_pixel(x, y)
			if color.a > 0.0:
				_fossil_image.set_pixel(x, y, Color(color.r, color.g, color.b, 0.0))
				_erased_pixels += 1

	_fossil_image_texture.update(_fossil_image)

	if _total_erasable_pixels > 0 and float(_erased_pixels) / float(_total_erasable_pixels) >= _brush_complete_percentage:
		_complete_minigame()

func _complete_minigame() -> void:
	_minigame_active = false
	for idx in range(_erase_mask.size()):
		if _erase_mask[idx]:
			var x = idx % _fossil_image.get_width()
			var y = idx / _fossil_image.get_width()
			_fossil_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	_fossil_image_texture.update(_fossil_image)
	fossil_surface.visible = false
	if _snapped_fossil:
		_snapped_fossil.currFossilState = FossilItem.FossilState.UNJACKETED
		_snapped_fossil.show()
		_snapped_fossil.isInteractable = true
		_snapped_fossil.interactableText = "Press \"e\" to pick up unjacketed fossil"
	print("Unjacketing complete!")
	_exit_table_view()

func _exit_table_view() -> void:
	_inTableView = false
	_minigame_active = false
	_brush_hold_time = 0.0
	if not _snapped_fossil or _snapped_fossil.currFossilState != FossilItem.FossilState.UNJACKETED:
		isInteractable = true

	var playerCamera = get_tree().get_first_node_in_group("player_camera")
	if playerCamera == null:
		_restore_player()
		return

	var tween = create_tween()
	tween.tween_property(tableCamera, "global_transform", playerCamera.global_transform, 0.8)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		playerCamera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		minecraft_f1(false)
		_restore_player()
	)

func _restore_player() -> void:
	if _player != null:
		_player.set_process(true)
		_player.set_physics_process(true)
		_player.set_process_input(true)
		_player = null

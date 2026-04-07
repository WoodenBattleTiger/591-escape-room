extends Node3D

var isInteractable: bool = false
var interactableText: String = "Examine Table"

@onready var tableCamera: Camera3D = $StaticBody3D/Camera3D
@onready var fossil_surface: MeshInstance3D = $FossilSurface
@onready var minigame_viewport: SubViewport = $MinigameViewport
@onready var fossil_image_rect: TextureRect = $MinigameViewport/FossilImage  # middle beige rock layer
@onready var bone_reveal_rect: TextureRect = $MinigameViewport/BoneReveal    # top bone PNG (static)

## Must match the PlaneMesh size in the scene
@export var plane_size: Vector2 = Vector2(0.8, 0.8)

# Camera transition
var _tableCameraTargetTransform: Transform3D
var _player: CharacterBody3D = null
var _inTableView: bool = false

# Minigame state
var _minigame_active: bool = false
var _snapped_fossil = null
var _fossil_image: Image          # the beige rock cover (middle layer, gets pixels erased)
var _fossil_image_texture: ImageTexture
var _bone_png_image: Image        # top bone PNG, used only for alpha sampling
var _erase_mask: Array[bool]      # flat [y * width + x], true = erasable (transparent in PNG)
var _total_erasable_pixels: int = 0
var _erased_pixels: int = 0
var _brush_complete_percentage = 0.995

const BRUSH_RADIUS := 40.0

# Beige rock color
const ROCK_COLOR := Color(0.87, 0.78, 0.62, 1.0)

# Accumulated mouse positions from InputEventMouseMotion, flushed each _process tick
var _pending_screen_positions: Array[Vector2] = []
# Last UV that was erased — used as the start of each segment to avoid gaps
var _last_erase_uv: Vector2 = Vector2(-1.0, -1.0)

func _ready() -> void:
	if tableCamera == null:
		push_error("UnjacketTable: could not find Camera3D at $StaticBody3D/Camera3D")
		return
	_tableCameraTargetTransform = tableCamera.global_transform
	fossil_surface.visible = false
	_setup_viewport_material()

func _setup_viewport_material() -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = minigame_viewport.get_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fossil_surface.material_override = mat

func on_fossil_snapped(fossil) -> void:
	_snapped_fossil = fossil
	fossil.hide()
	fossil_surface.visible = true
	isInteractable = true
	_load_and_setup_fossil_image(fossil)

## Determine the path to the bone PNG based on the fossil's assigned scene.
## Returns "" if no matching image exists.
func _get_bone_image_path(fossil) -> String:
	if fossil.fossilAssigned == null:
		return ""
	var scene_path: String = fossil.fossilAssigned.scene_file_path
	if scene_path == "":
		return ""

	# Extract the filename without extension, e.g. "tri_left_shoulder"
	var filename: String = scene_path.get_file().get_basename()

	# Normalize: strip _left_ / _right_ (with surrounding underscores)
	filename = filename.replace("_left_", "_").replace("_right_", "_")
	# Handle trailing _left / _right (no trailing underscore)
	filename = filename.replace("_left", "").replace("_right", "")

	# Strip trailing digit suffixes like _1, _2, _3 (for fingers, ribs, etc.)
	for suffix in ["_1", "_2", "_3"]:
		if filename.ends_with(suffix):
			filename = filename.left(filename.length() - suffix.length())
			break

	var candidate := "res://assets/images/%s.png" % filename
	if ResourceLoader.exists(candidate):
		return candidate
	return ""

func _load_and_setup_fossil_image(fossil) -> void:
	var image_path := _get_bone_image_path(fossil)

	var bone_texture: Texture2D
	if image_path != "":
		bone_texture = load(image_path)

	# Set the top static bone PNG layer
	bone_reveal_rect.texture = bone_texture

	# Determine working dimensions
	var img_w: int
	var img_h: int
	if bone_texture != null:
		_bone_png_image = bone_texture.get_image()
		_bone_png_image.convert(Image.FORMAT_RGBA8)
		img_w = _bone_png_image.get_width()
		img_h = _bone_png_image.get_height()
	else:
		_bone_png_image = null
		img_w = 512
		img_h = 512

	# Build the beige rock cover (middle layer) — solid beige rectangle
	_fossil_image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	_fossil_image.fill(ROCK_COLOR)
	_fossil_image_texture = ImageTexture.create_from_image(_fossil_image)
	fossil_image_rect.texture = _fossil_image_texture

	# Bake the erase mask from the PNG alpha channel
	_bake_erase_mask()

## Build the flat boolean erase mask.
## A pixel is erasable when it is transparent in the bone PNG (= background around the bone).
## If there is no bone PNG, every pixel is erasable.
func _bake_erase_mask() -> void:
	var w := _fossil_image.get_width()
	var h := _fossil_image.get_height()
	_erase_mask.resize(w * h)
	_erase_mask.fill(false)
	_total_erasable_pixels = 0
	_erased_pixels = 0

	for y in range(h):
		for x in range(w):
			var erasable: bool
			if _bone_png_image != null:
				# Erasable = transparent in the PNG (not part of the fossil bone)
				erasable = _bone_png_image.get_pixel(x, y).a < 0.5
			else:
				erasable = true
			if erasable:
				_erase_mask[y * w + x] = true
				_total_erasable_pixels += 1

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
		_player.get_node("%InteractText").hide()
		_player.get_node("%Crosshair").hide()
	else:
		_player.get_node("%InteractText").show()
		_player.get_node("%Crosshair").show()

func _input(event: InputEvent) -> void:
	if _inTableView and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_exit_table_view()
		return
	# Collect every mouse motion while the button is held so _process can
	# interpolate a smooth path rather than stamping one circle per frame.
	if _minigame_active and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pending_screen_positions.append(event.position)

func _process(_delta: float) -> void:
	if not _minigame_active:
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pending_screen_positions.clear()
		_last_erase_uv = Vector2(-1.0, -1.0)
		return

	# Always include the current mouse position so a stationary click still erases
	# and so _process never misses a position if no motion events fired this tick.
	_pending_screen_positions.append(get_viewport().get_mouse_position())

	var dirty := false
	for screen_pos in _pending_screen_positions:
		var uv := _screen_pos_to_uv(screen_pos)
		if uv.x < 0.0:
			continue
		if _last_erase_uv.x >= 0.0:
			dirty = _erase_segment(_last_erase_uv, uv) or dirty
		else:
			dirty = _erase_circle(uv) or dirty
		_last_erase_uv = uv

	_pending_screen_positions.clear()

	if dirty:
		_fossil_image_texture.update(_fossil_image)
		if _total_erasable_pixels > 0 and float(_erased_pixels) / float(_total_erasable_pixels) >= _brush_complete_percentage:
			_complete_minigame()

## Convert a screen-space position to a UV on the fossil surface plane.
## Returns Vector2(-1, -1) if the ray misses the plane.
func _screen_pos_to_uv(screen_pos: Vector2) -> Vector2:
	var ray_origin := tableCamera.project_ray_origin(screen_pos)
	var ray_dir := tableCamera.project_ray_normal(screen_pos)

	var plane_normal := fossil_surface.global_transform.basis.y
	var plane_point := fossil_surface.global_position
	var plane := Plane(plane_normal, plane_normal.dot(plane_point))

	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return Vector2(-1.0, -1.0)

	var local := fossil_surface.to_local(hit)
	var uv_x := local.x / plane_size.x + 0.5
	var uv_z := local.z / plane_size.y + 0.5
	return Vector2(clamp(uv_x, 0.0, 1.0), clamp(uv_z, 0.0, 1.0))

## Walk from uv_a to uv_b in half-radius steps, stamping a circle at each point.
## Returns true if any pixels were changed.
func _erase_segment(uv_a: Vector2, uv_b: Vector2) -> bool:
	var img_w := _fossil_image.get_width()
	var img_h := _fossil_image.get_height()

	var pa := Vector2(uv_a.x * img_w, uv_a.y * img_h)
	var pb := Vector2(uv_b.x * img_w, uv_b.y * img_h)
	var dist := pa.distance_to(pb)

	# Step at half-radius intervals so circles overlap and leave no gaps
	var step := BRUSH_RADIUS * 0.5
	if dist <= step:
		return _erase_circle(uv_b)

	var steps := int(ceil(dist / step))
	var dirty := false
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var p := pa.lerp(pb, t)
		dirty = _erase_circle(Vector2(p.x / img_w, p.y / img_h)) or dirty
	return dirty

## Stamp a single circular brush at the given UV. Returns true if any pixels changed.
func _erase_circle(uv: Vector2) -> bool:
	var img_w := _fossil_image.get_width()
	var img_h := _fossil_image.get_height()
	var px := int(uv.x * img_w)
	var py := int(uv.y * img_h)
	var r := int(BRUSH_RADIUS)
	var r2 := r * r
	var dirty := false

	for x in range(px - r, px + r + 1):
		for y in range(py - r, py + r + 1):
			if (x - px) * (x - px) + (y - py) * (y - py) > r2:
				continue
			if x < 0 or x >= img_w or y < 0 or y >= img_h:
				continue
			var idx := y * img_w + x
			if not _erase_mask[idx]:
				continue
			var color := _fossil_image.get_pixel(x, y)
			if color.a > 0.0:
				_fossil_image.set_pixel(x, y, Color(color.r, color.g, color.b, 0.0))
				_erased_pixels += 1
				dirty = true

	return dirty

func _complete_minigame() -> void:
	_minigame_active = false
	# Clear all remaining rock pixels so the reveal is clean
	for idx in range(_erase_mask.size()):
		if _erase_mask[idx]:
			var x := idx % _fossil_image.get_width()
			var y := idx / _fossil_image.get_width()
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
	_pending_screen_positions.clear()
	_last_erase_uv = Vector2(-1.0, -1.0)
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

extends CharacterBody3D

@export var footstep_sound: Array[AudioStream]

# Base movement speeds in units per second.
var run_speed = 5.5

# Sprint speed is the maximum speed the player can reach when sprinting.
var sprint_speed = 8.0

# Current target movement speed, 
# which will be set to either walk_speed, run_speed, or sprint_speed based on player input and stamina.
var target_speed = 0.0

# Walk speed is a slower movement speed for when the player is holding the slow walk key, allowing them to move more carefully.
var walk_speed = 3

# Crouch speed is the slowest movement speed for when the player is holding the crouch key.
var crouch_speed = 1.8

# Controls the maximum height multiplier for a run jump. 
# A run jump is when the player is sprinting and jumps, allowing them to jump higher than a normal jump.
# Note that if they jump immediately after starting to sprint, they might not get the full multiplier 
# since the multiplier scales based on current speed, starting at 1.0x jump_velocity at any speed below run_speed
# and scaling linearly up to sprint_jump_height_multiplier_max at sprint_speed or above.
var sprint_jump_height_multiplier_max = 1.3

# Acceleration values (horizontal only). 
# Corresponds to the formula 
# 
# v = v + accel * delta, 
# 
# where v is velocity, accel is acceleration, and delta is time since last frame.

# How much the player accelerates when trying to reach max speed on the ground. 
var accel_ground := 24.0

# How much the player decelerates when trying to stop from max speed on the ground (i.e. when there is no input).
var decel_ground := 30.0

# How much the player accelerates when trying to reach max speed in the air. 
# Ideally, this should be less than accel_ground to make the player feel less responsive in the air.
var accel_air := 12.0

# How much the player decelerates when trying to stop from max speed in the air.
# Should be much lower than decel_ground so that it doesn't feel like you're jumping
# through water or something when you're in the air with no input.
var decel_air := 1.5

var jump_velocity = 7
var landing_velocity

var distance = 0
var footstep_distance = 2.1

# stamina values are in arbitrary units (0..max_stamina)
var max_stamina := 100.0
var stamina := max_stamina
var stamina_drain_rate := 25.0 # units per second while sprinting
var stamina_regen_rate := 15.0 # units per second while not sprinting
var stamina_reenable_threshold := 0.5 # fraction of max to reenable sprint
var can_sprint := stamina >= max_stamina * stamina_reenable_threshold # whether the player is currently allowed to sprint (i.e. has enough stamina)
# How much stamina a jump costs.
var jump_stamina_cost := 12.0

@export var is_holding = null #what the player is holding

var fossilsCollected = 0
var fossilsReturned = 0

#@export var voxel_terrain : VoxelTerrain
#@onready var voxel_tool : VoxelTool = voxel_terrain.get_voxel_tool()

@export var hud_path: NodePath
@onready var hud: CanvasLayer = get_node_or_null(hud_path)

# This should be moved elsewhere, but for now to test the audio manager it is here.
# Path to the audio manager node in the scene tree, which we will use to call methods on the audio manager to play sounds.
@export var audio_manager_path: NodePath
@onready var audio_manager: Node = get_node_or_null(audio_manager_path)

# Inventory reference. The node is added under the player scene.
@onready var inventory: Inventory = $Inventory # Onready avoids null before scene instantiation finishes.
var is_map_open : bool = false

# Weight-to-stamina tuning. These multipliers scale drain/regen based on carried weight.
var weight_stamina_drain_mult_per_unit := 0.02 # Higher values make heavy loads punish sprinting more aggressively.
var weight_stamina_regen_mult_per_unit := 0.01 # Regen penalty keeps load meaningful even when resting.

# Tracks whether the test track has already been played, to ensure it only plays once.
var has_played_test_track = false

# Keyboard rotation rate for held items in pseudo-mouse-units per second.
var hold_rotation_keyboard_rate := 1000.0

# Toggles inversion for held-item rotation controls (mouse + keyboard).
var invert_hold_rotation_controls := false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_resolve_hud()
	_update_stamina_bar()

func _input(event: InputEvent) -> void:	
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACKSLASH:
		invert_hold_rotation_controls = not invert_hold_rotation_controls
		print("Invert hold rotation controls: ", invert_hold_rotation_controls)
	
	
	if event is InputEventMouseMotion:
		# In case the player is holding an item that can be rotated, 
		# we want to rotate the held item instead of the player/the player's view when they move the mouse
		# with the left mouse button held down. 
		var rotating_held_item := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_holding != null
		if rotating_held_item:
			if is_holding.has_method("apply_hold_rotation_input"):
				var control_sign := -1.0 if invert_hold_rotation_controls else 1.0
				is_holding.apply_hold_rotation_input(event.relative * control_sign)
			return

		rotation_degrees.y -= event.relative.x / 10
		%Camera3D.rotation_degrees.x -= event.relative.y / 10
		%Camera3D.rotation_degrees.x = clamp(%Camera3D.rotation_degrees.x, -90, 90)

func _physics_process(delta: float) -> void:
	
	# For keyboard controls for held-item rotation:
	if is_holding != null and is_holding.has_method("apply_hold_rotation_input"):
		var keyboard_x := int(Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_LEFT))
		var keyboard_y := int(Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_UP))
		# Pitch/yaw should be obvious, but for roll we can use the comma and period keys 
		# since shift + , = < and shift + . = > making them honorary arrow keys.
		var keyboard_roll := int(Input.is_key_pressed(KEY_PERIOD)) - int(Input.is_key_pressed(KEY_COMMA))

		# We already have a function for applying rotation input given a mouse delta, 
		# so let's just translate keyboard input into a pseudo mouse delta and feed it into that function,
		# (along with a roll input since I didn't have that yet).
		if keyboard_x != 0 or keyboard_y != 0 or keyboard_roll != 0:
			var control_sign := -1.0 if invert_hold_rotation_controls else 1.0
			var pseudo_mouse_delta := Vector2(keyboard_x, keyboard_y) * hold_rotation_keyboard_rate * delta * control_sign
			var roll_input := keyboard_roll * hold_rotation_keyboard_rate * delta
			is_holding.apply_hold_rotation_input(pseudo_mouse_delta, roll_input)
	
	#logic for dropping a held item
	if Input.is_action_just_pressed("interact") and is_holding != null:
		if is_holding.has_method("drop"):
			if is_holding.drop():
				is_holding = null
		#drop item
	
	# The code for raycasting to detect if an object is in front of the player is interactable
	%InteractText.hide()
	if %SeeCast.is_colliding():
		var target = %SeeCast.get_collider()
		if target != null and is_instance_valid(target):
			var interactable = target if target.has_method("interact") else target.get_parent()
			if is_holding == null and interactable != null and interactable.has_method("interact") and interactable.isInteractable:
				%InteractText.text = interactable.interactableText
				%InteractText.show()
				if Input.is_action_just_pressed("interact"):
					interactable.interact()
	
	if not is_on_floor():
		velocity += get_gravity() * 2 * delta
		landing_velocity = -velocity.y
		distance = 0

	# Jump with Space - only if on floor, no ceiling above, and the player isn't tired (tracked by can_sprint and stamina).
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not $CeilingDetector.is_colliding() and can_sprint and stamina >= jump_stamina_cost:
		# velocity.y = jump_velocity

		# var speed := velocity.length()
		var horizontal_velocity := Vector3(velocity.x, 0, velocity.z)
		var speed := horizontal_velocity.length()

		# A run jump makes the player jump up to 1.5x higher than a normal jump, 
		# so if the player is sprinting when they jump, we apply a multiplier which
		# scales linearly from 1.0x jump_velocity at run_speed to 1.5x jump_velocity at sprint_speed.
		if speed > run_speed:
			# Formula: If we denote the sprint jump multiplier as m, the current speed as s, the run speed as r, the sprint speed as sp,
			# and the max sprint jump multiplier as m_max, we can calculate m with the following formula:
			# m = 1.0 + ((m_max - 1.0) * ((s - r) / (sp - r)))
			# This will give us a multiplier of 1.0 when s = r, and a multiplier of m_max when s = sp, scaling linearly in between 
			# (Just differentiate this with respect to s to see that the rate of change of the multiplier with respect to speed is constant).
			var sprint_multiplier : float = 1.0 + ((sprint_jump_height_multiplier_max - 1.0) * ((speed - run_speed) / (sprint_speed - run_speed)))
			velocity.y = jump_velocity * sprint_multiplier
		else:
			velocity.y = jump_velocity

		# Jumping costs stamina now.
		stamina -= jump_stamina_cost

		# < 0.0 shouldn't be possible due to the check above, but in the
		# rare case where stamina = 0.0 after the subtraction, 
		# let's ensure we properly mark the player as being too tired.
		if stamina <= 0.0:
			stamina = 0.0
			can_sprint = false
		_update_stamina_bar()
		play_random_footstep_sound()

	if not $CeilingDetector.is_colliding():
		$CollisionShape3D.shape.height = lerp($CollisionShape3D.shape.height, 1.85, 0.1)
	else:
		$CollisionShape3D.shape.height = lerp($CollisionShape3D.shape.height, 1.38, 0.1)

	if is_on_floor():
		if landing_velocity != 0:
			landing_animation()
			landing_velocity = 0

		target_speed = run_speed
		# Crouch with C key.
		# Slow walk with Ctrl key.
		# Sprint with Shift key (only if can_sprint and has stamina).
		var wants_crouch = Input.is_key_pressed(KEY_CTRL)
		var wants_slow_walk = Input.is_key_pressed(KEY_C)
		var wants_sprint = Input.is_key_pressed(KEY_SHIFT)

		# Have to track this rather than
		# just calling sprint() inside the sprint
		# functions below since we want stamina to regenerate 
		# when the player is crouching or slow walking, and sprint() 
		# is where we handle stamina regeneration when not sprinting.
		var do_sprint := false
		# crouch overrides other movement speeds
		if wants_crouch:
			target_speed = crouch_speed
			do_sprint = false
		elif wants_slow_walk:
			target_speed = walk_speed
			do_sprint = false
		elif wants_sprint and can_sprint and stamina > 0.0:
			target_speed = sprint_speed
			do_sprint = true
			# dear god
			#print("Sprinting. Current stamina: " + str(stamina) + ", Current total weight: " + str(inventory.get_total_weight()))
		else:
			do_sprint = false

		sprint(do_sprint, delta)
	else:
		sprint(false, delta)

	if Input.is_key_pressed(KEY_CTRL):
		$CollisionShape3D.shape.height = lerp($CollisionShape3D.shape.height, 1.38, 0.1)

	$MeshInstance3D.mesh.height = $CollisionShape3D.shape.height
	%HeadPosition.position.y = $CollisionShape3D.shape.height - 0.25

	# Movement inputs
	var input_dir = Vector2.ZERO
	# Forward (W or Z)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
		input_dir.y -= 1
	# Backward (S)
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	# Left (A or Q)
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		input_dir.x -= 1
	# Right (D)
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	# Horizontal acceleration model: We want to accelerate towards the desired velocity based on player input, 
	# and decelerate when there is no input. 
	# We also have different acceleration and deceleration values for when the player is on the ground vs in the air, 
	# so air movement is less responsive to make it feel less like the player has some sort of jetpack.

	# We first want to figure out the desired movement direction based on player input and camera orientation.
	# transform.basis gives us the local coordinate system of the player, 
	# so we can multiply the input direction (which is in the player's local space) by the basis to get the desired movement direction in world space.
	var desired_dir := transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	if desired_dir.length() > 0:
		desired_dir = desired_dir.normalized()

	# Then we want to calculate the desired velocity based on the desired direction and current target_speed,
	# where v_h is the horizontal velocity (i.e. the player's current velocity ignoring vertical velocity from jumping/falling).
	var v_h := Vector3(velocity.x, 0, velocity.z)

	# desired_vel is the velocity we want to be moving at based on player input.
	var desired_vel: Vector3 = desired_dir * target_speed

	# Here we determine the appropriate acceleration and deceleration values to use based on whether the player is on the ground or in the air.
	var accel := 0.0
	var decel := 0.0
	if is_on_floor():
		accel = accel_ground
		decel = decel_ground
	else:
		accel = accel_air
		decel = decel_air

	if desired_dir.length() > 0:
		# If the player is providing input, we want to accelerate towards the desired velocity.
		# We first figure out the difference between the desired velocity and current velocity (delta_v),
		var delta_v := desired_vel - v_h
		
		# and then we want to make sure we don't accelerate faster than our acceleration value allows, 
		# so we have a maximum change in velocity (max_step) that we can apply this frame based on our acceleration and delta time,
		var max_step := accel * delta
		if delta_v.length() > max_step:
			# and if the change in velocity is greater than this max step, we clamp it down to the max step in the same direction.
			delta_v = delta_v.normalized() * max_step

		# Then we just add this change in velocity to our current velocity to get our new velocity 
		# (we'll normalize the velocity later if we're going over max target_speed).
		v_h += delta_v
	else:
		# If the player is not providing input, 
		# we want to decelerate (i.e. accelerate in the opposite direction of our current velocity).
		var decel_step := decel * delta
		var v_len := v_h.length()

		# If deceleration would reverse our direction 
		# (i.e. the deceleration step is greater than our current velocity), 
		# we just want to stop completely (set velocity to zero) rather than start moving in the opposite direction.
		if v_len <= decel_step:
			v_h = Vector3.ZERO
		else:
			v_h = v_h.normalized() * (v_len - decel_step)

	# Finally, we want to make sure we don't exceed our max target_speed in the horizontal direction,
	# so we clamp the horizontal velocity to the max target_speed if it's going over.
	var max_speed: float = target_speed
	var v_h_len := v_h.length()
	if v_h_len > max_speed:
		v_h = v_h.normalized() * max_speed

	velocity.x = v_h.x
	velocity.z = v_h.z

	distance += get_real_velocity().length() * delta

	if distance >= footstep_distance:
		distance = 0
		if target_speed > walk_speed:
			play_random_footstep_sound()

	move_and_slide()


	# digging code
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		pass
		# voxel_tool.mode = VoxelTool.MODE_REMOVE
		# voxel_tool.do_sphere(marker.global_position, 2.0)
		
		#voxel_terrain.save_modified_blocks()
		

func landing_animation():
	if landing_velocity >= 2:
		play_random_footstep_sound()

	var tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE)
	var amplitude = clamp(landing_velocity / 100, 0.0, 0.3)

	tween.tween_property(%LandingAnimation, "position:y", -amplitude, amplitude)
	tween.tween_property(%LandingAnimation, "position:y", 0, amplitude)

## This function shall reset the player's motion state by zeroing out velocity and landing velocity, 
## and resetting distance to zero. Velocity is the player's current movement velocity, 
## landing_velocity is used to determine the intensity of the landing animation when the player lands on the ground, 
## and distance is used to track how far the player has moved for purposes of playing footstep sounds.
func reset_motion_state() -> void:
	velocity = Vector3.ZERO
	landing_velocity = 0
	target_speed = 0.0
	distance = 0

func remove_held_item() -> bool:
	if(is_holding == null):
		print("not holding anything")
		return false
	var held_item_name = is_holding.fossil_res.display_name
	print("removing: ", held_item_name)
	var held_item_id = null
	for stack in inventory.slots:
		if (stack.item.display_name == held_item_name):
			held_item_id = stack.item.id
			break
	if (held_item_id == null):
		print("couldn't find '", held_item_name, "' in the inventory")
		return false
	if (!inventory.has_method("remove_item_from_inventory")):
		print("inventory doesn't have remove item method")
	if (!inventory.remove_item_from_inventory(held_item_id, 1)):
		print("couldn't remove item_id '", held_item_id, "' from inventory")
		return false
	print("item {id: ", held_item_id, ", name: ", held_item_name, "} was successfully removed")
	return true

func play_random_footstep_sound() -> void:
	if footstep_sound.size() > 0:
		$FootstepSound.stream = footstep_sound.pick_random()
		$FootstepSound.play()

## Handles sprinting logic, including stamina drain and regeneration. Should be called every frame with the current sprinting state and delta time.
## [br]
## **param** active Whether the player is currently trying to sprint.
## [br]
## **param** delta The time in seconds since the last frame, used to calculate stamina changes
func sprint(active: bool, delta: float) -> void:
	var carry_weight := 0.0
	if inventory:
		carry_weight = inventory.get_total_weight() # Query inventory each frame to keep stamina effects in sync with pickups/drops.

	# As the player picks up more weight, sprinting drains stamina faster and regeneration is slower.
	# The current formula is a simple linear multiplier based on total carry weight.
	# Denote the drain multiplier as m_d, the regen multiplier as m_r, the total carry weight as w, and the respective per-unit multipliers as k_d and k_r. 
	# We have:
	# 
	# m_d = 1.0 + (w * k_d)
	# m_r = 1.0 + (w * k_r)
	# 
	# As weight increases, the drain multiplier m_d increases linearly. 
	# In turn, the amount of time the player can sprint continuously decreases.
	# If they could sprint for s seconds at zero weight, then at weight w, we can solve for the new sprint time s' by setting up the equation:
	# 
	# stamina_drain_rate * m_d * s' = stamina_drain_rate * s
	#
	# Solving for s' gives us:
	# s' = s / m_d = s / (1.0 + (w * k_d))
	#
	# So as w increases, the effective sprint time s' decreases inversely with the multiplier.

	var drain_mult := 1.0 + carry_weight * weight_stamina_drain_mult_per_unit

	# Doing this with regeneration amplifies the effect of weight on sprinting.
	var regen_mult := 1.0 + carry_weight * weight_stamina_regen_mult_per_unit

	# If sprinting is active and allowed, drain stamina (scaled by carried weight).
	if active and can_sprint:
		stamina -= stamina_drain_rate * drain_mult * delta

		# If the player fully depletes their stamina, disable sprint until threshold is met.
		if stamina <= 0.0:
			stamina = 0.0
			can_sprint = false
	else:
		# If not sprinting or not allowed, regenerate stamina (penalized by carried weight).
		stamina += (stamina_regen_rate / regen_mult) * delta
		if not can_sprint and stamina >= max_stamina * stamina_reenable_threshold:
			can_sprint = true

	# Ensure stamina stays within valid bounds.
	stamina = clamp(stamina, 0.0, max_stamina)

	# Updates the stamina bar in the UI to reflect the current stamina value after changes.
	_update_stamina_bar()


## Updates the stamina bar UI element to reflect the current stamina and max stamina values.
func _update_stamina_bar() -> void:
	# If we don't have a reference to the HUD, try to resolve it. 
	# This allows the stamina bar to update correctly even if the 
	# HUD wasn't immediately available when the player node was initialized.
	if not hud:
		_resolve_hud()

	# If we have a valid HUD reference and it has the set_stamina method,
	# call it to safely update the stamina bar display with the current stamina values.
	# We pass the can_sprint value as well so the HUD can adjust visuals accordingly 
	# (e.g. flashing and color change when sprinting is disabled).
	if hud and hud.has_method("set_stamina"):
		hud.set_stamina(stamina, max_stamina, can_sprint)

	# TODO: Remove this once we have a better place to put the audio manager.
	# For testing purposes, let's have the player play a test track when their stamina drops below the max value for the first time.
	if not has_played_test_track and stamina < max_stamina:
		has_played_test_track = true
		#if audio_manager and audio_manager.has_method("play_sound_effect"):
		#	audio_manager.play_sound_effect("test_sfx")
		

## Attempts to resolve the HUD node reference if it hasn't been set yet.
## This will look for the node at the specified hud_path and assign it to the hud variable.
func _resolve_hud() -> void:
	if hud_path != NodePath(""):
		hud = get_node_or_null(hud_path)

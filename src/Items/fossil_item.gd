#just decaring this so that I can use the fossil state enum in other objects
class_name FossilItem
extends RigidBody3D

const MAX_HEALTH := 100.0

enum FossilState { JACKETED, ONTABLE, UNJACKETED, INPRINTER, PRINTED}
var currFossilState = FossilState.JACKETED

var isInteractable = true
var interactableText = "Press \"e\" to pick up"
@onready var fossil_res = preload("res://src/Items/fossil.tres")
@onready var player
@onready var camera_path := NodePath("HeadPosition/LandingAnimation/Camera3D")
@onready var rock_particles: GPUParticles3D = $RockParticles

# How many particle effects to play when taking damage.
var damage_particle_count := 20

## Radial distance in spherical coordinates for positioning while held.
## The fossil is placed at this distance from an anchor point near the player,
## in the same direction as the camera's current forward vector (yaw + pitch).
@export var hold_distance := 1.0

## Vertical anchor offset from the player's origin used as the spherical center
## while holding. This keeps the orbit center near the torso/head area instead
## of at the player's feet.
@export var hold_height := 1.6

## Strength of the positional spring pulling the fossil toward the target hold point.
## larger values increase the restoring force for a given position error.
## Example: big (e.g. 2000) -> item snaps to target very quickly but may produce strong collision impulses or jitter;
##          small (e.g. 100) -> item is very floaty and slow to return.
## `hold_spring_strength` should be balanced with `hold_damping` and `max_hold_force`.
@export var hold_spring_strength := 10000.0

## Linear damping applied to the velocity error (viscous term that resists motion).
## Higher damping reduces oscillation/overshoot from the positional spring; too-high values feel sluggish.
## Example: big (e.g. 200) -> critically or over-damped (no bounce, may feel heavy); small (e.g. 10) -> under-damped, oscillatory float.
## When you raise `hold_spring_strength`, increase `hold_damping` to maintain stability.
@export var hold_damping := 1000.0

## Maximum magnitude of the positional force applied (force cap for safety/stability).
## Prevents the spring+damping force from becoming unbounded and doing weird things like maybe launching the fossil if some tremendous position error occurs even if for a single frame.
## Example: big (e.g. 8000) -> allows very aggressive corrections (may shove through light obstacles); small (e.g. 200) -> weak corrections, item may not snap back.
## Set `max_hold_force` >= (`hold_spring_strength` * typical_target_distance) to allow intended corrections.
@export var max_hold_force := 4000.0

## Rotational spring strength for correcting orientation (applied as torque via PD controller).
## larger values make orientation correct faster across all axes (pitch/yaw/roll).
## Example: big (e.g. 600) -> quick orientation recovery but risks oscillation without adequate damping;
##          small (e.g. 10) -> very slow or no recovery; item may stay tilted.
## Tune with `hold_rotation_damping` and `max_hold_torque` (higher spring needs higher damping and torque cap).
@export var hold_rotation_spring := 1200.0

## Rotational damping applied to angular velocity to reduce spin and overshoot in rotation.
## Higher values kill residual angular velocity faster (damps spin); too high can feel unresponsive.
## Example: big (e.g. 80) -> strongly damps tumble/oscillation; small (e.g. 2) -> allows prolonged tumbling.
## Increase this when increasing `hold_rotation_spring` for stability.
@export var hold_rotation_damping := 130.0

## Sensitivity for mouse-driven hold rotation input, measured in radians per pixel.
@export var hold_rotation_input_sensitivity := 0.001

## Maximum allowed torque magnitude for rotational correction (safety cap).
## Caps the rotational PD output so angular acceleration stays reasonable.
## Example: big (e.g. 1000) -> permits very strong torque corrections; small (e.g. 20) -> weak correction and slow orienting.
## Choose this so typical `angle_error * hold_rotation_spring` can be delivered without saturating constantly.
@export var max_hold_torque := 960.0

## Euclidean distance threshold: if the fossil center is farther than this from the target hold point, force-release it.
## Smaller values cause earlier release when item is pulled away by collisions; larger values are more lenient.
## Example: big (e.g. 3.5) -> tolerates larger displacements before dropping; small (e.g. 1.0) -> strict, drops quickly when pulled.
## Set in relation to `max_hold_force` so the item isn't allowed to float very far because forces are too weak.
@export var max_hold_distance_from_target := 2.0

# Keeps track of spherical angles derived from camera forward while held.
# _hold_theta is azimuth (yaw in the XZ plane), _hold_phi is elevation (pitch).
var _hold_theta := 0.0
var _hold_phi := 0.0

# Mouse-driven orientation offset relative to the camera-yaw-aligned hold orientation.
var _hold_rotation_offset := Quaternion.IDENTITY

# This flag represents ownership of the current hold session by this script.
# We set it true when interact() starts holding, and false immediately when a drop/force-release begins.
# The immediate false transition is critical: it prevents additional physics ticks from scheduling extra releases
# before player.remove_held_item() has finished mutating external state.
var _hold_session_active := false

# Collision bits
const PLAYER_LAYER_BIT := 3
const FOSSIL_LAYER_BIT := 2
const WORLD_LAYER_BIT := 1

var weight = 0.0
var health = MAX_HEALTH

@export var min_damage_speed := 4.0 # Threshold speed before collisions cause damage
@export var damage_per_speed := 1.0 # Damage multiplier per unit of impact speed

# Ranges for visual damage effect. Darkness is interpolated between these based on damage ratio.

# The minimum darkness multiplier to apply to the material colors when the fossil is at 100% health. 
@export_range(0.0, 1.0, 0.01) var min_darkness := 0.0

# The maximum darkness multiplier to apply to the material colors when the fossil is at 0% health.
# A value like 1.0 would result in total blackness at 0 health, which looks a little off.
# So we use a value less than 1.0 to allow the fossil to still be somewhat visible even when fully damaged.
@export_range(0.0, 1.0, 0.01) var max_darkness := 0.65

var _damage_materials: Array[Dictionary] = []
var _is_destroying := false

#contains a fieldLofInfo.initials and fieldLogInfo.description after the fieldLog has been attached to the fossilItem
var fieldLogInfo
#used to save the path of the scene used for this script to know what scene to instantiate in the logbook (saved to the globals when the fossil is deposited)
var fossilScenePath

#this is what fossil is assigned to this fossil item. This is very important for knowing which fossil it should snap to.
var fossilAssigned

func _ready() -> void:
	# Enable contact reporting so we can read contact data in _integrate_forces.
	# https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html#class-rigidbody3d-property-contact-monitor
	contact_monitor = true
	# https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html#class-rigidbody3d-property-max-contacts-reported
	max_contacts_reported = 8
	sleeping = false # ensure physics stays active so _integrate_forces runs
	fossil_res.weight = weight
	health = clamp(health, 0.0, MAX_HEALTH)
	player = get_tree().root.get_node("Level/Player")
	_cache_damage_materials()
	_update_damage_visuals()

## This function is called to play damage particles when the fossil takes damage.
## [br]
##  **Param**: particle_count (int) - The number of particles to emit.
func play_damage_particles(particle_count: int) -> void:
	if rock_particles == null:
		print("Error: rock_particles is null, cannot play damage particles.")
		return

	# Delegate to the rock_particles node to handle playing the particle effect.
	rock_particles.play_particles(particle_count)

#assign the fossil (assigned in the fossil_spawn_point)
func assign_fossil(fossilScenePath: String) -> void:
	fossilAssigned = load(fossilScenePath).instantiate()
	add_child(fossilAssigned)
	_cache_damage_materials()

## This function is called when the fossil is readied. 
## It collects all materials used in the fossil's visual representation and caches them in the _damage_materials array, along with their base colors
## so that we can modify their colors later to visually represent damage.
func _cache_damage_materials() -> void:
	# Clear any previously cached materials in case this is called more than once for some reason. We want to avoid duplicates and stale references.
	_damage_materials.clear()
	if fossilAssigned == null:
		return

	# We assume that all visual MeshInstance3D nodes are children (or descendants) of a common root node, which is called "SmallFossilRock".
	#var visual_root := get_node_or_null("SmallFossilRock")
	#if visual_root == null:
		#return

	# DFS traversal to find all MeshInstance3D nodes under visual_root, then for each material used by those mesh instances, 
	# we create a duplicate of the material and store it in _damage_materials along with its base color.
	var mesh_instances := _collect_mesh_instances(fossilAssigned)

	for mesh_instance in mesh_instances:

		# First we check if the mesh instance has a material override. 
		if mesh_instance.material_override is BaseMaterial3D:
			# If it does, we duplicate the override material and set it back as the new override, then register that duplicated material for damage visualization.
			var override_material := mesh_instance.material_override.duplicate() as BaseMaterial3D
			mesh_instance.material_override = override_material

			# Note that if a material is used as an override on multiple mesh instances, this will create separate duplicates for each instance, 
			# which is fine for our purposes since they can have different damage states.
			_register_damage_material(override_material)
			continue

		if mesh_instance.mesh == null:
			continue

		# If there is no material override, we check the materials assigned to each surface of the mesh. 
		# For each active material, we duplicate it and set it as a surface override,
		# then register that duplicated material for damage visualization.
		for surface_index in mesh_instance.mesh.get_surface_count():
			var active_material := mesh_instance.get_active_material(surface_index)
			if active_material is BaseMaterial3D:
				var surface_material := active_material.duplicate() as BaseMaterial3D
				mesh_instance.set_surface_override_material(surface_index, surface_material)
				_register_damage_material(surface_material)


## This function recursively collects all MeshInstance3D nodes in the subtree rooted at the given node.
## [br]
##  **Param**: root (Node) - The root node of the subtree to search.
## [br]
##  **Returns**: Array[MeshInstance3D] - A list of all MeshInstance3D nodes found.
func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var mesh_instances: Array[MeshInstance3D] = []
	_append_mesh_instances(root, mesh_instances)
	return mesh_instances

## This function is a helper for _collect_mesh_instances that performs a depth-first traversal of the node tree, 
## appending any MeshInstance3D nodes it finds to the provided mesh_instances array.
## [br]
##  **Param**: node (Node) - The current node being processed.
## [br]
##  **Param**: mesh_instances (Array[MeshInstance3D]) - The array to which found MeshInstance3D nodes should be appended.
func _append_mesh_instances(node: Node, mesh_instances: Array[MeshInstance3D]) -> void:
	# Base case: if the current node is a MeshInstance3D, we add it to the list of mesh instances.
	if node is MeshInstance3D:
		mesh_instances.append(node as MeshInstance3D)

	# Recursive case: we call this function on all children of the current node to continue the depth-first traversal.
	for child in node.get_children():
		_append_mesh_instances(child, mesh_instances)

## This function registers a material for damage visualization by storing a reference to it along with its base color in the _damage_materials array.
## [br]
##  **Param**: material (BaseMaterial3D) - The material to register for damage visualization.
func _register_damage_material(material: BaseMaterial3D) -> void:
	# We only need to know the base color of the material to apply our damage darkening effect, so we store that along with the material reference.
	_damage_materials.append({
		"material": material,
		"base_color": material.albedo_color,
	})


## This function updates the visual appearance of the fossil based on its current health.
## It calculates a damage ratio based on the current health and uses it to determine how much to darken the material colors.
## Specifically, it linearly interpolates between min_darkness and max_darkness based on the damage ratio, 
## and then applies that darkness as a multiplier to the base color of each registered material.
func _update_damage_visuals() -> void:
	# First we determine how much damage the fossil has taken as a ratio of its max health. 
	# This will be a value between 0 and 1, where 0 means no damage and 1 means fully damaged.
	var damage_ratio : float = clamp((MAX_HEALTH - health) / MAX_HEALTH, 0.0, 1.0)

	# We ensure that the darkness value is clamped between min_darkness and max_darkness, and we use linear interpolation to calculate it based on the damage ratio.
	# This way, when the damage ratio is 0 (no damage), darkness will be at min_darkness, and when the damage ratio is 1 (fully damaged), darkness will be at max_darkness, with a smooth transition in between.
	var darkness : float = clamp(lerp(min_darkness, max_darkness, damage_ratio), min_darkness, max_darkness)

	# We calculate brightness as the inverse of darkness, so that as the fossil takes more damage and darkness increases, brightness decreases.
	var brightness : float = 1.0 - darkness

	# For each material that we want to darken...
	for material_entry in _damage_materials:
		# ...We figure out what material it is...
		var material := material_entry["material"] as BaseMaterial3D
		# ...What the base color of that material is (the original undamaged color that we cached when we registered the material)...
		var base_color := material_entry["base_color"] as Color

		# ...And finally we apply the darkness as a multiplier to the base color and set that as the new albedo color of the material.
		# For those who may not know but are interested, albedo color is basically the base color of a material that is used in lighting calculations. 
		# By multiplying the base color by the brightness factor, we effectively darken the material as the fossil takes damage.
		material.albedo_color = Color(
			base_color.r * brightness,
			base_color.g * brightness,
			base_color.b * brightness,
			base_color.a
		)


func update_state_on_snap():
	match currFossilState:
		FossilItem.FossilState.JACKETED:
			currFossilState = FossilItem.FossilState.ONTABLE
			interactableText = "Press \"e\" to unjacket the fossil"
			isInteractable = true
			var table = get_tree().get_first_node_in_group("jacketing_table")
			table.on_fossil_snapped(self)
			
		FossilItem.FossilState.UNJACKETED:
			currFossilState = FossilItem.FossilState.INPRINTER
			interactableText = "Press \"e\" to retrieve 3d printed fossil"
			
			var printer : Printer3D = get_tree().get_first_node_in_group("3DPrinter")
			printer.isInteractable = true


func interact():
	#push_warning("interact() called on base FossilItem — subclass should override this.")
	match currFossilState:
		# The starting state that the player finds the fossil in
		FossilState.JACKETED:
			pickup()
		
		# The state of the fossil after the player places it on the table to be dejacketed
		FossilState.ONTABLE:
			#TODO The interaction for dejacketing the fossil
			print("u dejacketed the fossil.")
			interactableText = "Press \"e\" to pick up unjacketed fossil"
			currFossilState = FossilState.UNJACKETED
		
		# Interacting with the fossil after player has unjacketed the fossil 
		FossilState.UNJACKETED:
			pickup()
		
		# Interacting with the fossil after it has gone through 3d-printer
		FossilState.PRINTED:
			pickup()
		_:
			#Player shouldn't be able to interact with the fossil while it is in the 3d printer (This is because they should be interacting with the 3d printer)
			print("HOW ARE U INTERACTING IN THIS STATE?????")

func pickup():
	if player != null:
		# In case the player had already been holding this fossil and 
		# is interacting again (e.g. this is the second time they picked it up), 
		# we want to reset hold rotation offsets so that the new hold session 
		# doesn't start with them holding it at the previous position they dropped it from.
		_reset_hold_rotation_offsets()
		# Stop the fossil from colliding with the player while it's held
		# so the player has an easier time rotating the fossil.
		_set_player_collision_ignored(true)
		# Keep the rigid body under world/terrain while held.
		# RigidBody3D nodes behave most predictably when simulated in world space rather than inheriting a fast-moving parent transform.
		# Parenting to the player can create visible jitter/choppiness because the body is influenced by both parent transform changes and physics.
		var terrain = get_tree().root.get_node_or_null("Node3D/dc_terrain")
		reparent(terrain if terrain != null else get_tree().root, true)
		gravity_scale = 0.0
		rotation = Vector3(0.0, 0.0, 0.0)
		isInteractable = false
		freeze = false
		lock_rotation = false
		sleeping = false
		# The player has started a new hold session.
		_hold_session_active = true
		# https://forum.godotengine.org/t/collisions-layers-masks/66193/2
		# Collision layer is what the body lies in. It's its little world, it just exists in that layer.
		collision_layer = (1 << (FOSSIL_LAYER_BIT - 1))
		# Collision mask is what the object looks towards when searching for collisions. It’s what it's interested in.
		collision_mask = 1 << (WORLD_LAYER_BIT - 1)
		set_collision_mask_value(PLAYER_LAYER_BIT, false) # ignore player while held

		# When picking up the fossil, we position it using a spherical-coordinate style target so it follows both
		# camera yaw and camera pitch. In other words, looking up/down moves the hold target up/down as well.
		#
		# We treat `hold_distance` as the spherical radius r, and we use the camera forward direction to recover
		# spherical angles:
		#   theta (azimuth)   = atan2(forward.x, forward.z)
		#   phi   (elevation) = asin(forward.y)
		#
		# The equivalent Cartesian offset for that direction and radius is:
		#   x = r * sin(theta) * cos(phi)
		#   y = r * sin(phi)
		#   z = r * cos(theta) * cos(phi)
		#
		# We still keep `hold_height` as a vertical anchor offset from the player origin, so the spherical center is
		# near the player's torso/head rather than near their feet.
		
		var cam: Node3D = player.get_node_or_null(camera_path)
		if cam:
			# cam_basis is a 3x3 matrix where the columns represent the camera's local x, y, and z axes in global space.
			# As stated before, we want the camera's forward vector, which is the negative z basis vector.
			var cam_basis: Basis = cam.global_transform.basis

			# We normalize the forward vector to ensure it has a length of 1.
			# A basis vector need not be a normal vector. It is merely guaranteed to be a part of a minimal spanning set of vectors of the space.
			var forward: Vector3 = -cam_basis.z.normalized()

			# atan2 gives azimuth theta from XZ, and asin gives elevation phi from Y.
			_hold_theta = atan2(forward.x, forward.z)
			_hold_phi = asin(forward.y)

			# We now get the player's global position for the sake of calculating the fossil's position relative to the player.
			var player_origin: Vector3 = player.global_transform.origin
			var anchor := player_origin + Vector3(0.0, hold_height, 0.0)

			# Now we can calculate the Cartesian offset from the spherical coordinates as described above.
			# We calculate cos(phi) once since it's used in both x and z calculations. 
			var cos_phi := cos(_hold_phi)

			# Our offset is some cartesian coordinate that is `hold_distance` away from the anchor point in the 
			# direction defined by the camera's forward vector.
			# We just need to translate from spherical to Cartesian coordinates using the formulas above, 
			# and then we can add that offset to the anchor point to get the final hold position.
			var offset := Vector3(
				sin(_hold_theta) * cos_phi * hold_distance,
				sin(_hold_phi) * hold_distance,
				cos(_hold_theta) * cos_phi * hold_distance
			)

			# Now we just add the offset.
			global_position = anchor + offset
		else:

			# In case the camera is not found for some reason,
			# we will fall back to placing the fossil near the player's anchor point.
			global_position = player.global_position + Vector3(0.0, hold_height, 0.0)
		player.is_holding = self
		
		var inv = player.get_node_or_null("Inventory")
		if inv and inv.has_method("add_item_to_inventory"):
			inv.add_item_to_inventory(fossil_res, 1)

func drop() -> bool:
	var cast = player.get_node("HeadPosition/LandingAnimation/Camera3D/SeeCast")
	var collider = cast.get_collider()
	if collider == null: #this check isn't perfect but it's better than nothing
		_reset_hold_rotation_offsets()
		# Once the fossil is dropped, 
		# we want it to be able to collide with the player again.
		_set_player_collision_ignored(false)
		# Any normal drop path ends the hold session.
		_hold_session_active = false
		reparent(get_tree().root.get_node("Node3D/dc_terrain"), true)
		gravity_scale = 1.0
		isInteractable = true
		freeze = false
		sleeping = false
		collision_layer = (1 << (FOSSIL_LAYER_BIT - 1))
		collision_mask = (1 << (WORLD_LAYER_BIT - 1)) | (1 << (PLAYER_LAYER_BIT - 1)) # collide with world and player again
		position -= player.global_transform.basis.z * 1.25
		
		return player.remove_held_item()
	return false

## This function is called to forcefully release the hold on the fossil.
## Currently it's only triggered when the fossil is pulled too far from the target hold point.
## Some notes:
## - The fossil is already parented under world terrain while held, so we do not need scene-tree surgery here.
## - Avoiding deferred callbacks keeps control flow easier to reason about and prevents queued stale releases.
## - We still keep this idempotent by checking hold session + current ownership before mutating
##
## For those that don't know, idempotent means that calling the function multiple times has the same effect as calling it once. 
## In this case, if the hold session is already inactive or if the player is not currently holding this fossil, 
## then calling _force_release_hold() will do nothing. This prevents issues where multiple calls to _force_release_hold() 
## could cause a null reference error.
func _force_release_hold() -> void:

	# If the hold session is already inactive, we can just return early. 
	# This prevents any further logic from running multiple times if _force_release_hold() is called again before the first call has finished processing.
	if not _hold_session_active:
		return
	
	# Safety check to ensure we don't accidentally mutate state if something has already changed.
	if player == null or player.is_holding != self:
		_hold_session_active = false
		return

	# Analogous to drop(), but we skip the collision check and we also don't need to reparent since we're already in world space.
	_reset_hold_rotation_offsets()

	# Just like in drop(), we want to make sure the fossil can collide with the player again once it's released.
	_set_player_collision_ignored(false)
	_hold_session_active = false
	gravity_scale = 1.0
	isInteractable = true
	freeze = false
	sleeping = false
	collision_layer = (1 << (FOSSIL_LAYER_BIT - 1))
	collision_mask = (1 << (WORLD_LAYER_BIT - 1)) | (1 << (PLAYER_LAYER_BIT - 1))

	print("Hold released due to exceeding max hold distance.")
	if player.has_method("remove_held_item"):
		player.remove_held_item()

	# Note that in general it is other script's responsibility to set player.is_holding = null.
	# The only time this is not true is when the player is still holding the fossil and presses
	# the drop key, which in player's _physics_process checks for input and then calls fossil.drop(). 
	# In that case, since drop() returns true, the player script will set player.is_holding = null.
	if player.is_holding == self:
		player.is_holding = null

## Called when the fossil's health reaches 0. Rewrite this function to extend behavior on destruction.
## Currently, it just prints a message and removes the fossil from the player's inventory if it's being held, 
## then removes the fossil from the scene.
func _on_health_depleted() -> void:
	if _is_destroying:
		return
	_is_destroying = true

	print("Fossil destroyed! Health has reached zero.")
	
	# Health depletion should terminate any active hold session immediately.
	# This also prevents force-hold logic from running again during the same frame.
	_reset_hold_rotation_offsets()

	# This shouldn't matter too much, but for the sake of cleanup
	# we restore the default collision behavior with the player 
	# in case it was being held when it was destroyed,
	_set_player_collision_ignored(false)
	_hold_session_active = false
	isInteractable = false
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0
	
	# Remove from player's inventory if being held
	if player and player.is_holding == self:
		if player.has_method("remove_held_item"):
			player.remove_held_item()
		if player.is_holding == self:
			player.is_holding = null
	
	_queue_free_after_depletion()


## This function queues the fossil for deletion after a delay to allow any final effects (like particles) to play out.
func _queue_free_after_depletion() -> void:
	# We check if the rock_particles node has a method to get the cleanup delay, 
	# which allows us to synchronize the fossil's removal with the duration of any death particles or effects.
	var cleanup_delay := 0.0
	if rock_particles and rock_particles.has_method("get_cleanup_delay"):
		cleanup_delay = rock_particles.get_cleanup_delay()

	if cleanup_delay > 0.0:
		await get_tree().create_timer(cleanup_delay).timeout

	queue_free()

## Accepts mouse motion while the item is held and applies camera-relative rotation to the hold target.
## [br]
## **Param** `mouse_delta`: The change in mouse position since the last frame.
## **Param** `roll_input`: Additional roll channel in the same units as mouse delta.
func apply_hold_rotation_input(mouse_delta: Vector2, roll_input: float = 0.0) -> void:
	if player == null:
		return

	# We want rotations to be relative to the camera/player, as opposed
	# to being relative to the fossil. This way, the controls feel consistent regardless of the fossil's current orientation.
	# If they are relative to the fossil, then consider what happens if the player rotates the fossil 90 degrees to the right.
	# In such a case, moving the mouse up or down to pitch the fossil would now (from their point of view)
	# be rolling it rather than pitching it, which can be disorienting.
	var cam: Node3D = player.get_node_or_null(camera_path)
	var view_basis: Basis = cam.global_transform.basis if cam else player.global_transform.basis
	view_basis = view_basis.orthonormalized()

	# Since the mouse input is in 2D (x and y), 
	# we will map the x movement to yaw (rotation around the up axis) and the y movement to pitch 
	# (rotation around the right axis).
	var view_up: Vector3 = view_basis.y.normalized()
	var view_right: Vector3 = view_basis.x.normalized()
	var view_forward: Vector3 = -view_basis.z.normalized()

	# We create three quaternions representing yaw, pitch, and roll rotations based on input,
	# then combine them into a single camera-relative delta rotation.
	var yaw_delta := -mouse_delta.x * hold_rotation_input_sensitivity
	var pitch_delta := -mouse_delta.y * hold_rotation_input_sensitivity
	var roll_delta := roll_input * hold_rotation_input_sensitivity
	var delta_q := (
		Quaternion(view_up, yaw_delta)
		* Quaternion(view_right, pitch_delta)
		* Quaternion(view_forward, roll_delta)
	).normalized()

	# To maintain the hold orientation relative to the camera's yaw, 
	# we need to update the _hold_rotation_offset based on the new camera orientation.
	var forward: Vector3 = -view_basis.z.normalized()
	var current_theta := atan2(forward.x, forward.z)
	var base_q := Basis(Vector3.UP, current_theta).get_rotation_quaternion()

	# We apply the delta rotation to the current target orientation 
	# which is the combination of the camera-yaw-aligned base orientation and 
	# the existing hold rotation offset) to get an updated target orientation,
	# and then we calculate the new hold rotation offset by comparing the updated target orientation to the base orientation.
	var current_target_q := (base_q * _hold_rotation_offset).normalized()
	var updated_target_q := (delta_q * current_target_q).normalized()
	_hold_rotation_offset = (base_q.inverse() * updated_target_q).normalized()

## Builds the target basis for a held fossil from camera yaw and camera-relative rotation offset.
## [br]
## **Returns**: Basis - The target orientation basis for the held fossil, combining camera yaw and mouse-driven rotation offset.
func _get_hold_target_basis() -> Basis:
	var base_q := Basis(Vector3.UP, _hold_theta).get_rotation_quaternion()
	return Basis((base_q * _hold_rotation_offset).normalized())

## Clears mouse-driven hold rotation offsets so a fresh pickup starts from camera-aligned orientation.
func _reset_hold_rotation_offsets() -> void:
	_hold_rotation_offset = Quaternion.IDENTITY

## Toggles direct collision exceptions with the player while this fossil is held.
## [br]
## **Param** `ignored`: If true, the fossil will ignore collisions with the player; if false, it will collide normally.
func _set_player_collision_ignored(ignored: bool) -> void:
	if player == null:
		return
	if ignored:
		# docs.godotengine.org/en/stable/classes/class_physicsbody3d.html#class-physicsbody3d-method-add-collision-exception-with
		add_collision_exception_with(player)
	else:
		# https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html#class-physicsbody3d-method-remove-collision-exception-with
		remove_collision_exception_with(player)

# https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html#class-rigidbody3d-private-method-integrate-forces
# This function is called during the physics step and allows us to read contact data to implement custom collision responses, 
# in this case applying damage based on impact speed.

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# See the above comments in interact() for the rationale behind this code. 
	if player and player.is_holding == self and _hold_session_active:
		# If we have a player and the player is holding this fossil, 
		# we compute a target hold position in front of the player and drive the fossil toward it using physically applied forces.
		#
		# We avoid setting state.transform directly each frame while held. Hard-setting transforms is effectively teleporting the body,
		# which can conflict with collision response and can produce clipping/tunneling behavior around nearby geometry.
		#
		# Instead we use a spring-damper model:
		#   hold_force = (position_error * hold_spring_strength) + (velocity_error * hold_damping)
		# and clamp the result to max_hold_force for stability and predictable gameplay feel.
		#
		# This gives a much more "in-hand" feel while still letting world collisions push the fossil away naturally.

		# First we calculate the target hold position based on the player's current position and camera orientation,
		# using the same spherical-coordinate logic as in interact().
		var cam: Node3D = player.get_node_or_null(camera_path)
		var cam_basis: Basis = cam.global_transform.basis if cam else player.global_transform.basis
		var forward: Vector3 = -cam_basis.z.normalized()
		_hold_theta = atan2(forward.x, forward.z)
		_hold_phi = asin(clamp(forward.y, -1.0, 1.0))
		var origin: Vector3 = player.global_transform.origin
		var anchor := origin + Vector3(0.0, hold_height, 0.0)
		var cos_phi := cos(_hold_phi)
		var offset := Vector3(
			sin(_hold_theta) * cos_phi * hold_distance,
			sin(_hold_phi) * hold_distance,
			cos(_hold_theta) * cos_phi * hold_distance
		)
		var target: Vector3 = anchor + offset

		# See interact() comments for explanation of the hold positioning logic.

		# Now we have the target hold position, we can calculate the spring force to apply to the fossil to pull it toward that target.

		# to_target is the vector from the fossil's current position to the target hold position. This is our position error.
		var to_target := target - state.transform.origin
		var distance_to_target := to_target.length()

		# In case the fossil is pulled very far from the target hold point (e.g. by a strong collision), 
		# we want to release it so it doesn't feel like the player has mile long arms or strings attached to the fossil.
		if distance_to_target > max_hold_distance_from_target:
			# Release immediately when the fossil is pulled too far from the target hold point.
			# This avoids asynchronous/deferred cleanup and keeps the hold lifecycle local to this script.
			_force_release_hold()
			return

		# Use the carrier's real velocity as desired velocity so the fossil tracks the player's movement more tightly.
		# This significantly reduces the "floating on a string" feeling during acceleration/strafe turns because the body
		# is not only pulled to a position, it is also asked to match the carrier's velocity.
		var desired_velocity := Vector3.ZERO
		if player.has_method("get_real_velocity"):
			desired_velocity = player.get_real_velocity()

		# Spring term pulls toward target. Damping/velocity term aligns body velocity with the carrier velocity.
		# Combined, these make the object snap back and hold at the target quickly,
		# but still feel much better than having it teleport to the target every frame and clip through nearby geometry.

		# Velocity error is the difference between the desired velocity (e.g. player's velocity) and the fossil's current velocity.
		var velocity_error := desired_velocity - state.linear_velocity

		# Hold force is the sum of the spring force (proportional to position error) and the damping force (proportional to velocity error).
		# Remember that the ODE spring equation is 
		# F = kx + bx' + mx'' where k is the spring constant, b is the damping coefficient, and m is the mass.
		# In our case, we are directly calculating the force F to apply each frame based on the current position error (x) and velocity error (x'), 
		# where the spring constant k is hold_spring_strength and the damping coefficient b is hold_damping.
		# We omit the mass term since the physics engine will take care of that when we apply the force.
		# Rather than try to solve the differential equation for a specific desired response, we can experimentally tune hold_spring_strength and hold_damping to achieve a good feel.
		var hold_force := (to_target * hold_spring_strength) + (velocity_error * hold_damping)

		# Once we have the hold force, we limit it to the maximum allowed force to prevent any extreme values that could result in anomalous behavior.
		if hold_force.length() > max_hold_force:
			hold_force = hold_force.normalized() * max_hold_force

		# https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html#class-rigidbody3d-method-apply-central-force
		# Applies a directional force without affecting rotation. A force is time dependent and meant to be applied every physics update.
		# This is equivalent to using apply_force() at the body's center of mass.
		state.apply_central_force(hold_force)


		# So the above code handles getting the fossil to the right position, but we also want it to have the right orientation while held.
		# In our case, we want the fossil to maintain a consistent orientation relative to the player's camera yaw, so it doesn't feel like it's spinning around while held. 
		# We can achieve this by applying a corrective torque to the fossil that tries to align its orientation with the desired orientation based on the camera yaw.

		# https://en.wikipedia.org/wiki/Euler_angles
		# Euler angles are a way to represent 3D rotations using three angles (often called pitch, yaw, and roll).
		# However, Euler angles can suffer from gimbal lock and can be unintuitive to work with when trying to calculate smooth rotational corrections, 
		# especially when you want to correct across multiple axes simultaneously.
		# https://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation
		# Instead of using Euler angles, we can use quaternions to represent the fossil's current orientation and the desired orientation, 
		# and then calculate the rotational error as a quaternion difference.
		#
		# Brief primer for readers unfamiliar with these terms:
		# Euler angles describe a rotation by applying three separate rotations around the coordinate axes (for example: rotate around X, then Y, then Z).
		# This is intuitive because you can think "pitch, yaw, roll" like a plane, but it has practical problems: the order of the rotations matters
		# (rotating X then Y is different from Y then X), and certain combinations cause two axes to align so one degree of freedom is lost,
		# which is called gimbal lock. In gimbal lock a small change in desired orientation can require a very large or poorly behaved
		# change in the Euler angles, which makes smooth control difficult. For an intuitive example of gimbal lock, see https://en.wikipedia.org/wiki/Gimbal_lock.
		#
		# Quaternions are a compact mathematical way to represent 3D rotation without those singularities (points where the representation becomes undefined). 
		# A quaternion can be thought of as an axis (a unit 3D direction) plus an angle around that axis (an axis-angle representation),
		# but encoded as a 4-component value that  composes cleanly. Quaternion multiplication composes rotations without re-ordering pitfalls, 
		# and taking the "difference" between two quaternions produces a single quaternion that describes the minimal rotation from one orientation to the other. 
		# Converting that quaternion error into an axis and angle lets us drive a good looking torque without teleports: torque = axis * angle * gain, with additional
		# damping applied to the angular velocity. That proportional derivative (PD) style controller corrects pitch/yaw/roll simultaneously and avoids the instability
		# and ambiguity Euler-based corrections would introduce.
		#
		# Formally, this can be described in the lens of group theory.
		# The set of all 3D rotations about the origin forms a mathematical group called SO(3) (the special orthogonal group in 3 dimensions).
		# A group is a set equipped with a composition operation (here: perform rotation A then rotation B) that has an identity element,
		# inverses, and associativity. SO(3) is non-commutative (nonabelian): the order of rotations matters. Unit quaternions (quaternions of length 1)
		# form a group under multiplication that is closely related to SO(3). In fact, unit quaternions provide a double-cover of SO(3)
		# (commonly written as SU(2) or Spin(3) in algebraic terms), which means each rotation in SO(3) corresponds to two opposite unit
		# quaternions. Practically, this algebraic structure is why quaternion multiplication cleanly represents rotation composition,
		# why inverses are simple (conjugate the quaternion), and why taking a quaternion difference (desired * inverse(current)) maps
		# naturally to the minimal group element that transforms the current orientation into the desired one.
		#
		# This group-theoretic perspective is helpful because the PD-style torque controller we're using is effectively operating on the
		# Lie-group manifold of rotations (basically a mathematical object that lets us both do calculus and group operations):
		# we compute an error element in the group (the quaternion error), convert it into a tangent-space
		# axis-angle (an element of the Lie algebra), and apply forces proportional to that tangent error and its derivative. That avoids
		# the discontinuities and singularities that appear if one tries to treat rotations as simple 3D vectors.

		# We want the fossil to rotate with the player's camera yaw, which is represented by _hold_theta.
		# This is so that if for example the player is holding the fossil and looking around, if they look to the north, 
		# they will see the front of the fossil, and if they look to the south, they will still see the front of the fossil, 
		# instead of the fossil always being oriented in the same direction regardless of where the player is looking.
		# Moreover, since we're using quaternions we don't have to think about order of rotations, we can just use the earlier
		# explained algebraic approach to basically do:
		#
		# error_q = desired_q * inverse(current_q)
		#
		# Then convert error_q to axis-angle and apply a PD controller:
		# 
		# torque = axis * angle * hold_rotation_spring - angular_velocity * hold_rotation_damping
		#

		# We orthonormalize the basis to ensure it is a valid rotation matrix. All rotation matrices should be orthonormal, 
		# meaning each column is a unit vector and the columns are mutually orthogonal (defined in various ways but one simple one 
		# is that the dot product of any two different columns should be zero).
		# https://docs.godotengine.org/en/stable/classes/class_basis.html
		var current_basis: Basis = state.transform.basis.orthonormalized()
		var desired_basis: Basis = _get_hold_target_basis().orthonormalized()

		# current_q is the fossil's current orientation as a quaternion, and desired_q is the target orientation based on the camera yaw.
		# https://docs.godotengine.org/en/stable/classes/class_quaternion.html
		var current_q: Quaternion = current_basis.get_rotation_quaternion()
		var desired_q: Quaternion = desired_basis.get_rotation_quaternion()
		var error_q: Quaternion = (desired_q * current_q.inverse()).normalized()

		# Quaternions q and -q represent the same orientation; forcing positive w selects the shorter corrective path.
		# Why is this true? Think of it this way: if we have a desired orientation and a current orientation, 
		# there are actually two paths to get from the current orientation to the desired orientation: one is the "short way" and the other is the "long way" that goes around the opposite direction.
		# Like if I'm looking slightly to the left of something and want to look right at it I can either turn a little bit to the right (short way) or turn almost all the way around to the left (long way).
		# Since quaternions represent rotations in a double-cover way, both q and -q represent the same rotation. However, when we calculate the error quaternion as desired * inverse(current),
		# we might get either the short path or the long path depending on the signs of the quaternion components. 
		# By enforcing that the w component of the error quaternion is positive, we ensure that we always take the short path for correction, which results in more intuitive behavior.
		# Now you might be asking "well that makes sense, but why does the positive w component correspond to the short path?"
		# The quaternion representing a rotation can be expressed as q = [v*sin(theta/2), cos(theta/2)] where v is the rotation axis and theta is the rotation angle.
		# When theta is between 0 and 180 degrees, cos(theta/2) is positive, which corresponds to the short path. When theta is between 180 and 360 degrees, cos(theta/2) is negative, which corresponds to the long path. 
		# By enforcing w > 0, we ensure that theta is always between 0 and 180 degrees, thus taking the short path.
		if error_q.w < 0.0:
			error_q = Quaternion(-error_q.x, -error_q.y, -error_q.z, -error_q.w)

		# Angle error is the angle of rotation needed to correct the orientation, and axis error is the axis around which we need to apply that rotation.
		var angle_error: float = error_q.get_angle()
		var axis_error: Vector3 = error_q.get_axis()

		var rotation_torque := Vector3.ZERO
		if angle_error > 0.0001:
			rotation_torque = (axis_error * angle_error * hold_rotation_spring) - (state.angular_velocity * hold_rotation_damping)
		else:
			# Near the target orientation, we mostly want to remove all residual angular velocity to avoid micro-jitter.
			rotation_torque = -state.angular_velocity * hold_rotation_damping

		# As with the positional force, we clamp the rotation torque to a maximum value to prevent extreme corrections that could produce erratic behavior.
		if rotation_torque.length() > max_hold_torque:
			rotation_torque = rotation_torque.normalized() * max_hold_torque

		# https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html#class-rigidbody3d-method-apply-torque
		# Applies a rotational force (torque) to the body. Like apply_central_force, this is time dependent and meant to be applied every physics update. 
		state.apply_torque(rotation_torque)

	# https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html#class-physicsdirectbodystate3d-method-get-contact-count
	# Returns the number of contacts (collisions) currently involving this body. 
	var contact_count := state.get_contact_count()
	if contact_count == 0:
		# No contacts, so nothing to process for damage.
		return

	# Approximate linear velocity even when the body is driven kinematically by parenting.
	var carrier_vel := Vector3.ZERO
	var using_carrier := false
	if player and player.is_holding == self and player.has_method("get_real_velocity"):
		carrier_vel = player.get_real_velocity()
		using_carrier = true

	print("Carrier velocity: ", carrier_vel, ", carrier speed: ", carrier_vel.length())
	# Keeps track of which contact had the highest relative speed, so we can apply damage based on that.
	# We don't sum damage across contacts because that leads to a lot more damage than might be expected by the player,
	# who from their perspective might have just hit one thing, not multiple things at once. 
	var max_speed := 0.0
	for i in contact_count:
		# https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html#class-physicsdirectbodystate3d-method-get-contact-local-velocity-at-position
		# Returns the relative velocity at the contact point in local space. 
		# This is the velocity of the other body relative to this one.
		var rel_vel := state.get_contact_local_velocity_at_position(i)
		var contact_normal := state.get_contact_local_normal(i)
		var normal_speed : float
		if using_carrier:
			normal_speed = abs(carrier_vel.dot(contact_normal))
		else:
			normal_speed = abs(rel_vel.dot(contact_normal))
		max_speed = max(max_speed, rel_vel.length(), normal_speed)

	# print("Max impact speed from contacts: ", max_speed)

	# We only apply damage if the impact speed exceeds our threshold, 
	# so stuff like just leaving the fossil on the ground or gently placing it down doesn't cause damage.
	if max_speed >= min_damage_speed:
		print("Applying damage from impact. Impact speed: ", max_speed, ", Health before: ", health)
		# We calculate damage as a linear function of how much the impact speed exceeds the threshold, multiplied by our damage multiplier.
		# This is opposed to calculating it as max_speed * damage_per_speed, as that would mean anything barely above the threshold could cause a lot of damage
		# if the threshold is high enough, while something barely below the threshold would cause no damage at all, which could be frustrating.
		var damage_amount := (max_speed - min_damage_speed) * damage_per_speed
		health = clamp(health - damage_amount, 0.0, MAX_HEALTH)

		# Give a visual indicator of damage, 
		# both when it happens via particles and by darkening the fossil's materials based on its current health.
		play_damage_particles(damage_particle_count)
		_update_damage_visuals()
		
		# Check if fossil has been destroyed
		if health <= 0:
			_on_health_depleted()

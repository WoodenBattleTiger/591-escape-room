extends Node3D


## This will be used for everytime a player held item needs to leave their hands and 
## then arrive at some fixed location

# placing a jacketed fossil on the table
# placing a still damaged fossil in the 3d printer for repair
# placing a fully repaired bone into the skeleton

var tracked_held_item
var player : Player

var printNumber = 0

## magnitude of the sphere that marks the correct spot
@export var position_closeness_threshold = 0.25

## number of degrees that the rotation should be within for the object to snap into place
@export var rotation_closeness_threshold = 100

#the fossil type that the snap location is allowed to take (FossilItem.FOssilState.JACKETED, etc.)
@export var fossilTypeAllowed: FossilItem.FossilState = FossilItem.FossilState.JACKETED

## name of the object to snap to this location. if empty, will accept any object
@export var snapped_object_name : String = ""

@export var snap_time : float = 0.1

## Opacity of the ghost placement preview mesh.
@export_range(0.0, 1.0, 0.01) var ghost_alpha := 0.35

## Tint used for the ghost placement preview.
@export var ghost_tint := Color(0.65, 0.85, 1.0, 0.35)

#tracks the fossil being held
var object : FossilItem
var ghost_preview: Node3D
var ghost_preview_source_name := ""


@onready var snap_particles = $SnapParticles

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_tree().get_nodes_in_group("player")[0]
	#position_closeness_threshold = 0.25
	#rotation_closeness_threshold = 100.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	_update_ghost_preview()
	
	if player.is_holding: # TODO also add a check to make sure it is actually the correct object
		
		# TODO remove and turn back into functionsvar dist = global_position.distance_to(object.global_position)
		object = player.is_holding
		
		#null check because of occassional race condition
		if not is_instance_valid(object):
			return

		if object.fossilAssigned == null:
			return
		
		
		if not _matches_object_name(object):
			# TODO TEST THIS later
			return
			
		# distance check
		var dist = global_position.distance_to(object.global_position)
		var l_check = dist < position_closeness_threshold
		
		# rotation check
		var rot_a = global_transform.basis.get_rotation_quaternion()
		var rot_b = object.global_transform.basis.get_rotation_quaternion()
		var angle_dist = rad_to_deg(rot_a.angle_to(rot_b))
		var r_check =  angle_dist < rotation_closeness_threshold
		
		if printNumber % 100 == 0:
			print("name: ", name)
			print("distance: ", dist, ": ", l_check, "   angle: ", angle_dist, ": ", r_check)
			print(object.currFossilState, fossilTypeAllowed)
		printNumber += 1

		if l_check and r_check and object.currFossilState == fossilTypeAllowed:
			snap_object()


func _matches_object_name(fossil: FossilItem) -> bool:
	if fossil == null or fossil.fossilAssigned == null:
		return false
	if snapped_object_name.strip_edges() == "":
		# Printed fossils must have an explicit target slot name.
		return fossilTypeAllowed != FossilItem.FossilState.PRINTED
	return snapped_object_name.to_lower() == fossil.fossilAssigned.name.to_lower()


func _update_ghost_preview() -> void:
	if not visible:
		_clear_ghost_preview()
		return

	if fossilTypeAllowed != FossilItem.FossilState.PRINTED:
		_set_ghost_visible(false)
		return

	if not player.is_holding:
		_set_ghost_visible(false)
		return

	var held_fossil := player.is_holding as FossilItem
	if held_fossil == null or not is_instance_valid(held_fossil):
		_set_ghost_visible(false)
		return

	if held_fossil.currFossilState != FossilItem.FossilState.PRINTED:
		_set_ghost_visible(false)
		return

	if held_fossil.fossilAssigned == null:
		_set_ghost_visible(false)
		return

	if not _matches_object_name(held_fossil):
		_set_ghost_visible(false)
		return

	_ensure_ghost_preview(held_fossil)
	_set_ghost_visible(true)


func _ensure_ghost_preview(held_fossil: FossilItem) -> void:
	var source_name = held_fossil.fossilAssigned.name
	if ghost_preview != null and is_instance_valid(ghost_preview) and ghost_preview_source_name == source_name:
		return

	_clear_ghost_preview()

	ghost_preview = held_fossil.fossilAssigned.duplicate() as Node3D
	if ghost_preview == null:
		ghost_preview_source_name = ""
		return

	ghost_preview.name = "GhostPreview"
	ghost_preview_source_name = source_name
	add_child(ghost_preview)
	ghost_preview.transform = Transform3D.IDENTITY
	_configure_ghost_tree(ghost_preview)


func _configure_ghost_tree(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.material_override is BaseMaterial3D:
			mesh.material_override = _create_ghost_material(mesh.material_override as BaseMaterial3D)
		elif mesh.mesh != null:
			for surface_index in mesh.mesh.get_surface_count():
				var active_material := mesh.get_active_material(surface_index)
				if active_material is BaseMaterial3D:
					mesh.set_surface_override_material(surface_index, _create_ghost_material(active_material as BaseMaterial3D))

	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0

	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true

	for child in node.get_children():
		_configure_ghost_tree(child)


func _create_ghost_material(source_material: BaseMaterial3D) -> BaseMaterial3D:
	var ghost_material := source_material.duplicate() as BaseMaterial3D
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(ghost_tint.r, ghost_tint.g, ghost_tint.b, ghost_alpha)
	return ghost_material


func _set_ghost_visible(visible_state: bool) -> void:
	if ghost_preview != null and is_instance_valid(ghost_preview):
		ghost_preview.visible = visible_state


func _clear_ghost_preview() -> void:
	if ghost_preview != null and is_instance_valid(ghost_preview):
		ghost_preview.queue_free()
	ghost_preview = null
	ghost_preview_source_name = ""
 

func snap_object():
	print("snapping the object")
	# Find the audio manager
	var audio_manager = get_tree().root.get_node_or_null("Level/DungeonCrawlerAudioManager")
	if audio_manager and audio_manager.has_method("play_sound_effect"):
		print("playing sound effect")
		
		if fossilTypeAllowed == FossilItem.FossilState.PRINTED: # basically checking if we are one of the final ones
			audio_manager.play_sound_effect("snapToPosClick")
		else:
			print("the second sfx")
			audio_manager.play_sound_effect("snapToPosClick2", 0.5, 0.5)
	
	# remove it from the player
	object = player.is_holding
	#player.remove_held_item() # TODO the inventory is very broken, figure out if we are scrapping it or not
	player.is_holding = null
	
	# stop physics for the object
	object.freeze = true
	object.lock_rotation = true

	# switch the fossil state on snapping
	object.update_state_on_snap()
	_clear_ghost_preview()
	
	var tween = get_tree().create_tween()
	tween.set_parallel()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(object, "global_transform", global_transform, snap_time)
	

	if fossilTypeAllowed == FossilItem.FossilState.PRINTED: # basically checking if we are one of the final ones
		tween.tween_callback(play_particles).set_delay(snap_time)



func play_particles():
	print("particles GO!")
	# but they aren't actually happening?
	snap_particles.one_shot = true
	snap_particles.emitting = true


func _exit_tree() -> void:
	_clear_ghost_preview()
	
	

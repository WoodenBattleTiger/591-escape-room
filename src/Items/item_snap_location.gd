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

#tracks the fossil being held
var object : FossilItem


@onready var snap_particles = $SnapParticles

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_tree().get_nodes_in_group("player")[0]
	#position_closeness_threshold = 0.25
	#rotation_closeness_threshold = 100.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	
	if player.is_holding: # TODO also add a check to make sure it is actually the correct object
		
		# TODO remove and turn back into functionsvar dist = global_position.distance_to(object.global_position)
		object = player.is_holding
		
		#null check because of occassional race condition
		if not is_instance_valid(object):
			return
		
		
		if not (snapped_object_name == "" or snapped_object_name.to_lower() == object.fossilAssigned.name.to_lower()):
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
 

func snap_object():
	print("snapping the object")
	# Find the audio manager
	var audio_manager = get_tree().root.get_node_or_null("Level/DungeonCrawlerAudioManager")
	if audio_manager and audio_manager.has_method("play_sound_effect"):
		print("playing sound effect")
		audio_manager.play_sound_effect("snapToPosClick", 0.5, 0.5)
	
	# remove it from the player
	object = player.is_holding
	#player.remove_held_item() # TODO the inventory is very broken, figure out if we are scrapping it or not
	player.is_holding = null
	
	# stop physics for the object
	object.freeze = true
	object.lock_rotation = true

	# switch the fossil state on snapping
	object.update_state_on_snap()
	
	var tween = get_tree().create_tween()
	tween.tween_property(object, "global_transform", global_transform, snap_time)
	tween.set_ease(Tween.EASE_IN)
	
	# TODO play particles and a sound effect
	tween.tween_callback(self.play_particles)
	tween.tween_callback(func(): hide())


func play_particles():
	snap_particles.one_shot = true
	snap_particles.emitting = true
	
	

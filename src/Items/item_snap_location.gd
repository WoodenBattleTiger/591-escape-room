extends Node3D


## This will be used for everytime a player held item needs to leave their hands and 
## then arrive at some fixed location

# placing a jacketed fossil on the table
# placing a still damaged fossil in the 3d printer for repair
# placing a fully repaired bone into the skeleton

var tracked_held_item
var player : Player

## magnitude of the sphere that marks the correct spot
@export var position_closeness_threshold = 0.25

## number of degrees that the rotation should be within for the object to snap into place
@export var rotation_closeness_threshold = 100

#the fossil type that the snap location is allowed to take (FossilItem.FOssilState.JACKETED, etc.)
@export var fossilTypeAllowed: FossilItem.FossilState = FossilItem.FossilState.JACKETED

## name of the object to snap to this location. if empty, will accept any object
@export var snapped_object_name : String = ""

#tracks the fossil being held
var object : FossilItem

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_tree().get_nodes_in_group("player")[0]
	#position_closeness_threshold = 0.25
	#rotation_closeness_threshold = 100.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	
	if player.is_holding: # TODO also add a check to make sure it is actually the correct object
		pass
		
		
		# but check position and rotation separately
		#var lc = location_check(player.is_holding)
		#var rc = rotation_check(player.is_holding)
		
		# TODO remove and turn back into functionsvar dist = global_position.distance_to(object.global_position)
		object = player.is_holding
		
		#null check because of occassional race condition
		if not is_instance_valid(object):
			return
			
		# distance check
		var dist = global_position.distance_to(object.global_position)
		var l_check = dist < position_closeness_threshold
		
		# rotation check
		var rot_a = global_transform.basis.get_rotation_quaternion()
		var rot_b = object.global_transform.basis.get_rotation_quaternion()
		var angle_dist = rad_to_deg(rot_a.angle_to(rot_b))
		var r_check =  angle_dist < rotation_closeness_threshold
		
		#print("distance: ", dist, ": ", l_check, "   angle: ", angle_dist, ": ", r_check)
		
		if l_check and r_check and object.currFossilState == fossilTypeAllowed:
			 # TODO TEST THIS later
			if snapped_object_name == "" or snapped_object_name == object.fossilAssigned.name:
				snap_object()
 

func snap_object():
	print("snapping the object")
	
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
	tween.tween_property(object, "global_transform", global_transform, 0.1)
	tween.set_ease(Tween.EASE_IN)
	
	# TODO play particles and a sound effect
	tween.tween_callback(self.play_particles)
	tween.tween_callback(func(): hide())


func play_particles():
	$GPUParticles3D.one_shot = true
	$GPUParticles3D.emitting = true
	
	

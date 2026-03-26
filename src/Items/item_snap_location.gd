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
@export var rotation_closeness_threshold = 15

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_tree().get_nodes_in_group("player")[0]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	
	if player.is_holding: # TODO also add a check to make sure it is actually the correct object
		pass
		
		
		# but check position and rotation separately
		#var lc = location_check(player.is_holding)
		#var rc = rotation_check(player.is_holding)
		
		# TODO remove and turn back into functionsvar dist = global_position.distance_to(object.global_position)
		var object = player.is_holding
		
		# distance check
		var dist = global_position.distance_to(object.global_position)
		var l_check = dist < position_closeness_threshold
		
		# rotation check
		var rot_a = global_transform.basis.get_rotation_quaternion()
		var rot_b = object.global_transform.basis.get_rotation_quaternion()
		var angle_dist = rad_to_deg(rot_a.angle_to(rot_b))
		var r_check =  angle_dist < rotation_closeness_threshold
		
		#print("distance: ", dist, ": ", l_check, "   angle: ", angle_dist, ": ", r_check)
		
		if l_check and r_check:
			snap_object()
 

func snap_object():
	print("snapping the object")
	
	# remove it from the player
	var object :RigidBody3D = player.is_holding
	#player.remove_held_item() # TODO the inventory is very broken, figure out if we are scrapping it or not
	player.is_holding = null
	
	# stop physics for the object
	object.freeze = true
	object.lock_rotation = true
	
	
	var tween = get_tree().create_tween()
	tween.tween_property(object, "global_transform", global_transform, 0.1)
	tween.set_ease(Tween.EASE_IN)
	
	# TODO play particles and a sound effect
	
	

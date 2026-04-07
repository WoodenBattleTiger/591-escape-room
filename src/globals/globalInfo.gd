extends Node

var fossil_scenes_triceratops: Array = [
	"res://src/Items/Fossils/triceratops/tri_neck_bone.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_thigh.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_shoulder.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_flank.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_hip.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_forearm.tscn",
	"res://src/Items/Fossils/triceratops/tri_rib_2.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_thigh.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_shoulder.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_flank.tscn",
	"res://src/Items/Fossils/triceratops/tri_skull.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_shin.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_hip.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_forearm.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_horn.tscn",
	"res://src/Items/Fossils/triceratops/tri_rib_3.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_lower_arm.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_hand.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_shin.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_lower_arm.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_finger_1.tscn",
	"res://src/Items/Fossils/triceratops/tri_lower_jaw.tscn",
	"res://src/Items/Fossils/triceratops/tri_rib.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_hand.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_foot.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_foot.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_finger_2.tscn",
]

var fossil_scenes_tyrannosaur: Array = [
	"res://src/Items/Fossils/tyrannosaur/tyran_hip_and_pelvis.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_left_shoulder.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_right_thigh.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_left_arm.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_skull.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_left_thigh.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_right_arm.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_left_calf.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_right_shin.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_left_foot.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_right_shoulder.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_right_foot.tscn",
	"res://src/Items/Fossils/tyrannosaur/tyran_tooth.tscn"
]

var shuffled_triceratops_scenes: Array = []
var shuffled_tyrannosaur_scenes: Array = []

func _ready():
	shuffled_triceratops_scenes = fossil_scenes_triceratops
	shuffled_tyrannosaur_scenes = fossil_scenes_tyrannosaur
	#shuffle_triceratops()
	#shuffle_tyrannosaur()

func shuffle_triceratops():
	shuffled_triceratops_scenes = fossil_scenes_triceratops.duplicate()
	shuffled_triceratops_scenes.shuffle()
	
func shuffle_tyrannosaur():
	shuffled_tyrannosaur_scenes = fossil_scenes_tyrannosaur.duplicate()
	shuffled_tyrannosaur_scenes.shuffle()

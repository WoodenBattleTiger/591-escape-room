extends Node

var fossil_scenes_triceratops: Array = [
	"res://src/Items/Fossils/triceratops/tri_left_finger_1.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_finger_2.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_flank.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_foot.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_forearm.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_hand.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_hip.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_horn.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_lower_arm.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_shin.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_shoulder.tscn",
	"res://src/Items/Fossils/triceratops/tri_left_thigh.tscn",
	"res://src/Items/Fossils/triceratops/tri_lower_jaw.tscn",
	"res://src/Items/Fossils/triceratops/tri_neck_bone.tscn",
	"res://src/Items/Fossils/triceratops/tri_rib.tscn",
	"res://src/Items/Fossils/triceratops/tri_rib_2.tscn",
	"res://src/Items/Fossils/triceratops/tri_rib_3.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_flank.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_foot.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_forearm.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_hand.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_hip.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_lower_arm.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_shin.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_shoulder.tscn",
	"res://src/Items/Fossils/triceratops/tri_right_thigh.tscn",
	"res://src/Items/Fossils/triceratops/tri_skull.tscn",
]

var shuffled_triceratops_scenes: Array = []

func _ready():
	shuffle_triceratops()

func shuffle_triceratops():
	shuffled_triceratops_scenes = fossil_scenes_triceratops.duplicate()
	shuffled_triceratops_scenes.shuffle()

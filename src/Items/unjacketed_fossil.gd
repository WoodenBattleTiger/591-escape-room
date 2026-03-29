# unjacketed_fossil.gd
extends "res://src/Items/fossil_item.gd"

func _ready() -> void:
	super._ready()
	var interactableText = "Press \"e\" to pickup unjacketed fossil"

func interact() -> void:
	print("The unjacketed fossil is on the table. Do the interaction for getting it here.")
	pickup()

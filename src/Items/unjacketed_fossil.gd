# unjacketed_fossil.gd
extends "res://src/Items/fossil_item.gd"

func _ready() -> void:
	super._ready()
	interactableText = "Press \"e\" to pickup unjacketed fossil"

func interact() -> void:
	print("doing interaction with unjacketed fossil")
	pickup()

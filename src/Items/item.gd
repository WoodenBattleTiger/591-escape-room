extends Resource

class_name Item

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var weight := 1.0
@export var stack_size := 99
@export_multiline var description := "" # Optional flavor text kept on the data asset so UI/tooltips can stay dumb.

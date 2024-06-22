extends Camera3D

@export var MAX_X_ROTATION = 70

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	rotation_degrees.x = clamp(rotation_degrees.x, -MAX_X_ROTATION, MAX_X_ROTATION)

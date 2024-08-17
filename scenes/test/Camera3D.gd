extends Camera3D

@export var MAX_X_ROTATION = 70
@export var CAMERA_SENSITIVITY = 0.1

@onready var player = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    rotation_degrees.x = clamp(rotation_degrees.x, -MAX_X_ROTATION, MAX_X_ROTATION)

func _input(event):
    if event is InputEventMouseMotion:
        var mouse_sensitivity = 0.01
        var rx = deg_to_rad(-event.relative.y * CAMERA_SENSITIVITY)
        rotate_x(rx)
        var ry = deg_to_rad(-event.relative.x * CAMERA_SENSITIVITY)
        player.rotate_y(ry)

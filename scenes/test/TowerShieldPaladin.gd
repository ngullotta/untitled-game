extends Node3D

@onready var player = get_parent()

# Shield stuff
const SHIELD_FORCE = 20
var shield_default_pos = Vector3.ZERO
var shield_default_rota = Vector3.ZERO

var shield_target_pos = Vector3.ZERO
var shield_target_rota = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready():
	shield_default_pos = position
	shield_default_rota = rotation

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	shield_target_pos = player.camera.position
	shield_target_pos.z -= 0.5 # put it a little in front
	shield_target_pos.y -= 1.10 # put it a little down
	shield_target_rota = shield_default_rota
	shield_target_rota.y = deg_to_rad(90)
	if player.has_active_state(player.State.SHIELDING):
		position = lerp(
			position,
			shield_target_pos,
			SHIELD_FORCE * delta
		)
		rotation = lerp(
			rotation,
			shield_target_rota,
			SHIELD_FORCE * delta
		)
	else:
		position = lerp(
			position,
			shield_default_pos,
			(SHIELD_FORCE * 0.25) * delta
		)
		rotation = lerp(
			rotation,
			shield_default_rota,
			(SHIELD_FORCE * 0.25) * delta
		)

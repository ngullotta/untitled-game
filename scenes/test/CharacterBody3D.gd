extends CharacterBody3D

enum State {
	IDLE = 0x1,
	JUMPING = 0x2,
	DASHING = 0x4,
	GROUND_POUNDING = 0x8
}

# State tracking
@export var state = State.IDLE
var last_velocity = Vector3.ZERO
var last_direction = Vector3.ZERO
var last_camera_aim = Vector3.ZERO

@onready var camera = $Camera3D
@onready var dash_rect = $Camera3D/ColorRect

const SPEED = 15.0
const JUMP_VELOCITY = 7.0
const DASH_FORCE = 200

# Camera Stuff
@export var CAMERA_SENSITIVITY = 0.1

# Jump Stuff
@export var jump_counter = 0

# Dash stuff
@export var dash_acceleration = 9
@export var dash_speed = 1

# Timers
var dash_timer = 0
var dash_time = 0.2

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func set_active_state(value, yn := true):
	if yn:
		state |= value
	else:
		state &= ~value
		
func has_active_state(value):
	return bool(state & value)

func _state_to_label():
	var labels = []
	if has_active_state(State.IDLE):
		labels.append("IDLE")
	if has_active_state(State.DASHING):
		labels.append("DASHING")
	if has_active_state(State.GROUND_POUNDING):
		labels.append("GROUND_POUNDING")
	return " | ".join(labels)

func process_ticks(delta):
	dash_timer -= delta
	if dash_timer < 0:
		dash_rect.set_visible(false)
		dash_timer = 0
		set_active_state(State.DASHING, false)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process_input(true)
	dash_rect.set_visible(false)

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Reset double-jump
	if is_on_floor():
		jump_counter = 0
		set_active_state(State.GROUND_POUNDING, false)

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and (
		is_on_floor() or jump_counter <= 1
	):
		velocity.y = JUMP_VELOCITY
		jump_counter += 1

	# Ground Pound
	if Input.is_action_just_pressed("ctrl_left") and not is_on_floor():
		velocity.y -= JUMP_VELOCITY * 3
		dash_timer = dash_time
		dash_rect.set_visible(true)
		set_active_state(State.GROUND_POUNDING)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector(
		"ui_left", 
		"ui_right", 
		"ui_up", 
		"ui_down"
	)
	var direction = (
		transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	).normalized()

	# Dash Handling (speedup)
	var speed_mult = 1
	if Input.is_action_just_pressed("shift_left"):
		speed_mult = 10
		dash_timer = dash_time
		dash_rect.set_visible(true)
		set_active_state(State.DASHING)
		if direction == Vector3.ZERO:
			var aim = camera.get_global_transform().basis
			direction = -aim.z * dash_speed
	if direction != Vector3.ZERO:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
 
	# Dashing Logic
	if has_active_state(State.DASHING):
		velocity.x += lerp(
			velocity.x * dash_speed, 
			last_velocity.x, 
			dash_acceleration * delta
		)
		velocity.z += lerp(
			velocity.z * dash_speed, 
			last_velocity.z, 
			dash_acceleration * delta
		)

	last_velocity = velocity
	last_direction = direction
	last_camera_aim = aim

	move_and_slide()
	process_ticks(delta)
	
	# Debug
	var labelstate = _state_to_label()
	$Camera3D/RichTextLabel.text = labelstate

func _input(event):
	if event is InputEventMouseMotion:
		var mouse_sensitivity = 0.01
		var camera = $Camera3D
		if camera:
			var rx = deg_to_rad(-event.relative.y * CAMERA_SENSITIVITY)
			camera.rotate_x(rx)
			var ry = deg_to_rad(-event.relative.x * CAMERA_SENSITIVITY)
			self.rotate_y(ry)

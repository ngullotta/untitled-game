extends CharacterBody3D

enum State {
    IDLE = 0x1,
    JUMPING = 0x2,
    DASHING = 0x4,
    GROUND_POUNDING = 0x8,
    SHIELDING = 0x10,
    SLIDING = 0x20
}

# State tracking
@export var state = 0
var last_velocity = Vector3.ZERO
var last_direction = Vector3.ZERO
var last_camera_aim = Vector3.ZERO

@onready var camera = $Camera3D
@onready var dash_rect = $Camera3D/ColorRect
@onready var shield = $Shield
var shield_default_pos = Vector3.ZERO
var shield_default_rot = Vector3.ZERO
var shield_target_pos = Vector3.ZERO
var shield_target_rota = Vector3.ZERO

const SPEED = 15.0
const JUMP_VELOCITY = 7.0
const DASH_FORCE = 200
const SHIELD_FORCE = 20
const SLIDE_FORCE = 2

# Camera Stuff
@export var CAMERA_SENSITIVITY = 0.1

# Jump Stuff
@export var jump_counter = 0

# Dash stuff
@export var dash_acceleration = 9
@export var dash_speed = 1
@export var dash_counter = 0
var dash_target = Vector3.ZERO

# Slide stuff
var slide_target = Vector3.ZERO

# Timers
# ======== DASH
var dash_timer = 0
var dash_time = 0.45

# ======== SLIDE
var slide_timer = 0
var slide_time = 1.5

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
        labels.append("Idle")
    if has_active_state(State.DASHING):
        labels.append("Dashing")
    if has_active_state(State.GROUND_POUNDING):
        labels.append("Ground Pounding")
    if has_active_state(State.JUMPING):
        labels.append("Jumping")
    if has_active_state(State.SHIELDING):
        labels.append("Shielding")
    if has_active_state(State.SLIDING):
        labels.append("Sliding")
    return " | ".join(labels)

func process_ticks(delta):
    dash_timer -= delta
    slide_timer -= delta
    if dash_timer < 0 and has_active_state(State.DASHING):
        dash_rect.set_visible(false)
        dash_timer = 0
        set_active_state(State.DASHING, false)
        
    if slide_timer < 0 and has_active_state(State.SLIDING):
        dash_rect.set_visible(false)
        slide_timer = 0
        set_active_state(State.SLIDING, false)
        

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    set_process_input(true)
    dash_rect.set_visible(false)
    shield_default_pos = shield.position
    shield_default_rot = shield.rotation

func _physics_process(delta):
    # Add the gravity.
    if not is_on_floor():
        velocity.y -= gravity * delta

    # Reset double-jump
    if is_on_floor():
        jump_counter = 0
        set_active_state(State.GROUND_POUNDING, false)
        dash_counter = 0
        # Just add any states here where dash_rect is not used on a timer
        if  not has_active_state(State.GROUND_POUNDING):
            dash_rect.set_visible(false)

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
    elif Input.is_action_just_pressed("ctrl_left") and is_on_floor():
        # handle slide
        slide_timer = slide_time
        dash_rect.set_visible(true)
        set_active_state(State.SLIDING, true)
        # Set slide target
        var aim = camera.get_camera_transform()
        slide_target = -aim.basis.z * 15

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
    
    if Input.is_action_just_released("shift_left") or Input.is_action_just_released("mouse_rclick"):
        set_active_state(State.SHIELDING, false)

    # Dash Handling (speedup)
    var speed_mult = 1
    if Input.is_action_just_pressed("shift_left"):
        set_active_state(State.SHIELDING, true)
        shield_target_pos = camera.position
        shield_target_pos.z -= 0.5 # put it a little in front
        shield_target_pos.y -= 1.10 # put it a little down
        shield_target_rota = shield_default_rot
        shield_target_rota.y = deg_to_rad(90)
        if dash_counter == 0:
            speed_mult = 10
            dash_timer = dash_time
            dash_rect.set_visible(true)
            set_active_state(State.DASHING)
            var aim = camera.get_camera_transform()
            if direction == Vector3.ZERO:
                dash_target = -aim.basis.z * 50
                
                
    if Input.is_action_just_pressed("mouse_rclick"):
        set_active_state(State.SHIELDING, true)
        shield_target_pos = camera.position
        shield_target_pos.z -= 0.5 # put it a little in front
        shield_target_pos.y -= 1.10 # put it a little down
        shield_target_rota = shield_default_rot
        shield_target_rota.y = deg_to_rad(90)
    
    if has_active_state(State.SHIELDING):
        shield.position = lerp(
            shield.position, 
            shield_target_pos, 
            SHIELD_FORCE * delta
        )
        shield.rotation = lerp(
            shield.rotation,
            shield_target_rota,
            SHIELD_FORCE * delta
        )
    else:
        shield.position = lerp(
            shield.position, 
            shield_default_pos, 
            (SHIELD_FORCE * 0.25) * delta
        )
        shield.rotation = lerp(
            shield.rotation,
            shield_default_rot,
            (SHIELD_FORCE * 0.25) * delta
        )

    if direction != Vector3.ZERO:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
        set_active_state(State.SLIDING, false)
    else:
        # Idle -> Dash
        if has_active_state(State.DASHING):
            velocity = lerp(
                last_velocity, 
                dash_target * dash_speed, 
                dash_acceleration * delta
            )
        # Idle -> Slide
        elif has_active_state(State.SLIDING):
            velocity = lerp(
                last_velocity, 
                slide_target * SLIDE_FORCE, 
                dash_acceleration * delta
            )
        else:
            velocity.x = move_toward(velocity.x, 0, SPEED)
            velocity.z = move_toward(velocity.z, 0, SPEED)
 
    # Dashing Logic
    if has_active_state(State.DASHING) and direction != Vector3.ZERO:
        velocity.x += lerp(
            velocity.x, 
            last_velocity.x * dash_speed, 
            dash_acceleration * delta
        )
        velocity.z += lerp(
            velocity.z, 
            last_velocity.z * dash_speed, 
            dash_acceleration * delta
        )
        
    last_velocity = velocity
    last_direction = direction
    move_and_slide()
    process_ticks(delta)
    
    if velocity == Vector3.ZERO and state == 0:
        set_active_state(State.IDLE)
    elif velocity != Vector3.ZERO and state > 0:
        set_active_state(State.IDLE, false)
    
    # Debug
    var labelstate = _state_to_label()
    $Camera3D/RichTextLabel.text = "[center]%s[/center]" % labelstate

func _input(event):
    if event is InputEventMouseMotion:
        var mouse_sensitivity = 0.01
        var camera = $Camera3D
        if camera:
            var rx = deg_to_rad(-event.relative.y * CAMERA_SENSITIVITY)
            camera.rotate_x(rx)
            var ry = deg_to_rad(-event.relative.x * CAMERA_SENSITIVITY)
            self.rotate_y(ry)

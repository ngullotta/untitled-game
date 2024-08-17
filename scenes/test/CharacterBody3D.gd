extends CharacterBody3D

enum State {
    IDLE = 0x1,
    JUMPING = 0x2,
    DASHING = 0x4,
    GROUND_POUNDING = 0x8,
    SHIELDING = 0x10,
    SLIDING = 0x20
}

# References
@onready var camera = $Camera3D
@onready var dash_rect = $Camera3D/ColorRect
@onready var shield = $Shield

# State
@export var state = 0
var last_velocity = Vector3.ZERO
var last_direction = Vector3.ZERO
var last_camera_rota = Vector3.ZERO

# Defaults
var player_default_rota = Vector3.ZERO
var shield_default_pos = Vector3.ZERO
var shield_default_rota = Vector3.ZERO

# Shield stuff
const SHIELD_FORCE = 20
var shield_target_pos = Vector3.ZERO
var shield_target_rota = Vector3.ZERO

# Camera Stuff
@export var CAMERA_SENSITIVITY = 0.1

# Jump Stuff
@export var JUMP_VELOCITY = 7
var jump_counter = 0

# Physics Stuff
const SPEED = 15.0

# Dash stuff
@export var dash_acceleration = 9
@export var DASH_FORCE = 200
var dash_speed = 1
var dash_counter = 0
var dash_target = Vector3.ZERO

# Slide stuff
@export var SLIDE_FORCE = 2
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

var timers = {}

func set_active_state(value, yn := true):
    if yn:
        state |= value
    else:
        state &= ~value

func remove_active_state(value):
    set_active_state(value, false)

func has_active_state(value):
    return bool(state & value)
    
func end_timer(label):
    if timers.has(label):
        timers[label].end.call()

func add_timer(
    label,
    start_value,
    end_value := 0,
    delta := 0,
    state := 0,
    callbacks := []
):
    # Add a timer to `timers`
    # every time `process_timers` is called, the `current_value` will be
    # decremented by `delta` until the `current_value` is < `end_value`
    # after this happens a callback can be triggered.
    #
    # If no value provided for delta, whatever is passed to `process_ticks`
    # will be used. If `state` is provided, `state` will be set to active,
    # and then removed once the `current_value` is < `end_value`
    timers[label] = {
        "current_value": start_value,
        "end_value": end_value,
        "delta": delta,
        "state": state,
        "callbacks": callbacks
    }
    timers[label].end = func(): timers[label]["current_value"] = -INF

func cleanup_timers():
    for timer in timers:
        var data = timers[timer]
        if data["current_value"] < data["end_value"]:
            timers.erase(timer)

func process_timers(delta):
    for timer in timers:
        var data = timers[timer]
        if not has_active_state(data["state"]):
            set_active_state(data["state"])
        data["current_value"] = data["current_value"] - delta
        if data["current_value"] < data["end_value"]:
            for callback in data["callbacks"]:
                callback.call()
            remove_active_state(data["state"])

    #if slide_timer < 0 and has_active_state(State.SLIDING):
        #rotation = player_default_rota
        #dash_rect.set_visible(false)
        #slide_timer = 0
        #set_active_state(State.SLIDING, false)
        #camera.rotation.x += deg_to_rad(90)
        
func raise_shield():
    shield_target_pos = camera.position
    shield_target_pos.z -= 0.5 # put it a little in front
    shield_target_pos.y -= 1.10 # put it a little down
    shield_target_rota = shield_default_rota
    shield_target_rota.y = deg_to_rad(90)
    set_active_state(State.SHIELDING)

func do_dash(direction := Vector3.ZERO):
    raise_shield()
    var aim = camera.get_camera_transform()
    if direction == Vector3.ZERO:
        dash_target = -aim.basis.z * 50
    add_timer(
        "dash",
        dash_time,
        0,
        0,
        State.DASHING,
        [
            func(): dash_rect.set_visible(false), 
            # Because we raise the shield during the dash too, we need
            # to ensure we lower it once finished
            func(): remove_active_state(State.SHIELDING)
        ]
    )
    dash_rect.set_visible(true)    

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

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    set_process_input(true)
    dash_rect.set_visible(false)
    player_default_rota = rotation
    shield_default_pos = shield.position
    shield_default_rota = shield.rotation

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
        #if  not has_active_state(State.GROUND_POUNDING):
            #dash_rect.set_visible(false)d

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

    # Dash Handling (speedup)
    if Input.is_action_just_pressed("shift_left"):
        do_dash(direction)

    if Input.is_action_just_pressed("mouse_rclick"):
        raise_shield()
    elif Input.is_action_just_released("mouse_rclick"):
        remove_active_state(State.SHIELDING)

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
            shield_default_rota,
            (SHIELD_FORCE * 0.25) * delta
        )

    if direction != Vector3.ZERO:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
        slide_timer = -1
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
            #camera.rotation.x = lerp(
                #last_camera_rota.x,
                #deg_to_rad(-82),
                #5 * delta
            #)
            rotation.x = deg_to_rad(82)
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
    last_camera_rota = camera.rotation
    move_and_slide()
    process_timers(delta)
    cleanup_timers()

    if velocity == Vector3.ZERO and state == 0:
        set_active_state(State.IDLE)
    elif velocity != Vector3.ZERO and state > 0:
        set_active_state(State.IDLE, false)
        
    if abs(velocity.x) > 25 or abs(velocity.y) > 10 or abs(velocity.z) > 25:
        dash_rect.set_visible(true)
    else:
        dash_rect.set_visible(false)        

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

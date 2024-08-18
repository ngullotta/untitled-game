extends CharacterBody3D

enum State {
    IDLE = 0x1,
    JUMPING = 0x2,
    DASHING = 0x4,
    GROUND_POUNDING = 0x8,
    SHIELDING = 0x10,
    SLIDING = 0x20,
    MOVEMENT_LOCK = 0x40
}

@onready var camera = $Camera

# State
@export var state = 0
var last_velocity = Vector3.ZERO
var last_direction = Vector3.ZERO
var last_camera_rota = Vector3.ZERO

# Defaults
var player_default_rota = Vector3.ZERO
var shield_default_pos = Vector3.ZERO
var shield_default_rota = Vector3.ZERO

# Jump Stuff
@export var JUMP_VELOCITY = 7
var jump_counter = 0

# Physics Stuff
const SPEED = 15.0

# Dash stuff
@export var dash_acceleration = 9
var dash_time = 0.45
var DASH_SPEED = 50
var dash_counter = 0
var dash_target = Vector3.ZERO

# Slide stuff
@export var SLIDE_FORCE = 2
var slide_time = 1.5
var slide_target = Vector3.ZERO

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

func raise_shield():
    set_active_state(State.SHIELDING)

func do_dash(direction := Vector3.ZERO):
    # Shield is up for this
    raise_shield()
    
    var ddd = -global_transform.basis.z
    var fff = -direction
    if direction:
        velocity = direction * DASH_SPEED
    else:
        velocity = -global_transform.basis.z * DASH_SPEED
    # FIXME -> Why can't I do State.DASHING | State.MOVEMENT_LOCK
    set_active_state(State.MOVEMENT_LOCK)
    add_timer(
        "dash",
        dash_time,
        0,
        0,
        State.DASHING,
        [
            # Because we raise the shield during the dash too, we need
            # to ensure we lower it once finished
            func(): remove_active_state(State.SHIELDING),
            func(): remove_active_state(State.MOVEMENT_LOCK)
        ]
    )

func do_slide():
    raise_shield()
    add_timer(
        "slide",
        slide_time,
        0,
        0,
        State.SLIDING,
        [
            # Because we raise the shield during the dash too, we need
            # to ensure we lower it once finished
            func(): remove_active_state(State.SHIELDING),
            func(): rotation = player_default_rota
        ]
    )
    var aim = -global_transform.basis.z

    slide_target = -aim.basis.z * 15

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    set_process_input(true)
    player_default_rota = rotation

func handle_input():
    var input_dir = Input.get_vector(
        "ui_left",
        "ui_right",
        "ui_up",
        "ui_down"
    )
    var direction = (
        transform.basis * Vector3(input_dir.x, 0, input_dir.y)
    ).normalized()

    # Inputs that actually perform an action
    # Jump
    if Input.is_action_just_pressed("ui_accept") and (
        is_on_floor() or jump_counter <= 1
    ):
        velocity.y = JUMP_VELOCITY
        jump_counter += 1
    # Ground pound
    elif Input.is_action_just_pressed("ctrl_left") and not is_on_floor():
        velocity.y -= JUMP_VELOCITY * 3
        set_active_state(State.GROUND_POUNDING)
    # Slide
    elif Input.is_action_just_pressed("ctrl_left") and is_on_floor():
        do_slide()
    # Dash
    elif Input.is_action_just_pressed("shift_left"):
        do_dash(direction)
    # Shield Up
    if Input.is_action_just_pressed("mouse_rclick"):
        raise_shield()
    # Shield Down
    elif Input.is_action_just_released("mouse_rclick"):
        remove_active_state(State.SHIELDING)

    return direction

func _physics_process(delta):
    # Add the gravity.
    if not is_on_floor():
        velocity.y -= gravity * delta

    # Reset double-jump
    if is_on_floor():
        jump_counter = 0
        remove_active_state(State.GROUND_POUNDING)

    # Handle all inputs and get a vector for direction
    var direction = handle_input()

    if direction != Vector3.ZERO and not has_active_state(State.MOVEMENT_LOCK):
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
    elif not has_active_state(State.MOVEMENT_LOCK):
        velocity.x = move_toward(velocity.x, 0, SPEED)
        velocity.z = move_toward(velocity.z, 0, SPEED)

    last_velocity = velocity
    last_direction = direction

    move_and_slide()
    process_timers(delta)
    cleanup_timers()

    if velocity == Vector3.ZERO and state == 0:
        set_active_state(State.IDLE)
    elif velocity != Vector3.ZERO and state > 0:
        set_active_state(State.IDLE, false)

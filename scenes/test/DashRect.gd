extends ColorRect

@onready var player = get_parent().get_parent()

# Called when the node enters the scene tree for the first time.
func _ready():
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    if abs(player.velocity.x) > 25 or abs(player.velocity.y) > 10 or abs(player.velocity.z) > 25:
        set_visible(true)
    else:
        set_visible(false)

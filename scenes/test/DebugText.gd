extends RichTextLabel

@onready var player = get_parent().get_parent()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _state_to_label():
	var labels = []
	if player.has_active_state(player.State.IDLE):
		labels.append("Idle")
	if player.has_active_state(player.State.DASHING):
		labels.append("Dashing")
	if player.has_active_state(player.State.GROUND_POUNDING):
		labels.append("Ground Pounding")
	if player.has_active_state(player.State.JUMPING):
		labels.append("Jumping")
	if player.has_active_state(player.State.SHIELDING):
		labels.append("Shielding")
	if player.has_active_state(player.State.SLIDING):
		labels.append("Sliding")
	return " | ".join(labels)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var labelstate = _state_to_label()
	text = "[center]%s[/center]" % labelstate

extends CharacterBody2D
@export var speed: float = 90.0
var player: Node2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	velocity = global_position.direction_to(
		player.global_position) * speed
	move_and_slide()
	for body in $ContactArea.get_overlapping_bodies():
		if body.is_in_group("player"):
			body.take_damage(1)
			
func take_hit() -> void:
	queue_free()

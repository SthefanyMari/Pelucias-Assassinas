extends Node2D
signal escaped
var unlocked := false

func _ready() -> void:
	$Trigger.body_entered.connect(_on_body_entered)

func unlock() -> void:
	unlocked = true
	$Blocker/CollisionShape2D.set_deferred("disabled", true)
	$Visual/Sprite2D.texture = preload("res://Kit_Ultima_Volta/sprites/props/exit_open.png")
	for body in $Trigger.get_overlapping_bodies():
		_on_body_entered(body)
		
func _on_body_entered(body: Node2D) -> void:
	if unlocked and body.is_in_group("player"):
		escaped.emit()

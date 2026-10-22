extends CharacterBody2D
@export var speed: float = 180.0

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
 		"move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
signal health_changed(value: int)
signal died
var health: int = 3
@onready var damage_cooldown: Timer = $DamageCooldown

func take_damage(amount: int) -> void:
	if health <= 0 or not damage_cooldown.is_stopped():
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health)
	if health == 0:
		died.emit()
	else:
		damage_cooldown.start()

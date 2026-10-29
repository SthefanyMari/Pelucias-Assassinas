extends CharacterBody2D

signal health_changed(value: int)
signal died

enum State {
	IDLE,
	WALK,
	ATTACK,
	HURT,
	DEAD
}

@export var speed: float = 180.0

var health: int = 3
var state: State = State.IDLE
var facing: String = "down"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var damage_cooldown: Timer = $DamageCooldown


func _ready() -> void:
	if not sprite.animation_finished.is_connected(
		_on_animation_finished
	):
		sprite.animation_finished.connect(_on_animation_finished)

	sprite.flip_h = false
	sprite.flip_v = false
	_play_state_animation()


func _physics_process(_delta: float) -> void:
	match state:
		State.IDLE, State.WALK:
			_update_movement()

		State.ATTACK, State.HURT:
			velocity = Vector2.ZERO

		State.DEAD:
			velocity = Vector2.ZERO
			return

	move_and_slide()


func _update_movement() -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	if direction != Vector2.ZERO:
		_update_facing(direction)

	if Input.is_action_just_pressed("attack"):
		if attack_cooldown.is_stopped():
			attack()
			return

	velocity = direction * speed

	if direction == Vector2.ZERO:
		_change_state(State.IDLE)
	else:
		_change_state(State.WALK)

	_play_state_animation()


func _update_facing(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		facing = "right" if direction.x > 0.0 else "left"
	else:
		facing = "down" if direction.y > 0.0 else "up"


func _change_state(next_state: State) -> void:
	if state == next_state:
		return

	state = next_state

	if state != State.WALK:
		velocity = Vector2.ZERO

	_play_state_animation()


func _play_state_animation() -> void:
	var animation_name: String = ""

	match state:
		State.IDLE:
			animation_name = "idle_" + facing

		State.WALK:
			animation_name = "walk_" + facing

		State.ATTACK:
			animation_name = "attack_" + facing

		State.HURT:
			animation_name = "hurt_" + facing

		State.DEAD:
			animation_name = "death_" + facing

	sprite.play(animation_name)


func attack() -> void:
	if health <= 0:
		return

	if state != State.IDLE and state != State.WALK:
		return

	if not attack_cooldown.is_stopped():
		return

	attack_cooldown.start()
	_change_state(State.ATTACK)

	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			if body.has_method("take_hit"):
				body.take_hit()


func take_damage(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return

	if not damage_cooldown.is_stopped():
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health)

	if health == 0:
		_change_state(State.DEAD)
		died.emit()
	else:
		damage_cooldown.start()
		_change_state(State.HURT)


func _on_animation_finished() -> void:
	if state == State.ATTACK or state == State.HURT:
		_change_state(State.IDLE)

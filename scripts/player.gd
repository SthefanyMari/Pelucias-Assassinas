extends CharacterBody2D

signal health_changed(value: int)
signal died

enum State { IDLE, WALK, ATTACK, HURT, DEAD }

const PROJECTILE_SCRIPT = preload("res://scripts/projectile.gd")
const WEAPON_NAMES := ["Lanterna", "Canhão de Berros", "Chuva de Chumbo"]
const POWER_NAMES := ["Rodinhas de Proteção", "Pane no Sistema", "Devolução de Pelúcias"]
const POWER_RECHARGE := [10.0, 15.0, 10.0]
const ATTACK_INTERVAL := [0.6, 0.5, 0.65]

@export var speed: float = 180.0

var health: int = 3
var state: State = State.IDLE
var facing: String = "down"
var difficulty: int = 1
var power_cooldown_remaining := 0.0
var shield_remaining := 0.0
var pulse_remaining := 0.0
var pulse_radius := 0.0
var pulse_color := Color.WHITE
var cone_remaining := 0.0
var cone_angle := 0.0
var cone_radius := 140.0
var cone_half_angle := 75.0
var cone_color := Color.CYAN
var combat_active := true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var damage_cooldown: Timer = $DamageCooldown


func _ready() -> void:
	difficulty = clampi(GameSession.difficulty, 0, 2)
	attack_cooldown.wait_time = float(ATTACK_INTERVAL[difficulty])
	attack_cooldown.one_shot = true
	damage_cooldown.one_shot = true

	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	sprite.flip_h = false
	sprite.flip_v = false
	_play_state_animation()


func _physics_process(delta: float) -> void:
	if not combat_active:
		return

	power_cooldown_remaining = maxf(power_cooldown_remaining - delta, 0.0)
	shield_remaining = maxf(shield_remaining - delta, 0.0)
	pulse_remaining = maxf(pulse_remaining - delta, 0.0)
	cone_remaining = maxf(cone_remaining - delta, 0.0)
	queue_redraw()

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
		"move_left", "move_right", "move_up", "move_down"
	)

	if direction != Vector2.ZERO:
		_update_facing(direction)

	if Input.is_action_just_pressed("power"):
		use_power()

	if Input.is_action_just_pressed("attack"):
		if attack_cooldown.is_stopped():
			attack()
			return

	velocity = direction * speed
	_change_state(State.IDLE if direction == Vector2.ZERO else State.WALK)
	_play_state_animation()


func _update_facing(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		facing = "right" if direction.x > 0.0 else "left"
	else:
		facing = "down" if direction.y > 0.0 else "up"


func _facing_vector() -> Vector2:
	match facing:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"up":
			return Vector2.UP
	return Vector2.DOWN


func _change_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	if state != State.WALK:
		velocity = Vector2.ZERO
	_play_state_animation()


func _play_state_animation() -> void:
	var action := "idle"
	match state:
		State.WALK:
			action = "walk"
		State.ATTACK:
			action = "attack"
		State.HURT:
			action = "hurt"
		State.DEAD:
			action = "death"
	sprite.play(action + "_" + facing)


func attack() -> void:
	if not combat_active or health <= 0:
		return
	if state != State.IDLE and state != State.WALK:
		return
	if not attack_cooldown.is_stopped():
		return

	attack_cooldown.start()
	_change_state(State.ATTACK)

	match difficulty:
		0:
			_show_pulse(48.0, Color.YELLOW)
			for body in attack_area.get_overlapping_bodies():
				if body.is_in_group("enemies") and body.has_method("take_hit"):
					body.take_hit()
		1:
			_sonic_blast(140.0, 75.0, Color.CYAN)

		2:
			_sonic_blast(160.0, 90.0, Color.HOT_PINK)

func _sonic_blast(
	attack_range: float,
	half_angle: float,
	attack_color: Color
) -> void:
	var forward := _facing_vector()

	cone_angle = forward.angle()
	cone_radius = attack_range
	cone_half_angle = half_angle
	cone_color = attack_color
	cone_remaining = 0.3
	queue_redraw()

	var enemies := get_tree().get_nodes_in_group("enemies")
	var excluded: Array[RID] = [get_rid()]

	for enemy in enemies:
		if enemy is CollisionObject2D:
			excluded.append(enemy.get_rid())

	for enemy in enemies:
		if not enemy is Node2D:
			continue

		if not enemy.has_method("take_hit"):
			continue

		var offset: Vector2 = enemy.global_position - global_position

		if offset.length() > attack_range:
			continue

		if offset.length_squared() > 0.001:
			if forward.dot(offset.normalized()) < cos(deg_to_rad(half_angle)):
				continue

		var query := PhysicsRayQueryParameters2D.create(
			global_position,
			enemy.global_position,
			1,
			excluded
		)

		var obstacle := get_world_2d().direct_space_state.intersect_ray(query)

		if obstacle.is_empty():
			enemy.take_hit()


func _fire_projectile(direction: Vector2, color: Color) -> void:
	var projectile = PROJECTILE_SCRIPT.new()
	projectile.configure(direction, color)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.add_collision_exception_with(self)

func use_power() -> void:
	if not combat_active or health <= 0:
		return
	if state != State.IDLE and state != State.WALK:
		return
	if power_cooldown_remaining > 0.0:
		return

	power_cooldown_remaining = float(POWER_RECHARGE[difficulty])
	match difficulty:
		0:
			shield_remaining = 3.0
			_show_pulse(28.0, Color.GOLD)
		1:
			_show_pulse(100.0, Color.CYAN)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.has_method("freeze"):
					enemy.freeze(2.0)
		2:
			_show_pulse(150.0, Color.HOT_PINK)
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy is Node2D and enemy.has_method("take_hit"):
					if global_position.distance_to(enemy.global_position) <= 150.0:
						enemy.take_hit()


func take_damage(amount: int) -> void:
	if not combat_active or health <= 0 or amount <= 0:
		return
	if shield_remaining > 0.0 or not damage_cooldown.is_stopped():
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
	if not combat_active:
		return
	if state == State.ATTACK or state == State.HURT:
		_change_state(State.IDLE)


func stop_combat() -> void:
	combat_active = false
	velocity = Vector2.ZERO
	if state != State.DEAD:
		_change_state(State.IDLE)


func get_weapon_name() -> String:
	return str(WEAPON_NAMES[difficulty])


func get_power_name() -> String:
	return str(POWER_NAMES[difficulty])


func _show_pulse(radius: float, color: Color) -> void:
	pulse_radius = radius
	pulse_color = color
	pulse_remaining = 0.25
	queue_redraw()


func _draw() -> void:
	if shield_remaining > 0.0:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 40, Color.GOLD, 3.0)
	if pulse_remaining > 0.0:
		var color := pulse_color
		color.a = pulse_remaining / 0.25
		draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 64, color, 3.0)

	if cone_remaining > 0.0:
		var color := cone_color
		color.a = cone_remaining / 0.3

		var start := cone_angle - deg_to_rad(cone_half_angle)
		var end := cone_angle + deg_to_rad(cone_half_angle)

		draw_arc(
			Vector2.ZERO,
			cone_radius,
			start,
			end,
			64,
			color,
			5.0
		)

		draw_line(
			Vector2.ZERO,
			Vector2.RIGHT.rotated(start) * cone_radius,
			color,
			2.0
		)

		draw_line(
			Vector2.ZERO,
			Vector2.RIGHT.rotated(end) * cone_radius,
			color,
			2.0
		)

extends CharacterBody2D

enum State { CHASE, WINDUP, ATTACK, RECOVER }

@export var speed: float = 90.0

var state: State = State.CHASE
var clock := 0.0
var nav_ready := false
var facing := "down"
var frozen_remaining := 0.0
var combat_active := true
var dying := false
var player: Node2D

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	$PathTimer.timeout.connect(update_target)
	play_animation("idle")
	var tree := get_tree()

	while is_inside_tree():
		await tree.physics_frame
		if not is_inside_tree() or not combat_active or dying:
			return
		var navigation_map: RID = agent.get_navigation_map()
		if not navigation_map.is_valid():
			continue
		if NavigationServer2D.map_get_iteration_id(navigation_map) == 0:
			continue
		nav_ready = true
		update_target()
		$PathTimer.start()
		return


func update_target() -> void:
	if combat_active and not dying and nav_ready and is_instance_valid(player):
		agent.target_position = player.global_position


func update_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	if abs(direction.x) > abs(direction.y):
		facing = "right" if direction.x > 0.0 else "left"
	else:
		facing = "down" if direction.y > 0.0 else "up"


func play_animation(action: String) -> void:
	sprite.flip_h = false
	sprite.flip_v = false
	sprite.play(action + "_" + facing)


func change_state(next_state: State) -> void:
	state = next_state
	clock = 0.0
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	match state:
		State.CHASE:
			update_target()
			play_animation("idle")
		State.WINDUP:
			sprite.modulate = Color.RED
			play_animation("idle")
		State.ATTACK:
			play_animation("attack")
		State.RECOVER:
			play_animation("idle")


func _physics_process(delta: float) -> void:
	if not combat_active or dying:
		return

	if frozen_remaining > 0.0:
		frozen_remaining = maxf(frozen_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		if frozen_remaining == 0.0:
			sprite.modulate = Color.RED if state == State.WINDUP else Color.WHITE
			sprite.play()
			update_target()
		return

	if not nav_ready or not is_instance_valid(player):
		return

	clock += delta
	velocity = Vector2.ZERO
	match state:
		State.CHASE:
			if global_position.distance_to(player.global_position) < 36.0:
				update_facing(global_position.direction_to(player.global_position))
				change_state(State.WINDUP)
			elif not agent.is_navigation_finished():
				var point := agent.get_next_path_position()
				var direction := global_position.direction_to(point)
				velocity = direction * speed
				update_facing(direction)
				play_animation("walk")
			else:
				play_animation("idle")
		State.WINDUP:
			if clock >= 0.35:
				change_state(State.ATTACK)
		State.ATTACK:
			if global_position.distance_to(player.global_position) <= 40.0:
				if player.has_method("take_damage"):
					player.take_damage(1)

			if clock >= 0.2:
				change_state(State.RECOVER)
		State.RECOVER:
			if clock >= 0.6:
				change_state(State.CHASE)
	move_and_slide()


func freeze(seconds: float) -> void:
	if not combat_active or dying:
		return
	frozen_remaining = maxf(frozen_remaining, seconds)
	velocity = Vector2.ZERO
	sprite.modulate = Color.CYAN
	sprite.pause()


func take_hit() -> void:
	if not combat_active or dying:
		return
	dying = true
	velocity = Vector2.ZERO
	$PathTimer.stop()
	queue_free()


func stop_combat() -> void:
	combat_active = false
	velocity = Vector2.ZERO
	$PathTimer.stop()
	sprite.pause()
	set_physics_process(false)

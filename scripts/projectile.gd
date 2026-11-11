extends CharacterBody2D

var direction := Vector2.RIGHT
var travel_speed := 420.0
var lifetime := 1.4
var distance_remaining := 180.0
var tint := Color.YELLOW
var combat_active := true


func configure(new_direction: Vector2, new_color: Color) -> void:
	direction = new_direction.normalized()
	tint = new_color


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 5
	add_to_group("combat_projectiles")
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	shape_node.shape = shape
	add_child(shape_node)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not combat_active:
		return

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	var step := minf(travel_speed * delta, distance_remaining)
	var collision := move_and_collide(direction * step)
	distance_remaining -= step
	if collision != null:
		var body := collision.get_collider()
		if is_instance_valid(body):
			if body.is_in_group("enemies") and body.has_method("take_hit"):
				if body is PhysicsBody2D:
					add_collision_exception_with(body)
				body.take_hit()
				return
		queue_free()
	if distance_remaining <= 0.0:
		queue_free()


func stop_combat() -> void:
	combat_active = false
	set_physics_process(false)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, tint)
	draw_line(-direction * 9.0, Vector2.ZERO, tint.darkened(0.25), 3.0)

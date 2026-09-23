class_name Enemy
extends Node2D

signal died(reward: int)
signal escaped(damage: int)

var path: PackedVector2Array
var path_index := 1
var kind := "normal"
var speed := 70.0
var max_hp := 40.0
var hp := 40.0
var reward := 5
var damage := 1
var radius := 12.0
var color := Color.RED
var traveled := 0.0
var slow_factor := 1.0
var slow_time := 0.0
var hit_flash := 0.0
var dead := false


func setup(p_path: PackedVector2Array, p_kind: String, stats: Dictionary, hp_scale: float) -> void:
	path = p_path
	position = path[0]
	kind = p_kind
	speed = stats["speed"]
	max_hp = stats["hp"] * hp_scale
	hp = max_hp
	reward = stats["reward"]
	damage = stats["damage"]
	radius = stats["radius"]
	color = stats["color"]


func _process(delta: float) -> void:
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_factor = 1.0
	hit_flash = maxf(0.0, hit_flash - delta)

	var move := speed * slow_factor * delta
	while move > 0.0 and path_index < path.size():
		var target := path[path_index]
		var dist := position.distance_to(target)
		if dist <= move:
			position = target
			move -= dist
			traveled += dist
			path_index += 1
		else:
			position += (target - position).normalized() * move
			traveled += move
			move = 0.0

	if path_index >= path.size():
		dead = true
		escaped.emit(damage)
		queue_free()
		return
	queue_redraw()


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	hit_flash = 0.08
	if hp <= 0.0:
		dead = true
		died.emit(reward)
		queue_free()


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, factor)
	slow_time = maxf(slow_time, duration)


func _draw() -> void:
	var body := color
	if slow_factor < 1.0:
		body = body.lerp(Color(0.5, 0.85, 1.0), 0.5)
	if hit_flash > 0.0:
		body = Color.WHITE

	draw_circle(Vector2(0, 4), radius, Color(0, 0, 0, 0.3))
	match kind:
		"fast":
			var pts := PackedVector2Array([
				Vector2(0, -radius * 1.2), Vector2(radius, 0),
				Vector2(0, radius * 1.2), Vector2(-radius, 0),
			])
			draw_colored_polygon(pts, body)
		"tank":
			draw_rect(Rect2(-radius, -radius, radius * 2, radius * 2), body)
			draw_rect(Rect2(-radius, -radius, radius * 2, radius * 2), body.darkened(0.5), false, 2.0)
		_:
			draw_circle(Vector2.ZERO, radius, body)
			draw_arc(Vector2.ZERO, radius, 0, TAU, 24, body.darkened(0.5), 2.0)
	if kind == "boss":
		draw_arc(Vector2.ZERO, radius + 4, 0, TAU, 32, Color(1, 0.8, 0.2), 3.0)

	# 血條
	var w := radius * 2.2
	var y := -radius - 10
	draw_rect(Rect2(-w / 2, y, w, 4), Color(0.1, 0.1, 0.1))
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w / 2, y, w * ratio, 4), Color(1 - ratio, ratio, 0.2))

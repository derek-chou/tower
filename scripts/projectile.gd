class_name Projectile
extends Node2D

var target: Enemy
var target_pos: Vector2
var speed := 600.0
var damage := 10.0
var splash := 0.0
var slow := 0.0
var color := Color.WHITE
var enemies_root: Node
var effects_root: Node


func _process(delta: float) -> void:
	if is_instance_valid(target) and not target.dead:
		target_pos = target.position
	var to := target_pos - position
	var step := speed * delta
	if to.length() <= step:
		position = target_pos
		_hit()
		return
	position += to.normalized() * step
	rotation = to.angle()


func _hit() -> void:
	if splash > 0.0:
		for node in enemies_root.get_children():
			var e := node as Enemy
			if e and not e.dead and e.position.distance_to(position) <= splash:
				_affect(e)
		Effect.ring(effects_root, position, splash, color)
	elif is_instance_valid(target) and not target.dead:
		_affect(target)
	queue_free()


func _affect(e: Enemy) -> void:
	if slow > 0.0:
		e.apply_slow(slow, 1.6)
	e.take_damage(damage)


func _draw() -> void:
	if speed > 1000.0:
		draw_line(Vector2(-12, 0), Vector2(4, 0), color, 2.0)
	else:
		draw_circle(Vector2.ZERO, 4.0 if splash <= 0.0 else 6.0, color)
		draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

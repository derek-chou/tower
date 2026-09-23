class_name Tower
extends Node2D

const MAX_LEVEL := 3

var type_id := ""
var data: Dictionary
var cell := Vector2i.ZERO
var level := 1
var damage := 0.0
var attack_range := 0.0
var rate := 1.0
var splash := 0.0
var slow := 0.0
var spent := 0
var cooldown := 0.0
var aim_angle := -PI / 2
var flash := 0.0

var enemies_root: Node
var projectiles_root: Node
var effects_root: Node


func setup(p_type: String, p_data: Dictionary, p_cell: Vector2i,
		enemies: Node, projectiles: Node, effects: Node) -> void:
	type_id = p_type
	data = p_data
	cell = p_cell
	damage = data["damage"]
	attack_range = data["range"]
	rate = data["rate"]
	splash = data["splash"]
	slow = data["slow"]
	spent = data["cost"]
	enemies_root = enemies
	projectiles_root = projectiles
	effects_root = effects


func can_upgrade() -> bool:
	return level < MAX_LEVEL


func upgrade_cost() -> int:
	return int(data["cost"] * 0.8 * level)


func sell_value() -> int:
	return int(spent * 0.7)


func upgrade() -> void:
	spent += upgrade_cost()
	level += 1
	damage *= 1.6
	attack_range *= 1.12
	rate *= 0.85
	splash *= 1.1
	if slow > 0.0:
		slow = maxf(0.25, slow - 0.1)


func _process(delta: float) -> void:
	cooldown -= delta
	flash = maxf(0.0, flash - delta)
	var target := _find_target()
	if target:
		var want := (target.position - position).angle()
		aim_angle = lerp_angle(aim_angle, want, minf(1.0, 18.0 * delta))
		if cooldown <= 0.0:
			_fire(target)
			cooldown = rate
	queue_redraw()


## 鎖定射程內走最遠的敵人（最接近終點）。
func _find_target() -> Enemy:
	var best: Enemy = null
	for node in enemies_root.get_children():
		var e := node as Enemy
		if e == null or e.dead:
			continue
		if position.distance_to(e.position) > attack_range:
			continue
		if best == null or e.traveled > best.traveled:
			best = e
	return best


func _fire(target: Enemy) -> void:
	var p := Projectile.new()
	p.position = position + Vector2.from_angle(aim_angle) * 20.0
	p.target = target
	p.target_pos = target.position
	p.speed = data["speed"]
	p.damage = damage
	p.splash = splash
	p.slow = slow
	p.color = data["color"]
	p.enemies_root = enemies_root
	p.effects_root = effects_root
	projectiles_root.add_child(p)
	flash = 0.08


func _draw() -> void:
	var col: Color = data["color"]
	var dark := col.darkened(0.55)
	draw_rect(Rect2(-26, -26, 52, 52), Color(0.22, 0.22, 0.27))
	draw_rect(Rect2(-26, -26, 52, 52), Color(0.08, 0.08, 0.1), false, 2.0)
	draw_circle(Vector2.ZERO, 19, dark)
	draw_circle(Vector2.ZERO, 15, col)

	var dir := Vector2.from_angle(aim_angle)
	var side := dir.orthogonal()
	var muzzle := 24.0
	match type_id:
		"gun":
			draw_line(side * 4, side * 4 + dir * 24, dark, 4.0)
			draw_line(-side * 4, -side * 4 + dir * 24, dark, 4.0)
		"cannon":
			draw_line(Vector2.ZERO, dir * 22, dark, 11.0)
			muzzle = 22.0
		"frost":
			draw_colored_polygon(PackedVector2Array([
				dir * 20, side * 7, -dir * 8, -side * 7,
			]), Color(0.9, 1.0, 1.0))
			muzzle = 20.0
		"sniper":
			draw_line(Vector2.ZERO, dir * 32, dark, 3.0)
			muzzle = 32.0
	draw_circle(Vector2.ZERO, 6, col.lightened(0.35))

	if flash > 0.0:
		draw_circle(dir * muzzle, 5, Color(1, 1, 0.7, flash / 0.08))

	for i in level:
		draw_circle(Vector2(-12 + i * 12, 20), 3.5, Color(1, 0.85, 0.2))

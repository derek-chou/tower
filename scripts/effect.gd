class_name Effect
extends Node2D

## 短暫的視覺特效：爆炸圓環或飄浮文字。

var kind := "ring"
var color := Color.WHITE
var radius := 30.0
var text := ""
var life := 0.35
var t := 0.0


static func ring(parent: Node, pos: Vector2, r: float, col: Color) -> void:
	var e := Effect.new()
	e.position = pos
	e.radius = r
	e.color = col
	parent.add_child(e)


static func floating_text(parent: Node, pos: Vector2, msg: String, col: Color) -> void:
	var e := Effect.new()
	e.kind = "text"
	e.position = pos
	e.text = msg
	e.color = col
	e.life = 0.8
	parent.add_child(e)


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	if kind == "text":
		position.y -= 30.0 * delta
	queue_redraw()


func _draw() -> void:
	var k := t / life
	if kind == "ring":
		var r := radius * (0.3 + 0.7 * k)
		draw_circle(Vector2.ZERO, r, Color(color, 0.35 * (1.0 - k)))
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(color, 1.0 - k), 2.0)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-12, 0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(color, 1.0 - k))

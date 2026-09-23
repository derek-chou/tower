extends Node2D

const TILE := 64
const COLS := 16
const ROWS := 11
const PANEL_W := 256
const MAX_WAVE := 20
const START_GOLD := 150
const START_LIVES := 20

## 敵人行走路線（格子座標），頭尾位於地圖外。
const WAYPOINTS := [
	Vector2i(-1, 1), Vector2i(3, 1), Vector2i(3, 8), Vector2i(7, 8), Vector2i(7, 2),
	Vector2i(11, 2), Vector2i(11, 9), Vector2i(14, 9), Vector2i(14, 5), Vector2i(16, 5),
]

const TOWER_ORDER := ["gun", "cannon", "frost", "sniper"]
const TOWER_TYPES := {
	"gun": {
		"name": "機槍塔", "desc": "射速快、單體傷害", "cost": 50,
		"range": 140.0, "damage": 8.0, "rate": 0.35, "splash": 0.0, "slow": 0.0,
		"speed": 700.0, "color": Color(0.35, 0.65, 1.0),
	},
	"cannon": {
		"name": "加農砲", "desc": "範圍爆炸傷害", "cost": 100,
		"range": 125.0, "damage": 26.0, "rate": 1.3, "splash": 60.0, "slow": 0.0,
		"speed": 380.0, "color": Color(1.0, 0.55, 0.2),
	},
	"frost": {
		"name": "冰霜塔", "desc": "範圍緩速敵人", "cost": 80,
		"range": 115.0, "damage": 4.0, "rate": 0.8, "splash": 45.0, "slow": 0.5,
		"speed": 450.0, "color": Color(0.55, 0.95, 1.0),
	},
	"sniper": {
		"name": "狙擊塔", "desc": "超遠射程、高傷害", "cost": 150,
		"range": 300.0, "damage": 70.0, "rate": 1.8, "splash": 0.0, "slow": 0.0,
		"speed": 1600.0, "color": Color(0.7, 1.0, 0.4),
	},
}

const ENEMY_TYPES := {
	"normal": {"hp": 40.0, "speed": 70.0, "reward": 5, "damage": 1, "radius": 12.0, "color": Color(0.9, 0.3, 0.3)},
	"fast": {"hp": 24.0, "speed": 135.0, "reward": 6, "damage": 1, "radius": 10.0, "color": Color(1.0, 0.85, 0.25)},
	"tank": {"hp": 160.0, "speed": 45.0, "reward": 14, "damage": 2, "radius": 14.0, "color": Color(0.6, 0.35, 0.85)},
	"boss": {"hp": 900.0, "speed": 38.0, "reward": 80, "damage": 5, "radius": 22.0, "color": Color(0.7, 0.12, 0.2)},
}

var gold := START_GOLD
var lives := START_LIVES
var wave := 0
var wave_active := false
var spawn_queue: Array[String] = []
var spawn_timer := 0.0
var alive := 0
var game_over := false

var build_type := ""
var selected_tower: Tower = null
var hover_cell := Vector2i(-1, -1)
var path_cells := {}
var path_points := PackedVector2Array()
var towers := {}

var towers_root: Node2D
var enemies_root: Node2D
var projectiles_root: Node2D
var effects_root: Node2D
var overlay: Node2D

var stats_label: Label
var info_label: Label
var tower_buttons := {}
var upgrade_button: Button
var sell_button: Button
var wave_button: Button
var speed_button: Button
var end_panel: Control
var end_label: Label


func _ready() -> void:
	Engine.time_scale = 1.0
	_build_path()
	towers_root = _add_layer("Towers")
	enemies_root = _add_layer("Enemies")
	projectiles_root = _add_layer("Projectiles")
	effects_root = _add_layer("Effects")
	overlay = _add_layer("Overlay")
	overlay.draw.connect(_draw_overlay)
	_build_ui()
	_refresh_ui()


func _add_layer(layer_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = layer_name
	add_child(n)
	return n


# ---------------------------------------------------------------- 地圖

func _build_path() -> void:
	for i in WAYPOINTS.size():
		var wp: Vector2i = WAYPOINTS[i]
		path_points.append(cell_center(wp))
		if i == 0:
			continue
		var prev: Vector2i = WAYPOINTS[i - 1]
		var step := (wp - prev).sign()
		var c := prev
		while true:
			if in_grid(c):
				path_cells[c] = true
			if c == wp:
				break
			c += step


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) * 0.5


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


func can_build(c: Vector2i) -> bool:
	return in_grid(c) and not path_cells.has(c) and not towers.has(c)


func _draw() -> void:
	for x in COLS:
		for y in ROWS:
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			if path_cells.has(Vector2i(x, y)):
				draw_rect(r, Color(0.56, 0.45, 0.3))
			elif (x + y) % 2 == 0:
				draw_rect(r, Color(0.26, 0.5, 0.26))
			else:
				draw_rect(r, Color(0.23, 0.46, 0.23))
	draw_polyline(path_points, Color(0.63, 0.52, 0.36), 20.0)

	# 入口與基地
	var entry := cell_center(WAYPOINTS[1]) - Vector2(TILE * 3, 0)
	draw_rect(Rect2(entry - Vector2(32, 32), Vector2(64, 64)), Color(0.2, 0.2, 0.2, 0.35))
	var base := cell_center(Vector2i(COLS - 1, WAYPOINTS[-1].y))
	draw_rect(Rect2(base - Vector2(28, 28), Vector2(56, 56)), Color(0.35, 0.35, 0.45))
	draw_rect(Rect2(base - Vector2(28, 28), Vector2(56, 56)), Color(0.9, 0.8, 0.3), false, 3.0)
	draw_circle(base, 10, Color(0.9, 0.8, 0.3))


func _draw_overlay() -> void:
	if is_instance_valid(selected_tower):
		var p := selected_tower.position
		overlay.draw_circle(p, selected_tower.attack_range, Color(1, 1, 1, 0.08))
		overlay.draw_arc(p, selected_tower.attack_range, 0, TAU, 64, Color(1, 1, 1, 0.6), 2.0)
		overlay.draw_rect(Rect2(p - Vector2(30, 30), Vector2(60, 60)), Color(1, 0.9, 0.3), false, 2.0)

	if build_type != "" and in_grid(hover_cell):
		var d: Dictionary = TOWER_TYPES[build_type]
		var ok := can_build(hover_cell) and gold >= int(d["cost"])
		var col := Color(0.3, 1, 0.3) if ok else Color(1, 0.3, 0.3)
		var center := cell_center(hover_cell)
		overlay.draw_rect(Rect2(Vector2(hover_cell) * TILE, Vector2(TILE, TILE)), Color(col, 0.35))
		overlay.draw_circle(center, d["range"], Color(col, 0.08))
		overlay.draw_arc(center, d["range"], 0, TAU, 64, Color(col, 0.6), 2.0)


# ---------------------------------------------------------------- 遊戲流程

func _process(delta: float) -> void:
	if wave_active:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and not spawn_queue.is_empty():
			_spawn_enemy(spawn_queue.pop_front())
			spawn_timer = maxf(0.35, 0.9 - wave * 0.03)
		if spawn_queue.is_empty() and alive <= 0:
			_finish_wave()
	_refresh_ui()


func start_next_wave() -> void:
	if wave_active or game_over:
		return
	wave += 1
	wave_active = true
	spawn_timer = 0.0
	spawn_queue = _build_wave(wave)


func _build_wave(n: int) -> Array[String]:
	var q: Array[String] = []
	for i in 5 + n * 2:
		var kind := "normal"
		if n >= 3 and i % 3 == 1:
			kind = "fast"
		if n >= 5 and i % 4 == 3:
			kind = "tank"
		q.append(kind)
	if n % 5 == 0:
		q.append("boss")
	return q


func _spawn_enemy(kind: String) -> void:
	var e := Enemy.new()
	e.setup(path_points, kind, ENEMY_TYPES[kind], pow(1.14, wave - 1))
	e.died.connect(_on_enemy_died.bind(e))
	e.escaped.connect(_on_enemy_escaped)
	enemies_root.add_child(e)
	alive += 1


func _on_enemy_died(reward: int, e: Enemy) -> void:
	alive -= 1
	gold += reward
	Effect.floating_text(effects_root, e.position, "+%d" % reward, Color(1, 0.9, 0.3))


func _on_enemy_escaped(dmg: int) -> void:
	alive -= 1
	lives = maxi(0, lives - dmg)
	if lives <= 0:
		_end_game(false)


func _finish_wave() -> void:
	wave_active = false
	var bonus := 20 + wave * 5
	gold += bonus
	Effect.floating_text(effects_root, Vector2(COLS * TILE / 2.0, 40), "波次獎勵 +%d" % bonus, Color(1, 0.9, 0.3))
	if wave >= MAX_WAVE:
		_end_game(true)


func _end_game(won: bool) -> void:
	if game_over:
		return
	game_over = true
	end_label.text = "勝利！守住了全部 %d 波" % MAX_WAVE if won else "基地失守！撐過 %d 波" % (wave - 1)
	end_panel.show()
	get_tree().paused = true


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- 建造 / 選取

func select_build(id: String) -> void:
	build_type = id
	if id != "":
		_select_tower(null)
	for key in tower_buttons:
		(tower_buttons[key] as Button).set_pressed_no_signal(key == build_type)
	overlay.queue_redraw()


func _select_tower(t: Tower) -> void:
	selected_tower = t
	overlay.queue_redraw()


func _place_tower(c: Vector2i) -> void:
	var d: Dictionary = TOWER_TYPES[build_type]
	if not can_build(c) or gold < int(d["cost"]):
		return
	gold -= int(d["cost"])
	var t := Tower.new()
	t.position = cell_center(c)
	t.setup(build_type, d, c, enemies_root, projectiles_root, effects_root)
	towers_root.add_child(t)
	towers[c] = t
	Effect.ring(effects_root, t.position, 36, Color.WHITE)
	overlay.queue_redraw()


func upgrade_selected() -> void:
	var t := selected_tower
	if not is_instance_valid(t) or not t.can_upgrade() or gold < t.upgrade_cost():
		return
	gold -= t.upgrade_cost()
	t.upgrade()
	Effect.ring(effects_root, t.position, 40, Color(1, 0.85, 0.2))
	overlay.queue_redraw()


func sell_selected() -> void:
	var t := selected_tower
	if not is_instance_valid(t):
		return
	gold += t.sell_value()
	Effect.floating_text(effects_root, t.position, "+%d" % t.sell_value(), Color(1, 0.9, 0.3))
	towers.erase(t.cell)
	t.queue_free()
	_select_tower(null)


func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventMouseMotion:
		var c := Vector2i((get_global_mouse_position() / TILE).floor())
		if c != hover_cell:
			hover_cell = c
			overlay.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var c := Vector2i((get_global_mouse_position() / TILE).floor())
		if event.button_index == MOUSE_BUTTON_RIGHT:
			select_build("")
			_select_tower(null)
		elif event.button_index == MOUSE_BUTTON_LEFT and in_grid(c):
			if towers.has(c):
				select_build("")
				_select_tower(towers[c])
			elif build_type != "":
				_place_tower(c)
			else:
				_select_tower(null)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				var id: String = TOWER_ORDER[event.keycode - KEY_1]
				select_build("" if build_type == id else id)
			KEY_SPACE:
				start_next_wave()
			KEY_U:
				upgrade_selected()
			KEY_S:
				sell_selected()
			KEY_F:
				_cycle_speed()
			KEY_ESCAPE:
				select_build("")
				_select_tower(null)


func _cycle_speed() -> void:
	Engine.time_scale = 1.0 if Engine.time_scale >= 3.0 else Engine.time_scale + 1.0


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang TC", "Heiti TC", "Microsoft JhengHei", "Noto Sans CJK TC", "sans-serif",
	])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16

	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.theme = theme
	panel.position = Vector2(COLS * TILE, 0)
	panel.size = Vector2(PANEL_W, ROWS * TILE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.17)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "塔防守衛戰"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	stats_label = Label.new()
	box.add_child(stats_label)
	box.add_child(HSeparator.new())

	for i in TOWER_ORDER.size():
		var id: String = TOWER_ORDER[i]
		var d: Dictionary = TOWER_TYPES[id]
		var b := _make_button("[%d] %s  $%d\n%s" % [i + 1, d["name"], d["cost"], d["desc"]])
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", d["color"])
		b.pressed.connect(func() -> void: select_build("" if build_type == id else id))
		box.add_child(b)
		tower_buttons[id] = b

	box.add_child(HSeparator.new())
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(0, 66)
	box.add_child(info_label)

	var row := HBoxContainer.new()
	upgrade_button = _make_button("")
	upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_button.pressed.connect(upgrade_selected)
	sell_button = _make_button("")
	sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_button.pressed.connect(sell_selected)
	row.add_child(upgrade_button)
	row.add_child(sell_button)
	box.add_child(row)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	wave_button = _make_button("")
	wave_button.custom_minimum_size = Vector2(0, 44)
	wave_button.pressed.connect(start_next_wave)
	box.add_child(wave_button)

	speed_button = _make_button("")
	speed_button.pressed.connect(_cycle_speed)
	box.add_child(speed_button)

	var help := Label.new()
	help.text = "左鍵建造/選取　右鍵取消\nU 升級　S 出售　F 倍速"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	box.add_child(help)

	# 結束畫面
	var end_layer := CanvasLayer.new()
	end_layer.layer = 10
	add_child(end_layer)
	end_panel = ColorRect.new()
	(end_panel as ColorRect).color = Color(0, 0, 0, 0.7)
	end_panel.theme = theme
	end_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.hide()
	end_layer.add_child(end_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.add_child(center)
	var end_box := VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 20)
	center.add_child(end_box)
	end_label = Label.new()
	end_label.add_theme_font_size_override("font_size", 40)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_box.add_child(end_label)
	var restart := _make_button("重新開始")
	restart.custom_minimum_size = Vector2(200, 50)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(_restart)
	end_box.add_child(restart)


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	return b


func _refresh_ui() -> void:
	stats_label.text = "金幣：%d\n生命：%d\n波次：%d / %d" % [gold, lives, wave, MAX_WAVE]

	for id in tower_buttons:
		var d: Dictionary = TOWER_TYPES[id]
		(tower_buttons[id] as Button).modulate.a = 1.0 if gold >= int(d["cost"]) else 0.45

	var t := selected_tower
	if is_instance_valid(t):
		info_label.text = "%s  Lv.%d\n傷害 %.0f　射程 %.0f\n攻擊間隔 %.2f 秒" % [
			t.data["name"], t.level, t.damage, t.attack_range, t.rate]
		upgrade_button.visible = true
		sell_button.visible = true
		if t.can_upgrade():
			upgrade_button.text = "升級 $%d" % t.upgrade_cost()
			upgrade_button.disabled = gold < t.upgrade_cost()
		else:
			upgrade_button.text = "已滿級"
			upgrade_button.disabled = true
		sell_button.text = "出售 +$%d" % t.sell_value()
	else:
		info_label.text = "選擇上方防禦塔後點地圖建造；點擊已建的塔可升級或出售。"
		upgrade_button.visible = false
		sell_button.visible = false

	if wave_active:
		wave_button.text = "第 %d 波進行中（剩 %d）" % [wave, spawn_queue.size() + alive]
		wave_button.disabled = true
	else:
		wave_button.text = "開始第 %d 波 [空白鍵]" % (wave + 1)
		wave_button.disabled = game_over
	speed_button.text = "速度 x%d [F]" % int(Engine.time_scale)

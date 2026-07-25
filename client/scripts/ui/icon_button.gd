class_name IconButton
extends Button

@export_enum("back", "pause", "hint", "report", "sound", "map", "replay", "next", "settings") var icon_kind := "back"
@export var glow := false

const INK := Color("#0b1b29")
const GOLD := Color("#d6a64f")
const PAPER := Color("#f0dfbd")
const CINNABAR := Color("#a53b2b")

var _hovered := false
var _pulse := 0.0


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func(): _hovered = true; queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())
	resized.connect(queue_redraw)
	set_process(glow)


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	if glow:
		var halo := radius + 7.0 + sin(_pulse * 3.2) * 3.0
		draw_circle(center, halo, Color(GOLD, 0.10))
		draw_arc(center, halo, 0, TAU, 40, Color(GOLD, 0.32), 2.0, true)
	draw_circle(center, radius, Color("#132c3c") if not button_pressed else Color("#203d4c"))
	draw_arc(center, radius, 0, TAU, 40, GOLD if _hovered or glow else Color(GOLD, 0.72), 2.5, true)
	var color := PAPER if not disabled else Color(PAPER, 0.35)
	var s := radius * 0.78
	match icon_kind:
		"back": _draw_back(center, s, color)
		"pause": _draw_pause(center, s, color)
		"hint": _draw_hint(center, s, color)
		"report": _draw_report(center, s, color)
		"sound": _draw_sound(center, s, color)
		"map": _draw_map(center, s, color)
		"replay": _draw_replay(center, s, color)
		"next": _draw_next(center, s, color)
		"settings": _draw_settings(center, s, color)


func _draw_back(c: Vector2, s: float, color: Color) -> void:
	var points := PackedVector2Array([c + Vector2(s * 0.45, -s * 0.42), c + Vector2(-s * 0.35, 0), c + Vector2(s * 0.45, s * 0.42)])
	draw_polyline(points, color, 5.0, true)


func _draw_pause(c: Vector2, s: float, color: Color) -> void:
	draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.48), Vector2(s * 0.22, s * 0.96)), color, true)
	draw_rect(Rect2(c + Vector2(s * 0.13, -s * 0.48), Vector2(s * 0.22, s * 0.96)), color, true)


func _draw_hint(c: Vector2, s: float, color: Color) -> void:
	draw_arc(c + Vector2(0, -s * 0.08), s * 0.34, PI, TAU, 24, color, 4.0, true)
	draw_line(c + Vector2(-s * 0.34, -s * 0.08), c + Vector2(-s * 0.10, s * 0.34), color, 4.0, true)
	draw_line(c + Vector2(s * 0.34, -s * 0.08), c + Vector2(s * 0.10, s * 0.34), color, 4.0, true)
	draw_line(c + Vector2(-s * 0.12, s * 0.48), c + Vector2(s * 0.12, s * 0.48), color, 4.0, true)


func _draw_report(c: Vector2, s: float, color: Color) -> void:
	draw_line(c + Vector2(0, -s * 0.48), c + Vector2(0, s * 0.15), color, 5.0, true)
	draw_circle(c + Vector2(0, s * 0.42), 3.5, color)


func _draw_sound(c: Vector2, s: float, color: Color) -> void:
	var p := PackedVector2Array([c + Vector2(-s * 0.46, -s * 0.18), c + Vector2(-s * 0.18, -s * 0.18), c + Vector2(s * 0.12, -s * 0.44), c + Vector2(s * 0.12, s * 0.44), c + Vector2(-s * 0.18, s * 0.18), c + Vector2(-s * 0.46, s * 0.18)])
	draw_colored_polygon(p, color)
	draw_arc(c + Vector2(s * 0.08, 0), s * 0.38, -PI * 0.34, PI * 0.34, 16, color, 3.0, true)


func _draw_map(c: Vector2, s: float, color: Color) -> void:
	var p := PackedVector2Array([c + Vector2(-s * 0.48, -s * 0.38), c + Vector2(-s * 0.15, -s * 0.50), c + Vector2(s * 0.15, -s * 0.35), c + Vector2(s * 0.48, -s * 0.48), c + Vector2(s * 0.48, s * 0.38), c + Vector2(s * 0.15, s * 0.50), c + Vector2(-s * 0.15, s * 0.35), c + Vector2(-s * 0.48, s * 0.48)])
	draw_polyline(p, color, 3.5, true)
	draw_line(c + Vector2(-s * 0.15, -s * 0.50), c + Vector2(-s * 0.15, s * 0.35), color, 2.5, true)
	draw_line(c + Vector2(s * 0.15, -s * 0.35), c + Vector2(s * 0.15, s * 0.50), color, 2.5, true)


func _draw_replay(c: Vector2, s: float, color: Color) -> void:
	draw_arc(c, s * 0.42, -PI * 0.65, PI * 1.18, 30, color, 4.0, true)
	var p := PackedVector2Array([c + Vector2(-s * 0.49, -s * 0.18), c + Vector2(-s * 0.48, s * 0.23), c + Vector2(-s * 0.12, s * 0.06)])
	draw_colored_polygon(p, color)


func _draw_next(c: Vector2, s: float, color: Color) -> void:
	draw_line(c + Vector2(-s * 0.48, 0), c + Vector2(s * 0.30, 0), color, 5.0, true)
	var p := PackedVector2Array([c + Vector2(s * 0.10, -s * 0.40), c + Vector2(s * 0.50, 0), c + Vector2(s * 0.10, s * 0.40)])
	draw_colored_polygon(p, color)


func _draw_settings(c: Vector2, s: float, color: Color) -> void:
	draw_arc(c, s * 0.42, 0, TAU, 24, color, 4.0, true)
	draw_circle(c, s * 0.14, color)

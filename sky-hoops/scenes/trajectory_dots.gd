extends Node2D

var points: Array[Vector2] = []
var max_radius: float = 7.0
var min_radius: float = 2.5

func _draw() -> void:
	var count = points.size()
	for i in range(count):
		# Calcola il raggio che decresce man mano che ci si allontana
		var t = float(i) / float(max(1, count - 1)) if count > 1 else 0.0
		var r = lerp(max_radius, min_radius, t)
		
		# Disegna il pallino giallo/oro arcade
		var local_pos = to_local(points[i])
		draw_circle(local_pos, r, Color(1.0, 0.82, 0.15, 0.95))
		# Piccolo riflesso bianco interno per dare tridimensionalità
		draw_circle(local_pos, r * 0.45, Color(1.0, 1.0, 1.0, 0.85))

func update_dots(new_points: Array[Vector2]) -> void:
	points = new_points
	queue_redraw()

func clear_dots() -> void:
	points.clear()
	queue_redraw()

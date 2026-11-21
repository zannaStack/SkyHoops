extends ParallaxBackground

@onready var sky_sprite: Sprite2D = $LayerSky/Sprite2D
@onready var mount_sprite: Sprite2D = $LayerMountains/Sprite2D
@onready var hills_sprite: Sprite2D = $LayerHills/Sprite2D

var player: Node2D = null

# Palette cromatiche per le fasi della giornata
const COLOR_DAY_SKY: Color = Color(1.0, 1.0, 1.0)
const COLOR_DAY_MOUNT: Color = Color(1.0, 1.0, 1.0)
const COLOR_DAY_HILLS: Color = Color(1.0, 1.0, 1.0)

const COLOR_SUNSET_SKY: Color = Color(1.0, 0.65, 0.45) # Arancio/rosso tramonto
const COLOR_SUNSET_MOUNT: Color = Color(0.85, 0.45, 0.55) # Porpora tramonto
const COLOR_SUNSET_HILLS: Color = Color(0.9, 0.6, 0.35)

const COLOR_NIGHT_SKY: Color = Color(0.18, 0.22, 0.45) # Blu notte profondo
const COLOR_NIGHT_MOUNT: Color = Color(0.25, 0.18, 0.4) # Notte indaco
const COLOR_NIGHT_HILLS: Color = Color(0.15, 0.35, 0.3)

func _ready() -> void:
	player = get_parent().get_node_or_null("Player")

func _process(delta: float) -> void:
	if not player:
		player = get_parent().get_node_or_null("Player")
		if not player:
			return

	var dist_m: float = max(0.0, player.global_position.x / 50.0)
	
	# Calcola il fattore di transizione in base alla distanza
	var target_sky: Color
	var target_mount: Color
	var target_hills: Color
	
	if dist_m < 600.0:
		# Giorno pieno con leggera sfumatura verso tramonto
		var t = clamp(dist_m / 600.0, 0.0, 1.0)
		target_sky = COLOR_DAY_SKY.lerp(COLOR_SUNSET_SKY, t * 0.4)
		target_mount = COLOR_DAY_MOUNT.lerp(COLOR_SUNSET_MOUNT, t * 0.4)
		target_hills = COLOR_DAY_HILLS.lerp(COLOR_SUNSET_HILLS, t * 0.4)
	elif dist_m < 1500.0:
		# Transizione verso tramonto caldo
		var t = clamp((dist_m - 600.0) / 900.0, 0.0, 1.0)
		target_sky = COLOR_DAY_SKY.lerp(COLOR_SUNSET_SKY, 0.4).lerp(COLOR_SUNSET_SKY, t)
		target_mount = COLOR_DAY_MOUNT.lerp(COLOR_SUNSET_MOUNT, 0.4).lerp(COLOR_SUNSET_MOUNT, t)
		target_hills = COLOR_DAY_HILLS.lerp(COLOR_SUNSET_HILLS, 0.4).lerp(COLOR_SUNSET_HILLS, t)
	elif dist_m < 2600.0:
		# Transizione verso la notte stellata
		var t = clamp((dist_m - 1500.0) / 1100.0, 0.0, 1.0)
		target_sky = COLOR_SUNSET_SKY.lerp(COLOR_NIGHT_SKY, t)
		target_mount = COLOR_SUNSET_MOUNT.lerp(COLOR_NIGHT_MOUNT, t)
		target_hills = COLOR_SUNSET_HILLS.lerp(COLOR_NIGHT_HILLS, t)
	else:
		# Notte fonda
		target_sky = COLOR_NIGHT_SKY
		target_mount = COLOR_NIGHT_MOUNT
		target_hills = COLOR_NIGHT_HILLS

	if sky_sprite: sky_sprite.modulate = sky_sprite.modulate.lerp(target_sky, 2.0 * delta)
	if mount_sprite: mount_sprite.modulate = mount_sprite.modulate.lerp(target_mount, 2.0 * delta)
	if hills_sprite: hills_sprite.modulate = hills_sprite.modulate.lerp(target_hills, 2.0 * delta)

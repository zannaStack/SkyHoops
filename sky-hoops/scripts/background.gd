extends ParallaxBackground

@onready var sky_sprite: Sprite2D = $LayerSky/Sprite2D
@onready var mount_sprite: Sprite2D = $LayerMountains/Sprite2D
@onready var hills_sprite: Sprite2D = $LayerHills/Sprite2D
@onready var stars_particles: CPUParticles2D = get_node_or_null("LayerStars/StarsParticles")

var player: Node2D = null

# Palette cromatiche per le fasi della giornata
const COLOR_DAY_SKY: Color = Color(1.0, 1.0, 1.0)
const COLOR_DAY_MOUNT: Color = Color(1.0, 1.0, 1.0)
const COLOR_DAY_HILLS: Color = Color(1.0, 1.0, 1.0)

const COLOR_SUNSET_SKY: Color = Color(1.0, 0.62, 0.42) # Caldo arancio/pesca tramonto
const COLOR_SUNSET_MOUNT: Color = Color(0.88, 0.44, 0.58) # Porpora tramonto
const COLOR_SUNSET_HILLS: Color = Color(0.92, 0.62, 0.38) # Oro colline

const COLOR_DUSK_SKY: Color = Color(0.38, 0.28, 0.62) # Crepuscolo viola/indaco
const COLOR_DUSK_MOUNT: Color = Color(0.32, 0.22, 0.48)
const COLOR_DUSK_HILLS: Color = Color(0.25, 0.38, 0.42)

const COLOR_NIGHT_SKY: Color = Color(0.12, 0.16, 0.38) # Blu notte profondo stellato
const COLOR_NIGHT_MOUNT: Color = Color(0.18, 0.14, 0.32) # Notte indaco
const COLOR_NIGHT_HILLS: Color = Color(0.16, 0.32, 0.35)

func _ready() -> void:
	player = get_parent().get_node_or_null("Player")
	if stars_particles:
		stars_particles.modulate.a = 0.0

func _process(delta: float) -> void:
	if not player:
		player = get_parent().get_node_or_null("Player")
		if not player:
			return

	var dist_m: float = max(0.0, player.global_position.x / 50.0)
	
	# Calcola la transizione dinamica delle 4 fasi del giorno
	var target_sky: Color
	var target_mount: Color
	var target_hills: Color
	var target_stars_alpha: float = 0.0
	
	if dist_m < 350.0:
		# Giorno pieno radioso (0 - 350m)
		target_sky = COLOR_DAY_SKY
		target_mount = COLOR_DAY_MOUNT
		target_hills = COLOR_DAY_HILLS
		target_stars_alpha = 0.0
	elif dist_m < 900.0:
		# Transizione verso il tramonto dorato (350m - 900m)
		var t = clamp((dist_m - 350.0) / 550.0, 0.0, 1.0)
		target_sky = COLOR_DAY_SKY.lerp(COLOR_SUNSET_SKY, t)
		target_mount = COLOR_DAY_MOUNT.lerp(COLOR_SUNSET_MOUNT, t)
		target_hills = COLOR_DAY_HILLS.lerp(COLOR_SUNSET_HILLS, t)
		target_stars_alpha = 0.0
	elif dist_m < 1600.0:
		# Crepuscolo porpora/indaco con prime stelle (900m - 1600m)
		var t = clamp((dist_m - 900.0) / 700.0, 0.0, 1.0)
		target_sky = COLOR_SUNSET_SKY.lerp(COLOR_DUSK_SKY, t)
		target_mount = COLOR_SUNSET_MOUNT.lerp(COLOR_DUSK_MOUNT, t)
		target_hills = COLOR_SUNSET_HILLS.lerp(COLOR_DUSK_HILLS, t)
		target_stars_alpha = lerp(0.0, 0.65, t)
	else:
		# Notte stellata con circuito illuminato (1600m+)
		var t = clamp((dist_m - 1600.0) / 800.0, 0.0, 1.0)
		target_sky = COLOR_DUSK_SKY.lerp(COLOR_NIGHT_SKY, t)
		target_mount = COLOR_DUSK_MOUNT.lerp(COLOR_NIGHT_MOUNT, t)
		target_hills = COLOR_DUSK_HILLS.lerp(COLOR_NIGHT_HILLS, t)
		target_stars_alpha = lerp(0.65, 0.95, t)

	if sky_sprite: sky_sprite.modulate = sky_sprite.modulate.lerp(target_sky, 2.0 * delta)
	if mount_sprite: mount_sprite.modulate = mount_sprite.modulate.lerp(target_mount, 2.0 * delta)
	if hills_sprite: hills_sprite.modulate = hills_sprite.modulate.lerp(target_hills, 2.0 * delta)
	if stars_particles: stars_particles.modulate.a = lerp(stars_particles.modulate.a, target_stars_alpha, 2.0 * delta)

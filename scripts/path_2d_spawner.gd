extends Path2D

@export var spawner_time: float = 2.0
@export var base_enemies_per_wave: int = 4
@export var wave_scaling_factor: float = 0.8
@export var min_spawn_delay: float = 0.2
@export var time_between_waves: float = 5.0


var enemy_scenes = {
	"scorpion": preload("res://scenes/enemi/scorpion.tscn"),
	"rat": preload("res://scenes/enemi/rat.tscn"),
	"cuervo": preload("res://scenes/enemi/cuervo.tscn"),
	"spider": preload("res://scenes/enemi/spider.tscn")
}
var minotauro = preload("res://scenes/enemi/minotauro.tscn")
var margarita = false
var enemies_alive: int = 0
var spawning: bool = false
var current_wave: int = 1
var wave_active: bool = false

func _ready() -> void:

	
	Dialogic.connect("signal_event", Callable(self, "_on_dialogic_signal"))
	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
	start_wave()
	if Player:
		#Player.update_data()
		Player._init_ui()
		if Player.wave == null:
			Player.wave = 1
		current_wave = Player.wave
		print("Empezando dialogo")
		$"..".play_wave_dialog(current_wave)
	
	await get_tree().create_timer(1.0).timeout  
	
func _on_dialogic_signal(argument:String):

	if argument == "start_wave":
		get_node("/root/Mapa").process_mode = Node.PROCESS_MODE_INHERIT
		spawning = false
		start_wave()
	elif argument == "stop_wave":
		spawning = true
		get_node("/root/Mapa").process_mode = Node.PROCESS_MODE_DISABLED

	elif argument == "pause":
		get_node("/root/Mapa").process_mode = Node.PROCESS_MODE_INHERIT

	elif argument == "end_good":
		Global.change_scene("res://scenes/final.tscn")
	elif argument == "end_pacifist":
		Global.change_scene("res://scenes/final.tscn")


func start_wave() -> void:
	if spawning:
		
		return

	spawning = true
	wave_active = true
	enemies_alive = 0
	
	var wave = Player.wave
	var enemies_to_spawn = base_enemies_per_wave + int(wave * wave_scaling_factor)
	
	print("====================================")
	print("🌊 Comenzando oleada %d con %d enemigos" % [wave, enemies_to_spawn])
	await get_tree().create_timer(0.5).timeout

	# Oleada de jefe cada 10 niveles
	if wave  == 100:
		await spawn_margarita()
		spawning = false
		return
	if wave % 10 == 0:
		await spawn_boss_wave(wave)
	# Oleada especial cada 5 niveles
	elif wave % 5 == 0:
		await spawn_special_wave(wave, enemies_to_spawn)
	# Oleada normal
	else:
		await spawn_normal_wave(wave, enemies_to_spawn)
	print("Stop spwaninf")
	spawning = false
func spawn_margarita():
	print("👑 ¡Oleada de Margarita!")
	var boss = minotauro.instantiate()
	connect_enemy(boss)
	add_child(boss)
	enemies_alive += 1

func spawn_boss_wave(wave: int) -> void:
	print("👑 ¡Oleada de Jefe! (Nivel %d)" % wave)
	await get_tree().create_timer(1.0).timeout
	var boss = select_enemy_for_wave(wave).instantiate()
	boss.runSpeed *= 0.8
	boss.live *= 10.0 * wave
	boss.damage *= 4 
	boss.reward *= 6
	boss.scale *= 2.2
	if wave >= 50:
		var boss2 = select_enemy_for_wave(wave).instantiate()
		boss2.runSpeed *= 0.8
		boss2.live *= 10.0 * wave
		boss2.damage *= 4
		boss2.reward *= 6
		boss2.scale *= 2.2
		connect_enemy(boss2)
		add_child(boss2)
		enemies_alive += 1
	connect_enemy(boss)
	add_child(boss)
	enemies_alive += 1

func spawn_special_wave(wave: int, base_count: int) -> void:
	print("🔥 Oleada especial: Enjambre (Nivel %d)" % wave)
	var total_enemies = base_count + 5
	var enjambre = select_enemy_for_wave(wave)
	for i in range(total_enemies):
		await spawn_enemy_delayed(enjambre, wave,  min_spawn_delay)


func spawn_normal_wave(wave: int, enemies_to_spawn: int) -> void:
	var spawn_delay = max(min_spawn_delay, 1.0 - (wave / 100.0))
	for i in range(enemies_to_spawn):
		var enemy_scene = select_enemy_for_wave(wave)
		await spawn_enemy_delayed(enemy_scene, wave, spawn_delay)



func select_enemy_for_wave(wave: int) -> PackedScene:
	var rand = randi_range(0, 100)
	
	if wave >= 10 and rand > 85:
		return enemy_scenes["cuervo"]
	elif wave >= 6 and rand > 70:
		return enemy_scenes["scorpion"]
	elif wave >= 4 and rand > 50:
		return enemy_scenes["spider"]
	else:
		return enemy_scenes["rat"]

func spawn_enemy_delayed(enemy_scene: PackedScene, wave: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	print("Enemigo instanciado. Total vivos: %d" % enemies_alive)

	if not wave_active:   
		return
	
	var enemy = enemy_scene.instantiate()
	# Escalar estadísticas según la oleada
	enemy.runSpeed += 0.0015 * wave
	enemy.live += 2.5 * wave
	enemy.reward += wave

	connect_enemy(enemy)
	add_child(enemy)
	enemies_alive += 1


func connect_enemy(enemy: Node) -> void:
	if not enemy.has_signal("enemy_died"):
		push_warning("Enemigo %s no tiene señal enemy_died" % enemy.name)
		return
	
	if not enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

func _on_enemy_died(_enemy:Node) -> void:
	enemies_alive -= 1
	print("Enemigos restantes: %d" % enemies_alive)
	if enemies_alive < 1 and !spawning and wave_active:
		end_wave()

func end_wave() -> void:
	wave_active = false
	current_wave += 1
	Player.wave = current_wave
	Player.update_data()
	Player.update_ui()
	if Player.auto_save:
		Global.save_game_named(Global.current_save_name)
	$"..".play_wave_dialog(current_wave)
	$Rondas.text = "Day " +str(current_wave) 
	$UI.start()
	print("✅ Oleada completada. Preparando oleada %d..." % current_wave)
	
	# Esperar tiempo entre oleadas
	await get_tree().create_timer(time_between_waves).timeout
	
	# Verificar que el jugador aún esté vivo antes de empezar nueva oleada
	if Player and Player.player_life > 0:
		$Rondas.text = "" 
		start_wave()


func _on_ui_timeout() -> void:
	$Rondas.text = ""

extends Node2D

@export var damage = 10
@export var bulletSpeed := 2000.0
@export var bulletPierce := 1
@export var attack_interval := 1.0
@export var price: float = 500
@export var escala: float = 1

# Contador para diferentes finales segun la torreta
var contDamage = 0

# Valores base para calcular mejoras
var base_damage := 10
var base_speed := 2000.0
var base_attack_speed := 1.0

# Costes de mejoras
var damage_upgrade_cost := 50
var speed_upgrade_cost := 50
var special_upgrade_cost := 75
var sell_refund_percent := 0.7  # 70% del precio al vender

# Valor de venta
var refund = price * sell_refund_percent

# Límites de mejoras
const MAX_DAMAGE_LEVEL := 10
const MAX_SPEED_LEVEL := 8
const MAX_SPECIAL_LEVEL := 7
const MIN_ATTACK_INTERVAL := 0.15  # Límite mínimo para el intervalo de ataque

var enemigos = []
var current_target = null
var can_attack = false
var upgrade_levels = {
	"damage": 0,
	"speed": 0,
	"special": 0
}

signal tower_sold(position)

func _ready():
	# Inicializar valores
	$attack_timer.wait_time = attack_interval
	# Conectar señales del menú si existe
	if has_node("TurretMenu"):
		$TurretMenu.tower = self

func _process(_delta):
	if current_target and current_target in enemigos and !current_target.is_dead:
		if can_attack:
			attack()
	else:
		try_get_closest_target()

func attack():
	if current_target and is_instance_valid(current_target) and current_target in enemigos:
		$AnimatedSprite2D.play("Atq")
		var projectileScene = preload("res://scenes/towers/bullet_espanta.tscn")
		var projectile = projectileScene.instantiate()
		projectile.connect("hit", Callable(self, "_on_projectile_hit"))
		projectile.damage = damage
		projectile.speed = bulletSpeed
		projectile.pierce = bulletPierce
		projectile.position = Vector2(-30, -16) + position
		projectile.target = current_target.position
		get_parent().add_child(projectile)
		can_attack = false

func _on_projectile_hit() :
	contDamage += 1
	check_carlitos_lore()

func check_carlitos_lore():
	match contDamage:
		50:
			Dialogic.start("lore_1")
		150:
			Dialogic.start("lore_2")
		300:
			Dialogic.start("lore_3")
		500:
			Dialogic.start("lore_4")
		800:
			print("Carlitos: No puedo callar más... ¡Él PROVOCÓ el apocalipsis!")
		_:
			pass  # Para cualquier otro valor, no hace nada


func _on_attack_timer_timeout():
	can_attack = true

func try_get_closest_target():
	$AnimatedSprite2D.play("sleep")
	if !enemigos.is_empty():
		current_target = enemigos.back()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemi"):
		enemigos.append(area.get_parent())
		if not current_target:
			current_target = area.get_parent()

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("enemi"):
		enemigos.erase(area.get_parent())
		if current_target == area.get_parent():
			var enemy_present = false
			for body in enemigos:
				if body.is_in_group("enemi"):
					enemy_present = true
					current_target = body
					break
			if not enemy_present:
				current_target = null

# Funciones de mejoras

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_menu()

func toggle_menu():
	if has_node("TurretMenu"):
		var menu = $TurretMenu/Panel
		menu.visible = not menu.visible
		Player.update_ui()
		update_menu_info()

func update_menu_info():
	if has_node("TurretMenu"):
		$TurretMenu.update_info(
			damage_upgrade_cost * (upgrade_levels["damage"] + 1) if upgrade_levels["damage"] < MAX_DAMAGE_LEVEL else -1,
			speed_upgrade_cost * (upgrade_levels["speed"] + 1) if upgrade_levels["speed"] < MAX_SPEED_LEVEL else -1,
			special_upgrade_cost * (upgrade_levels["special"] + 1) if upgrade_levels["special"] < MAX_SPECIAL_LEVEL else -1,
			refund,
			upgrade_levels
		)
		Player.update_ui()

func upgrade_damage():
	if upgrade_levels["damage"] >= MAX_DAMAGE_LEVEL:
		return
	
	var cost = damage_upgrade_cost * (upgrade_levels["damage"] + 1)
	if Player.player_gold >= cost:
		Player.player_gold -= cost
		refund += cost * sell_refund_percent
		upgrade_levels["damage"] += 1
		damage = base_damage + (5 * upgrade_levels["damage"])
		update_menu_info()

func upgrade_speed():
	if upgrade_levels["speed"] >= MAX_SPEED_LEVEL:
		return
	
	var cost = speed_upgrade_cost * (upgrade_levels["speed"] + 1)
	if Player.player_gold >= cost:
		Player.player_gold -= cost
		refund += cost * sell_refund_percent
		upgrade_levels["speed"] += 1
		attack_interval = max(MIN_ATTACK_INTERVAL, base_attack_speed - (0.1 * upgrade_levels["speed"]))
		$attack_timer.wait_time = attack_interval
		update_menu_info()

func upgrade_special():
	if upgrade_levels["special"] >= MAX_SPECIAL_LEVEL:
		return
	
	var cost = special_upgrade_cost * (upgrade_levels["special"] + 1)
	if Player.player_gold >= cost:
		Player.player_gold -= cost
		refund += cost * sell_refund_percent
		upgrade_levels["special"] += 1
		bulletPierce +=1
		bulletSpeed += 350
		update_menu_info()

func sell_tower():
	Player.player_gold += refund
	emit_signal("tower_sold", position)
	queue_free()
	Player.update_ui()


func get_save_data() -> Dictionary:
	return {
		"scene_path": "res://scenes/towers/espanta_pajaros.tscn",
		"position": position,
		"damage": damage,
		"bulletSpeed": bulletSpeed,
		"upgrade_levels": upgrade_levels,
		"attack_interval": attack_interval
	}

extends KinematicBody2D
class_name Player

const spawn = Vector2(200, -50)

var id
var health = 1.0 setget set_health
var direction setget set_direction
var hand_item: HandItem
var gun_item: Item

var last_gun_usage = 0
var last_hand_usage = 0

var deaths = 0 setget set_deaths
var kills = 0 setget set_kills

func _ready():
	hand_item = HandItem.new()
	hand_item.damage = 0.1
	hand_item.knockback_user = 70
	hand_item.knockback_enemy = 500
	hand_item.radius = 120
	hand_item.allowed_angle = PI / 4
	hand_item.reset_time = 400
	hand_item.owner = self
	gun_item = Item.new()
	gun_item.damage = 0.05
	gun_item.knockback_user = 20
	gun_item.knockback_enemy = 80
	gun_item.reset_time = 100
	gun_item.owner = self
	rset_config("position", MultiplayerAPI.RPC_MODE_REMOTESYNC)
	rset_config("health", MultiplayerAPI.RPC_MODE_REMOTESYNC)
	rset_config("direction", MultiplayerAPI.RPC_MODE_REMOTESYNC)
	rset_config("external_force", MultiplayerAPI.RPC_MODE_REMOTESYNC)
	rset_config("kills", MultiplayerAPI.RPC_MODE_REMOTESYNC)
	rset_config("deaths", MultiplayerAPI.RPC_MODE_REMOTESYNC)
	set_process(true)
	randomize()
	position = spawn
	$Camera2D.current = is_network_master()
	
	for player in get_tree().get_nodes_in_group("players"):
		if player != self:
			on_new_enemy(player)
			
	if is_network_master():
		$Camera2D/Kills.show()
		$Camera2D/KillsLabel.show()
		$Camera2D/Deaths.show()
		$Camera2D/DeathsLabel.show()
	
	# pick our color, even though this will be called on all clients, everyone
	# else's random picks will be overriden by the first sync_state from the master
	#set_color(Color.from_hsv(randf(), 1, 1))
	
func on_new_enemy(enemy: Player):
	if is_network_master():
		var indicator = preload("res://game/player_indicator/PlayerIndicator.tscn").instance()
		indicator.follow_enemy(self, enemy)
		$Camera2D.add_child(indicator)

func get_sync_state():
	# place all synced properties in here
	var properties = ['color', 'health', 'kills', 'deaths']
	
	var state = {}
	for p in properties:
		state[p] = get(p)
	return state

func _process(delta):
	if is_network_master():
		if Input.is_action_just_pressed("ui_accept"):
			rpc("spawn_box", position)
		if Input.is_mouse_button_pressed(BUTTON_RIGHT):
			if OS.get_ticks_msec() - last_gun_usage > gun_item.reset_time:
				rpc("spawn_projectile", position, get_mouse_direction(), Uuid.v4())
		
		do_movement(delta)

func _input(event):
	if is_network_master():
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
			if OS.get_ticks_msec() - last_hand_usage > hand_item.reset_time:
				do_hit(position, get_mouse_direction(), Uuid.v4())
		if event is InputEventMouseMotion:
			rset_unreliable("direction", get_mouse_direction())
		
func get_mouse_direction():
	return -(get_viewport().size / 2 - get_viewport().get_mouse_position()).normalized()

const gravity_acceleration = 2000
const max_speed = 1000
const speed = 350
const air_acceleration = 50
const jump_speed_side = 300
const wall_sliding_speed = 150
const jump_power = -800

var velocity = Vector2(0, 0)
var external_force = Vector2(0, 0)
var jump_allowed = 2
var dropping = false

var time_since_contact = 0
var time_since_jump = 0
const jump_grace_period_in_seconds = 0.1
const jump_lockout_period_in_seconds = 0.1

enum Move {
	LEFT,
	RIGHT,
	DROP,
	NOT
}

func do_movement(delta):
	time_since_contact += delta
#	
	var move = Move.NOT
	var jump = false
	
	if time_since_contact > jump_lockout_period_in_seconds || is_on_floor() || is_on_wall():
		if Input.is_action_pressed("action_left"):
			move = Move.LEFT
		if Input.is_action_pressed("action_right"):
			move = Move.RIGHT
		if Input.is_action_pressed("action_left") && Input.is_action_pressed("action_right"):
			move = Move.NOT
		if Input.is_action_just_pressed("action_down"):
			move = Move.DROP
			
	jump = Input.is_action_just_pressed("action_jump")
		
	if move == Move.LEFT && !dropping:
		if is_on_floor():
			velocity.x = min(velocity.x, -speed)
		else:
			velocity.x = max(velocity.x - air_acceleration, -speed)
	elif move == Move.RIGHT && !dropping:
		if is_on_floor():
			velocity.x = max(velocity.x, speed)
		else:
			velocity.x = min(velocity.x + air_acceleration, speed)
	elif move == Move.NOT:
		if is_on_floor():
			velocity.x = 0
	elif move == Move.DROP && !is_on_floor():
		velocity.x = 0
		velocity.y = -jump_power
		jump_allowed = 0
		dropping = true
	
	if is_on_floor():
		velocity.y = 0
		time_since_contact = 0
		dropping = false
		jump_allowed = 2
		if abs(velocity.x) > speed:
			var slowing = (abs(velocity.x) - speed) * 2 * delta
			print(velocity.x, " ", speed, " ", slowing)
			velocity.x -= slowing
	else:
		# gravity
		velocity.y += gravity_acceleration * delta
	
	if time_since_contact > jump_grace_period_in_seconds && jump_allowed == 2:
		jump_allowed = 1
	
	if is_on_ceiling():
		velocity.y = max(0, velocity.y)
	
	if is_on_wall():
		time_since_contact = 0
		jump_allowed = 2
		if !dropping:
			velocity.y = wall_sliding_speed
			if jump:
				var side = get_colliding_wall()
				if side == Wall.LEFT:
					velocity.x = jump_speed_side + speed
					print("left wall -> ", velocity)
				else:
					velocity.x = -(jump_speed_side + speed)
					print("right wall -> ", velocity)
				velocity.y = jump_power
				jump_allowed -=1
				time_since_jump = 0
	elif jump && jump_allowed:
		var side = get_colliding_wall()
		if move == Move.LEFT:
			velocity.x -= jump_speed_side
		if move == Move.RIGHT:
			velocity.x += jump_speed_side
		velocity.y = jump_power
		jump_allowed -=1
		time_since_jump = 0
	
	$Camera2D/is_jump_allowed.color = Color.red if jump_allowed else Color.white
	$Camera2D/is_drop_allowed.color = Color.red if dropping else Color.white
	$Camera2D/is_touching.color = Color.red if time_since_contact < jump_grace_period_in_seconds else Color.white
	
	velocity += external_force
	external_force *= 0.9 # TODO: dampen factor
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	#if knockback.length() > 0:
	#	external_force += knockback
	
	move_and_slide(velocity, Vector2(0, -1))
	rset_unreliable("position", position)

enum Wall {
	LEFT,
	RIGHT
}

func get_colliding_wall():
	for i in range(get_slide_count()):
		var collision = get_slide_collision(i)
		if collision.normal.x > 0:
			return Wall.LEFT
		elif collision.normal.x < 0:
			return Wall.RIGHT
	
func set_health(value: float):
	health = value
	$Camera2D/HealthBackground/Health.rect_scale = Vector2(health, 1.0)
	
func set_direction(value: Vector2):
	direction = value
	$Camera2D/Direction.set_direction(direction)

remotesync func spawn_projectile(position, direction, name):
	last_gun_usage = OS.get_ticks_msec()
	var projectile = preload("res://game/physics_projectile/physics_projectile.tscn").instance()
	projectile.set_network_master(1)
	projectile.name = name
	projectile.position = position
	projectile.direction = direction
	projectile.owned_by = self
	projectile.item = gun_item
	get_parent().add_child(projectile)
	knockback(-direction * gun_item.knockback_user)
	return projectile
	
func do_hit(position, direction: Vector2, name):
	last_hand_usage = OS.get_ticks_msec()
	$Camera2D/Direction.do_hit()
	knockback(-direction * get_active_item().knockback_user)
	var all = get_tree().get_nodes_in_group("players")
	for enemy in all:
		if enemy != self:
			var distance = position.distance_to(enemy.position)
			var vector_hit = (enemy.position - position).normalized()
			var angle = abs(direction.angle_to(vector_hit))
			if distance < hand_item.radius and angle < hand_item.allowed_angle:
				rpc("hit_player", enemy.id)
				
remotesync func hit_player(enemyid):
	var enemy = get_player_with_id(enemyid)
	if enemy:
		enemy.hit_by_player(self)

remotesync func spawn_box(position):
	var box = preload("res://examples/block/block.tscn").instance()
	box.position = position
	get_parent().add_child(box)
	
func get_active_item():
	return hand_item
	
func get_player_with_id(id):
	for player in get_tree().get_nodes_in_group("players"):
		if player.id == id:
			return player
	return null
	
remotesync func hit_by_projectile(projectile: Node2D):
	receive_damage(projectile, projectile.position.direction_to(position))
		
func hit_by_player(enemy: Player):
	receive_damage(enemy, enemy.position.direction_to(position))
			
remotesync func hit_by_environment(environment: Node):
	receive_damage(environment, Vector2(1, 0))
			
func receive_damage(element, direction):
	rset("health", health - element.get_active_item().damage)
	knockback(direction * element.get_active_item().knockback_enemy)
	if health <= 0:
		if element.get_active_item().owner:
			element.get_active_item().owner.enemy_killed()
		rpc("die_and_respawn", self)
		
func knockback(force: Vector2):
	if external_force.length() < force.length():
		rset("external_force", external_force + force)

remotesync func die_and_respawn(player: Player):
	if (player == self):
		print("Player died")
		rset("health", 1.0)
		rset("external_force", 0.0)
		position = spawn
		velocity = Vector2(0, 0)
		rset_unreliable("position", position)
		rset("deaths", deaths + 1)

func enemy_killed():
	rset("kills", kills + 1)
	
func set_deaths(value):
	deaths = value
	$Camera2D/Deaths.text = String(deaths)
	
func set_kills(value):
	kills = value
	$Camera2D/Kills.text = String(kills)
		
remotesync func kill():
	hide()

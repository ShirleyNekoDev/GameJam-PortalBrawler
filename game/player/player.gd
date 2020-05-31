extends KinematicBody2D
class_name Player

const spawn = Vector2(200, -50)

var id
var color: Color setget set_color
var health = 1.0 setget set_health
var direction setget set_direction
var hand_item = HandItem.new(0.1, 50, PI / 4)
var gun_item = Item.new(0.03)

func _ready():
	rset_config("position", MultiplayerAPI.RPC_MODE_REMOTESYNC)
	rset_config("health", MultiplayerAPI.RPC_MODE_REMOTESYNC)
	rset_config("direction", MultiplayerAPI.RPC_MODE_REMOTESYNC)
	set_process(true)
	randomize()
	position = spawn
	$Camera2D.current = is_network_master()
	
	# pick our color, even though this will be called on all clients, everyone
	# else's random picks will be overriden by the first sync_state from the master
	set_color(Color.from_hsv(randf(), 1, 1))

func get_sync_state():
	# place all synced properties in here
	var properties = ['color', 'health']
	
	var state = {}
	for p in properties:
		state[p] = get(p)
	return state

func _process(delta):
	if is_network_master():
		if Input.is_action_just_pressed("ui_accept"):
			rpc("spawn_box", position)
		if Input.is_mouse_button_pressed(BUTTON_RIGHT):
			rpc("spawn_projectile", position, get_mouse_direction(), Uuid.v4())
		
		do_movement(delta)

func _input(event):
	if is_network_master():
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
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
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
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

func set_color(_color: Color):
	color = _color
	$sprite.modulate = color
	
func set_health(value: float):
	health = value
	$Camera2D/HealthBackground/Health.rect_scale = Vector2(health, 1.0)
	
func set_direction(value: Vector2):
	direction = value
	$Camera2D/Direction.set_direction(direction)

remotesync func spawn_projectile(position, direction, name):
	var projectile = preload("res://game/physics_projectile/physics_projectile.tscn").instance()
	projectile.set_network_master(1)
	projectile.name = name
	projectile.position = position
	projectile.direction = direction
	projectile.owned_by = self
	projectile.item = gun_item
	get_parent().add_child(projectile)
	return projectile
	
func do_hit(position, direction: Vector2, name):
	var all = get_tree().get_nodes_in_group("players")
	for player in all:
		if player != self:
			var distance = position.distance_to(player.position)
			var vector_hit = (position - player.position).normalized()
			var angle = abs(direction.angle_to(vector_hit))
			if distance < hand_item.get_radius() and angle < hand_item.get_allowed_angle():
				rpc("hit_by_player", player.id)

remotesync func spawn_box(position):
	var box = preload("res://examples/block/block.tscn").instance()
	box.position = position
	get_parent().add_child(box)
	
func get_active_item():
	return hand_item
	
remotesync func hit_by_projectile(projectile: Node):
	receive_damage(projectile)
		
remotesync func hit_by_player(playerid):
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player.id == playerid:
			receive_damage(player)
			break
			
remotesync func hit_by_environment(environment: Node):
	receive_damage(environment)
			
func receive_damage(element):
	rset("health", health - element.get_active_item().get_damage())
	if health <= 0:
		rpc("die_and_respawn", self)

remotesync func die_and_respawn(player: Player):
	if (player == self):
		print("Player died")
		rset("health", 1.0)
		position = spawn
		velocity = Vector2(0, 0)
		rset_unreliable("position", position)

remotesync func kill():
	hide()

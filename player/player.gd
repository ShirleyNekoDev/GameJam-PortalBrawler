extends KinematicBody2D
class_name Player

var id
var color: Color setget set_color
var health = 1.0

signal health_changed(new_health)

func _ready():
	rset_config("position", MultiplayerAPI.RPC_MODE_REMOTESYNC)
	set_process(true)
	randomize()
	position = Vector2(rand_range(0, get_viewport_rect().size.x), rand_range(0, get_viewport_rect().size.y))
	
	
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
		if Input.is_mouse_button_pressed(BUTTON_LEFT):
			var direction = -(position - get_viewport().get_mouse_position()).normalized()
			rpc("spawn_projectile", position, direction, Uuid.v4())
		
		do_movement(delta)

const gravity_acceleration = 20
var velocity = Vector2(0, 0)
const max_speed = 200
var jump_allowed = false
const jump_power = 1400

var time_since_contact = 0
const jump_grace_period_in_seconds = 0.1

enum {
	MOVE_LEFT,
	MOVE_RIGHT,
	MOVE_NOT
}

func do_movement(delta):
	time_since_contact += delta
	
	jump_allowed = false
	var move = MOVE_NOT
	if Input.is_action_pressed("action_left"):
		move = MOVE_LEFT
	if Input.is_action_pressed("action_right"):
		move = MOVE_RIGHT
	if Input.is_action_pressed("action_left") && Input.is_action_pressed("action_right"):
		move = MOVE_NOT
	
	var jump = Input.is_action_just_pressed("action_jump")
	
	if move == MOVE_LEFT:
		velocity.x = -max_speed
	elif move == MOVE_RIGHT:
		velocity.x = max_speed
	elif move == MOVE_NOT:
		velocity.x = 0
	
	if is_on_floor():
		velocity.y = 0
		time_since_contact = 0
	else:
		velocity = velocity + Vector2(0, gravity_acceleration)
	
	if is_on_wall():
		time_since_contact = 0
	
	if time_since_contact < jump_grace_period_in_seconds:
		jump_allowed = true
	
	if jump && jump_allowed:
		velocity.y -= jump_power
		time_since_contact = jump_grace_period_in_seconds
	
	$Camera2D/is_jump_allowed.color = Color.red if jump_allowed else Color.white
	$Camera2D/is_on_ground.color = Color.red if time_since_contact < jump_grace_period_in_seconds else Color.white
	
	move_and_slide(velocity, Vector2(0, -1))
	rset_unreliable("position", position)

func set_color(_color: Color):
	color = _color
	$sprite.modulate = color

remotesync func spawn_projectile(position, direction, name):
	var projectile = preload("res://examples/physics_projectile/physics_projectile.tscn").instance()
	projectile.set_network_master(1)
	projectile.name = name
	projectile.position = position
	projectile.direction = direction
	projectile.owned_by = self
	get_parent().add_child(projectile)
	return projectile

remotesync func spawn_box(position):
	var box = preload("res://examples/block/block.tscn").instance()
	box.position = position
	get_parent().add_child(box)
	
remotesync func hit(element: Node):
	print("health loss")
	if element.is_in_group("projectiles"):
		health -= element.get_damage()
		emit_signal("health_changed", health)
		element.queue_free()
		if health <= 0:
			pass
			
remotesync func die_and_respawn(player: Player):
	print("Dieeee")
	if (player == self):
		print("Die")
		health = 1.0
		position = Vector2(100, 0)
		velocity = Vector2(0, 0)
		rset_unreliable("position", position)

remotesync func kill():
	hide()

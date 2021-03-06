extends Area2D

var direction: Vector2
var owned_by: Node2D
const speed = 10

func _ready():
	set_physics_process(true)
	
	# wait for a bit then kill the projectile
	if is_network_master():
		yield(get_tree().create_timer(2), "timeout")
		rpc("kill")

func _physics_process(delta):
	position += direction * speed

func _on_projectile_body_entered(body):
	if is_network_master():
		if body != owned_by:
			body.rpc("hit_by_environment", self)

func get_active_item():
	return Item.new(0.2)

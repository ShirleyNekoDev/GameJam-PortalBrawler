extends MeshInstance2D

var initial_rotation
var initial_distance
var last_hit_time = false

const hit_duration = 300.0
const hit_distance = 30.0

func _ready():
	initial_rotation = rotation
	initial_distance = position.distance_to(Vector2(0, 0))
	
func _process(delta):
	if last_hit_time:
		var hit_percentage = (OS.get_ticks_msec() - last_hit_time) / hit_duration
		if hit_percentage > 1.0:
			last_hit_time = false
		else:
			var progress_forwards = hit_percentage * 2
			var progress_backwards = 1 - 2 * (hit_percentage - 0.5)
			var progress = progress_forwards if hit_percentage < 0.5 else progress_backwards
			var eased_progress = pow(progress, 2.5)
			var distance = hit_distance * eased_progress
			var direction = position.normalized()
			position = direction * initial_distance + direction * distance 


func do_hit():
	rpc("do_remote_hit")
	
remotesync func do_remote_hit():
	last_hit_time = OS.get_ticks_msec()

func set_direction(direction: Vector2):
	var angle = direction.normalized().angle_to(Vector2(1, 0))
	var distance = position.distance_to(Vector2(0,0))
	position = Vector2(cos(angle), -sin(angle)) * distance
	rotation = initial_rotation - angle

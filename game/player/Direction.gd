extends MeshInstance2D

var distance
var initial_rotation

func _ready():
	distance = position.distance_to(Vector2(0,0))
	initial_rotation = rotation

func set_direction(direction: Vector2):
	var angle = direction.normalized().angle_to(Vector2(1, 0))
	position = Vector2(cos(angle), -sin(angle)) * distance
	rotation = initial_rotation - angle

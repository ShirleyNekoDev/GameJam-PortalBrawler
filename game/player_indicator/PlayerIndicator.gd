extends MeshInstance2D
class_name PlayerIndicator

const margin = 100
const opacity_change_margin = 140
const opacity_change_offset = 120

var player
var enemy

var initial_rotation
var color = Color(1.0, 1.0, 1.0, 1.0)

func _ready():
	initial_rotation = rotation
	modulate = color
	
func _process(delta):
	if (player and enemy):
		var distance = player.position.distance_to(enemy.position)
		var size = player.get_viewport_rect().size / 2 - Vector2(margin, margin)
		var radius = min(size.x, size.y)
		
		var opacity = clamp((distance - radius - opacity_change_offset) / opacity_change_margin, 0.0, 1.0)
		color.a = opacity
		modulate = color
		
		var direction = (enemy.position - player.position).normalized()
		var angle = direction.angle_to(Vector2(1, 0))
			
		position = direction * radius * 2
		rotation = initial_rotation - angle

func follow_enemy(player, enemy):
	self.player = player
	self.enemy = enemy

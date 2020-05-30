extends Item
class_name HandItem

var radius
var allowed_angle

func _init(damage, radius, allowed_angle).(damage):
	self.radius = radius
	self.allowed_angle = allowed_angle
	
func get_radius():
	return radius

func get_allowed_angle():
	return allowed_angle

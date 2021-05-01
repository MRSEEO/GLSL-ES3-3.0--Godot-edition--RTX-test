extends ColorRect

var pos = Vector3(-5.0, 0.0, 0.0)
var mouse = Vector2(0.0, 0.0)

func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	material.set_shader_param("u_seed1",randf())
	material.set_shader_param("u_seed2",randf())
	
	var velocity = Vector3(0.0, 0.0, 0.0)  
	if Input.is_action_pressed("ui_right"):
		velocity.y += 1
	if Input.is_action_pressed("ui_left"):
		velocity.y -= 1
	if Input.is_action_pressed("ui_down"):
		velocity.x -= 1
	if Input.is_action_pressed("ui_up"):
		velocity.x += 1 
	
	var velocity2 = Vector2()  
	if Input.is_action_pressed("right"):
		velocity2.x += 1
	if Input.is_action_pressed("left"):
		velocity2.x -= 1
	if Input.is_action_pressed("down"):
		velocity2.y += 1
	if Input.is_action_pressed("up"):
		velocity2.y -= 1
	
	mouse += velocity2.normalized() / 50
	
	var temp = Vector3()  
	temp.z = velocity.z * cos(-mouse.y) - velocity.x * sin(-mouse.y)
	temp.x = velocity.z * sin(-mouse.y) + velocity.x * cos(-mouse.y)
	temp.y = velocity.y
	velocity.x = temp.x * cos(mouse.x) - temp.y * sin(mouse.x)
	velocity.y = temp.x * sin(mouse.x) + temp.y * cos(mouse.x)
	velocity.z = temp.z
	
	if Input.is_action_pressed("ui_select"):
		velocity.z -= 1
	if Input.is_action_pressed("ui_shift"):
		velocity.z += 1 
	
	pos += velocity.normalized() / 10
	
	material.set_shader_param("u_pos", pos)
	material.set_shader_param("u_mouse", mouse )

		
		

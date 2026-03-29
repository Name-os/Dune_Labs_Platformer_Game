extends CharacterBody2D


@export var speed       := 250
@export var gravity     := 1100
@export var jump_power  := 500
@export var frame_delay  = 1 #idk what this is

#movement
var dir           := Vector2()
var stamina       := 100 #not in use yet
var speed_mod     := 1.0
var jump_mod      := 1.0
var gravity_mod   := 1.0

#state
#var current_state
#enum states {idle, running, jumping, crouching, climbing}
var crouching     := false
var climbing      := false
var allow_input   := true

#coyote time
var frames_since_on_floor := 0
var coyote_time_limit     := 4

var mod_values = {
	"crouching" : 0.6,
	"climb"     : 1.5,
}

func check_bound(lower, upper, num, equal=false):
	return lower >= num <= upper if equal else lower > num < upper

func animate():
	var animation = ""
	
#	flip the sprite if going left ony if we are moving		
	$AnimatedSprite2D.flip_h = dir.x < 0 if dir.x != 0 else $AnimatedSprite2D.flip_h
	
	if $timers/sleep.is_stopped():
		animation = "sleeping"
		allow_input = false
	elif $timers/sit.is_stopped():
		animation = "sitting"
	elif crouching:
		animation = "crouching_running" if dir.x else "crouching_idle"
	elif climbing:
		animation = "climbing"
	elif not is_on_floor():
		animation = "in_air_up" if velocity.y < 1 else "in_air_down"
	else:	
		animation = "running" if dir.x else "idle"
		
	$AnimatedSprite2D.play(animation)

func toggle_crouch(): #could make more clean
	if crouching:
		$head.disabled = true
		speed_mod = mod_values["crouching"]
	else:
		$head.disabled = false
		speed_mod = 1
#	change head hit box dir based on dir
	$head.position.x = (-1.0 if dir.x < 1 else 3.0) if dir.x != 0 else $head.position.x

func update_timers():
	if dir:
		$timers/sit.start()
		$timers/sleep.start()

func new_input():
	jump_mod = 1
	gravity_mod = 1
	climbing = false

	#Climbing button + up or down = up or down movement
	#Climbing button + jump + no directional input  that is left or right = Jump up while on a wall
	#Climbing button + jump + directional input = Jump in the direction of the input
	#Climbing button + on wall = Grip onto wall
	#No climbing button + walking into wall = slide down wall at constant speed
	#No climbing button + not walking into wall = freefall

	#if not allow_input:
		#return
		
	dir = Input.get_vector("left","right","up","down")
	var input_map = {
		"up"     : Input.is_action_pressed("up"),
		"down"   : Input.is_action_pressed("down"),
		"climb"  : Input.is_action_pressed("climb"),
		"jump"   : Input.is_action_just_pressed("jump")
	}
	if input_map["climb"] and is_on_wall():
		climbing = true
		speed_mod = mod_values["climb"]
		
		if input_map["jump"] and not dir.x:
			jump_mod = 1.5
			velocity.y = -jump_power * jump_mod
			


##		jump off wall
		#elif input_map["jump"] and dir.x:
			#climbing = false
			#velocity.y = -jump_power
##		going up or down
		#elif not input_map["jump"] and dir.y:
			#velocity.y += dir.y * speed * speed_mod
	elif input_map["jump"] and (is_on_floor() or frames_since_on_floor <= coyote_time_limit):
		velocity.y = -jump_power
	elif input_map["down"] and is_on_floor():
		crouching = true	
	elif not $head/ShapeCast2D.is_colliding(): #not allow uncrouch if head is clipped
		crouching = false
		
func get_input():
	jump_mod = 1
	climbing = false
	
	if allow_input:
		dir.x = Input.get_axis("left", "right")
		var input_map = {
			"up"     : Input.is_action_pressed("up"),
			"climb"  : Input.is_action_pressed("climb"),
			"down"   : Input.is_action_pressed("down"),
		}
		if input_map["climb"]:
			if is_on_wall() and dir.x != 0:
				climbing = true
				speed_mod = 0.5
				velocity.y = Input.get_axis("up", "down") * speed * speed_mod #overide the y vel
		elif input_map["up"] and (is_on_floor() or frames_since_on_floor <= coyote_time_limit):
			velocity.y = -jump_power
		elif input_map["down"] and is_on_floor():
			crouching = true
		elif not $head/ShapeCast2D.is_colliding(): #not allow uncrouch if head is clipped
			crouching = false

func update_vel(delta):
	# y axis
	if not is_on_floor():
		velocity.y += gravity * delta * gravity_mod

	if climbing:
		if velocity.y != 0:
			velocity.y += gravity * delta
			if velocity.y > 0:
				velocity.y = 0

	# X axis 
	velocity.x = dir.x * speed

func _physics_process(delta: float) -> void:
	new_input()
	update_timers()
	frames_since_on_floor = 0 if is_on_floor() or climbing else frames_since_on_floor+1 #update frames since on floor
	toggle_crouch()
	animate() #animate based on state
	update_vel(delta) #update the player vel
	move_and_slide() #update position and adds delta
	position = Vector2i(round(position/4))*4 #make movement pixel perfect
	
	
#camera values:
# left: 0
# bottom: 736

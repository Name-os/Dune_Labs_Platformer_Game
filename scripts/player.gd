extends CharacterBody2D

@export var speed      := 250
@export var gravity    := 1100
@export var jump_power := 500

#movement
var dir                 := Vector2()
var speed_mod           := 1.0
var gravity_mod         := 1.0
var velocity_last_frame := Vector2.ZERO

#stamina costs
var stamina_max            := 100.0
var stamina                := stamina_max
var stamina_drain_climb    := 18.0
var stamina_drain_grip     := 12.0
var stamina_cost_wall_jump := 20.0

#state
var crouching           := false
var climbing            := false
var climbing_moving     := false
var allow_input         := true
var was_on_floor        := false

#transition frame timers
var land_frames   := 0
var jump_frames   := 0
var land_duration := 13
var jump_duration := 3

#heavy landing threshold
var land_velocity_threshold := 800.0

#coyote time
var frames_since_on_floor := 0
var coyote_time_limit     := 4

#wall jump cooldown
var wall_jump_cooldown := 10

#springshroom related stuff
var shroom_jump_radius := 40;
var springshrooms := []

#checkpoints and teleport points
var last_checkpoint := Vector2()

var mod_values = {
	"crouching" : 0.6,
	"climb"     : 1.5,
	"shroom_jump": 1.5,
}

func _ready():
	shroom_jump_radius *= shroom_jump_radius #for faster distance calculations due to no need for square roots
	for shroom in get_tree().get_nodes_in_group("springshroom"):
		springshrooms.append(shroom)

func _on_hurtbox_area_entered(_area: Area2D) -> void:
	print("fergeg")
	position = last_checkpoint

func cap(value, min_val, max_val): #may be brokens
	value = min(value, max_val) if max_val else value
	value = max(value, min_val) if min_val else value
	return value

func animate(): #could prbly optimise
	$AnimatedSprite2D.flip_h = dir.x < 0 if dir.x != 0 else $AnimatedSprite2D.flip_h
	var animation = ""
	if $timers/sleep.is_stopped():
		animation = "sleeping"
	elif $timers/sit.is_stopped():
		animation = "sitting"
	elif crouching:
		animation = "crouching_running" if dir.x and not $body/ShapeCast2D.is_colliding() else "crouching_idle"
	elif climbing:
		animation = "climbing"
	elif land_frames > 0:
		$AnimatedSprite2D.play("jumping")
		$AnimatedSprite2D.frame = 6
		return
	elif jump_frames > 0:
		$AnimatedSprite2D.play("jumping")
		$AnimatedSprite2D.frame = 2
		return
	elif not is_on_floor():
		$AnimatedSprite2D.play("jumping")
		if velocity.y < -100:
			$AnimatedSprite2D.frame = 3
		elif velocity.y < 0:
			$AnimatedSprite2D.frame = 4
		else:
			$AnimatedSprite2D.frame = 5
		return
	else:
		animation = "running" if dir.x and not $body/ShapeCast2D.is_colliding() else "idle"
		
	$AnimatedSprite2D.play(animation)

func toggle_crouch():
	$head.disabled = crouching
	speed_mod = mod_values["crouching"] if crouching else 1.0
	$head.position.x = (-1.0 if dir.x < 0 else 3.0) if dir.x != 0 else $head.position.x

func update_timers():
	if dir or climbing or velocity.y != 0:
		$timers/sit.start()
		$timers/sleep.start()
		
	#for timer debugging		
	#print(str($timers/sit.time_left) + "   " + str($timers/sleep.time_left))
	
func update_stamina(delta):
	if is_on_floor():
		stamina = stamina_max
	elif climbing:
		if climbing_moving:
			stamina -= stamina_drain_climb * delta
		else:
			stamina -= stamina_drain_grip * delta
			
		stamina = cap(stamina, 0, null) #may be broken

func force_state_update():
	if not is_on_floor():
		crouching = false
	if climbing and crouching:
		push_error("2 states are active at the same time")

func climb(im):
	if stamina <= 0:
		climbing = false
		return
		
	climbing = true
	speed_mod = mod_values["climb"]

	if im["jump"]:
		climbing = false
		wall_jump_cooldown = 15
		jump_frames = jump_duration
		stamina -= stamina_cost_wall_jump
		stamina = cap(stamina, 0, null) #may be broken

		var ratio = cap(stamina / stamina_cost_wall_jump, null, 1.0) #may be broken

		velocity.x = dir.x * speed if dir.x else velocity.x
		velocity.y = -jump_power * ratio
	elif dir.y:
		climbing_moving = true
		velocity.y = speed * dir.y
	else:
		velocity.y = 0
		
func get_input():
	#experimental
	if Input.is_action_just_pressed("checkpoint"):
		last_checkpoint = position
	
	if not allow_input:
		return
	gravity_mod = 1.0
	climbing_moving = false
	if not is_on_floor():
		crouching = false
	if wall_jump_cooldown <= 0:
		climbing = false

	dir.x = Input.get_axis("left", "right")
	dir.y = Input.get_axis("up", "down")
	
	var im = {
		"up"    : Input.is_action_pressed("up"),
		"down"  : Input.is_action_pressed("down"),
		"climb" : Input.is_action_pressed("climb"),
		"jump"  : Input.is_action_just_pressed("jump")
	}

	if im["climb"] and $body/ShapeCast2D.is_colliding() and wall_jump_cooldown <= 0 and not $head/ShapeCast2D.is_colliding():
		climb(im)
	elif not $head/ShapeCast2D.is_colliding(): #dont allow certain things if head is clipped
		if im["jump"] or velocity.y > 0:
			for shroom in springshrooms: #could optimise using different nodes #springshroom jumping
				if position.distance_squared_to(shroom.position) <= shroom_jump_radius:
					velocity.y = -jump_power * mod_values["shroom_jump"]
					shroom.play("spring")
					return
		if im["jump"] and (is_on_floor() or frames_since_on_floor <= coyote_time_limit):
			velocity.y = -jump_power
			jump_frames = jump_duration #may need to add to shroom bit
		else:
			crouching = im["down"] and is_on_floor() and not im["climb"]

func update_vel(delta):
	if not is_on_floor() and not climbing:
		velocity.y += gravity * delta * gravity_mod
	if land_frames > 0:
		velocity.x = 0
	else:
		velocity.x = dir.x * speed * speed_mod

func _physics_process(delta: float) -> void:
	if land_frames <= 0:
		allow_input = true

	frames_since_on_floor = 0 if is_on_floor() else frames_since_on_floor + 1
	get_input()
	force_state_update()
	update_stamina(delta)
	update_timers()
	toggle_crouch()
	update_vel(delta)
	velocity_last_frame = velocity
	move_and_slide()

	# detect landing right before animate so land_frames is set before animate reads it
	if is_on_floor() and not was_on_floor:
		if velocity_last_frame.y >= land_velocity_threshold:
			land_frames = land_duration
			allow_input = false
			jump_frames = 0

	animate()
	was_on_floor = is_on_floor()

	land_frames = land_frames - 1 if land_frames > 0 else land_frames
	jump_frames = jump_frames - 1 if jump_frames > 0 else jump_frames
	wall_jump_cooldown = wall_jump_cooldown - 1 if wall_jump_cooldown > 0 else wall_jump_cooldown

#camera values:
# left: 0
# bottom: 736

extends CharacterBody2D

@export var speed      := 250
@export var gravity    := 1100
@export var jump_power := 500

#movement
var dir         := Vector2()
var stamina     := 100.0
var speed_mod   := 1.0
var gravity_mod := 1.0

#stamina costs
var stamina_drain_climb    := 20.0
var stamina_drain_grip     := 10.0
var stamina_cost_wall_jump := 40.0

#state
var crouching           := false
var climbing            := false
var allow_input         := true
var on_floor_last_frame := false

#coyote time
var frames_since_on_floor := 0
var coyote_time_limit     := 4

#wall jump cooldown
var wall_jump_cooldown := 0

var mod_values = {
	"crouching" : 0.6,
	"climb"     : 1.5
}

func check_bound(lower, upper, num, equal=false):
	return lower >= num <= upper if equal else lower > num < upper

func animate():
	$AnimatedSprite2D.flip_h = dir.x < 0 if dir.x != 0 else $AnimatedSprite2D.flip_h

	var animation = "sleeping" if $timers/sleep.is_stopped() else \
					"sitting"  if $timers/sit.is_stopped()   else \
					("crouching_running" if dir.x else "crouching_idle") if crouching else \
					"climbing" if climbing else \
					("in_air_up" if velocity.y < 1 else "in_air_down") if not is_on_floor() else \
					("running" if dir.x else "idle")

	$AnimatedSprite2D.play(animation)

func toggle_crouch():
	$head.disabled = crouching
	speed_mod = mod_values["crouching"] if crouching else 1.0
	if dir.x != 0:
		$head.position.x = -1.0 if dir.x < 1 else 3.0

func update_timers():
	if not dir and not climbing:
		$timers/sit.start()
		$timers/sleep.start()

func update_stamina(delta):
	if is_on_floor() and on_floor_last_frame:
		stamina = 100.0
	elif climbing:
		stamina = max(0, stamina - (stamina_drain_climb if dir.y else stamina_drain_grip) * delta)

func get_input_map() -> Dictionary:
	return {
		"up"    : Input.is_action_pressed("up"),
		"down"  : Input.is_action_pressed("down"),
		"climb" : Input.is_action_pressed("climb"),
		"jump"  : Input.is_action_just_pressed("jump")
	}

func new_input(_delta):
	gravity_mod = 1.0
	if not is_on_floor():
		crouching = false
	if wall_jump_cooldown <= 0:
		climbing = false

	dir = Input.get_vector("left", "right", "up", "down")
	var im = get_input_map()

	if im["climb"] and $body/ShapeCast2D.is_colliding() and wall_jump_cooldown <= 0:
		if stamina > 0:
			climbing = true
			speed_mod = mod_values["climb"]

			if im["jump"]:
				climbing = false
				wall_jump_cooldown = 15
				if dir.x:
					# jump away - no stamina cost
					velocity = Vector2(-dir.x * speed, -jump_power)
				else:
					# jump straight up - costs stamina
					var ratio = min(1.0, stamina / stamina_cost_wall_jump)
					velocity.y = -jump_power * ratio
					stamina = max(0, stamina - stamina_cost_wall_jump)
			elif dir.y:
				velocity.y = dir.y * speed * speed_mod * (0.5 if dir.y < 0 else 1.0)
			else:
				velocity.y = 0
		else:
			climbing = false
			if im["jump"]:
				pass

	elif im["jump"] and (is_on_floor() or frames_since_on_floor <= coyote_time_limit):
		velocity.y = -jump_power
	elif im["down"] and is_on_floor():
		crouching = true
	elif not $head/ShapeCast2D.is_colliding():
		crouching = false

func update_vel(delta):
	if not is_on_floor() and not climbing:
		velocity.y += gravity * delta * gravity_mod
	velocity.x = dir.x * speed * speed_mod

func _physics_process(delta: float) -> void:
	new_input(delta)
	update_stamina(delta)
	update_timers()
	on_floor_last_frame = is_on_floor()
	frames_since_on_floor = 0 if is_on_floor() else frames_since_on_floor + 1
	toggle_crouch()
	animate()
	update_vel(delta)
	move_and_slide()
	position = Vector2i(round(position / 4)) * 4

	if wall_jump_cooldown > 0:
		wall_jump_cooldown -= 1

#camera values:
# left: 0
# bottom: 736

extends CharacterBody2D

@export var speed := 80.0
var gravity := 1100.0
var direction := 1.0

func _ready():
	$AnimatedSprite2D.play("default")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	if $"Wall Check".is_colliding() or not $"Floor Check".is_colliding():
		direction *= -1.0
		$"Wall Check".target_position.x *= -1
		$"Floor Check".position.x *= -1
		$AnimatedSprite2D.flip_h = direction < 0

	velocity.x = speed * direction
	move_and_slide()

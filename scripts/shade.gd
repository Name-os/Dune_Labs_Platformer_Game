extends CharacterBody2D


@export var speed = 250

#var current_state
var dir_x = 0

func animate():
	var animation = ""
	
#	flip the sprite if going left ony if we are moving		
	$AnimatedSprite2D.flip_h = dir_x < 0 if dir_x != 0 else $AnimatedSprite2D.flip_h
	animation = "running" if dir_x else "idle"
	$AnimatedSprite2D.play(animation)

func _physics_process(_delta: float) -> void:
	dir_x = get_tree().get_nodes_in_group("player")[0].dir.x
	velocity.x = dir_x * speed
	animate() #animate based on state
	move_and_slide() #update position and adds delta

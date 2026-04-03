extends AnimatedSprite2D



#var player_is_toucing := false
#
#func _on_area_entered(_area: Area2D) -> void:
	#player_is_toucing = true
#
#func _on_area_exited(_area: Area2D) -> void:
	#player_is_toucing = false
#
#func _physics_process(_delta: float) -> void:
	#if player_is_toucing and Input.is_action_just_pressed("jump"):
		#get_tree().get_nodes_in_group("player")[0].velocity.y = -get_tree().get_nodes_in_group("player")[0].jump_power * 10

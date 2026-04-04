extends TileMapLayer

@export var player: Node2D

func _process(_delta):
	var vp_transform = get_viewport().get_canvas_transform()
	var converted = vp_transform * player.global_position
	material.set_shader_parameter("player_pos", converted)

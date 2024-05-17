extends StaticBody2D

@onready var despawn_timer = $DespawnTimer
@onready var sprite_2d = $Sprite2D
@onready var collision_shape_2d = $CollisionShape2D
@onready var area_2d = $Area2D
@onready var respawn_timer = $RespawnTimer

@onready var falling_text = preload("res://assets/pixelPlatformer/black_9slice.png")
@onready var ready_text = preload("res://assets/pixelPlatformer/white_9slice.png")

func _on_area_2d_body_entered(body):
	if despawn_timer.time_left <= 0.0:
		despawn_timer.start()
		sprite_2d.texture = falling_text


func _on_despawn_timer_timeout():
	sprite_2d.hide()
	collision_shape_2d.disabled = true
	area_2d.monitoring = false
	respawn_timer.start()


func _on_respawn_timer_timeout():
	sprite_2d.show()
	collision_shape_2d.disabled = false
	area_2d.monitoring = true
	sprite_2d.texture = ready_text

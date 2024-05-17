extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var coyote_jump_timer = $CoyoteJumpTimer
@onready var jump_buffer_timer = $JumpBufferTimer
@onready var left_ray_cast_2d = $LeftRayCast2D
@onready var right_ray_cast_2d = $RightRayCast2D
@onready var uncapped_speed_timer = $UncappedSpeedTimer
@onready var no_control_timer = $NoControlTimer
@onready var animation_player = $AnimationPlayer
@onready var left_up_ray_cast_2d = $LeftUpRayCast2D
@onready var right_up_ray_cast_2d = $RightUpRayCast2D
@onready var dash_timer = $DashTimer
@onready var dash_floor_stop_timer = $DashFloorStopTimer
@onready var speed_particles_2d = $SpeedParticles2D
@onready var floor_ray_cast_2d = $FloorRayCast2D


const SPEED = 60.0
const ACCELERATION = 300.0
const NO_CONTROL_ACCELERATION = 10.0
const FRICTION = 600.0
const GRAVITY = 250.0
const GRAVITY_MAX = 150.0
const WALL_SLIDE_GRAVITY = 125.0
const JUMP_STR = -150.0
const WALL_JUMP_STR = -90.0
const WALL_JUMP_SUPER_LENGTH = 0.3
const WALL_PUSH_STR = 180.0
const GROUND_POUND_STR = 300.0
const GROUD_POUND_JUMP_STR = -200.0
const SUPER_SPEED_THRESHOLD = 170.0
const DASH_SPEED = 180.0
const DASH_TIMER_LENGTH = 0.35

var is_wall_sliding = false
var dead = false

#func _ready():
	#print(Vector2(SPEED, JUMP_STR).length())

func _physics_process(delta):
	if dead: return
	var was_wall_sliding = is_wall_sliding
	is_wall_sliding = (is_on_wall() or left_ray_cast_2d.is_colliding() or left_up_ray_cast_2d.is_colliding() or right_ray_cast_2d.is_colliding() or right_up_ray_cast_2d.is_colliding()) and not (is_on_floor() or floor_ray_cast_2d.is_colliding())
	
	if is_on_floor() and dash_timer.time_left > 0.0 and dash_floor_stop_timer.time_left <= 0.0:
		dash_floor_stop_timer.start()
	
	apply_gravity(delta, is_wall_sliding, was_wall_sliding)
	var input_axis = Input.get_axis("move_left", "move_right")
	handle_acceleration(delta, input_axis)
	var dash_input = Input.is_action_just_pressed("dash")
	var down_input = Input.is_action_pressed("down")
	handle_dash(dash_input, down_input, input_axis)
	var jump_input = Input.is_action_just_pressed("jump")
	handle_jump(jump_input, is_wall_sliding)
	update_animations(input_axis)
	
	var was_on_floor = is_on_floor()
	move_and_slide()
	if was_on_floor and not is_on_floor():
		coyote_jump_timer.start()
	
	if velocity.length() > SUPER_SPEED_THRESHOLD:
		speed_particles_2d.emitting = true
		speed_particles_2d.initial_velocity_max = velocity.length() + 10.0
		speed_particles_2d.initial_velocity_min = velocity.length() - 10.0
		speed_particles_2d.direction = -(velocity / 2).normalized()
	else:
		speed_particles_2d.emitting = false

func apply_gravity(delta, is_wall_sliding, was_wall_sliding):
	if not is_on_floor():
		if is_wall_sliding:
			if was_wall_sliding:
				if velocity.y > 0.0:
					velocity.y = move_toward(velocity.y, GRAVITY_MAX, WALL_SLIDE_GRAVITY * delta)
				else:
					if dash_timer.time_left <= 0.0:
						velocity.y = move_toward(velocity.y, GRAVITY_MAX, GRAVITY * delta)
			else:
				velocity.y = min(velocity.y, WALL_SLIDE_GRAVITY)
		else:
			if dash_timer.time_left <= 0.0:
				velocity.y = move_toward(velocity.y, GRAVITY_MAX, GRAVITY * delta)
	else:
		velocity.y = 0.0

func handle_acceleration(delta, input_axis):
	if input_axis:
		if uncapped_speed_timer.time_left <= 0.0:
			if sign(velocity.x) == sign(input_axis) or velocity.x == 0.0:
				velocity.x = move_toward(velocity.x, SPEED * input_axis, ACCELERATION * delta)
			else:
				velocity.x = move_toward(velocity.x, SPEED * input_axis, (ACCELERATION + FRICTION) * delta)
		else:
			var acceleration = ACCELERATION
			if no_control_timer.time_left > 0.0:
				acceleration = NO_CONTROL_ACCELERATION
			if sign(velocity.x) == sign(input_axis) or velocity.x == 0.0:
				velocity.x += acceleration * delta * input_axis
			else:
				velocity.x += (acceleration + FRICTION) * delta * input_axis
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

func handle_dash(dash_input, down_input, input_axis):
	if dash_input and down_input and not is_on_floor():
		dash_timer.start()
		velocity.y = GROUND_POUND_STR
		velocity.x = sign(velocity.x) * 50.0
	elif dash_input and input_axis and is_on_floor():
		velocity.x = DASH_SPEED * input_axis
		uncapped_speed_timer.start(DASH_TIMER_LENGTH)

func handle_jump(jump_input, is_wall_sliding):
	if jump_input or jump_buffer_timer.time_left > 0.0:
		if is_on_floor() or coyote_jump_timer.time_left > 0.0:
			jump_buffer_timer.stop()
			coyote_jump_timer.stop()
			if dash_timer.time_left <= 0.0:
				velocity.y = JUMP_STR
			else:
				velocity.y = GROUD_POUND_JUMP_STR
		elif jump_buffer_timer.time_left <= 0.0:
			jump_buffer_timer.start()
	else:
		if Input.is_action_just_released("jump") and velocity.y < JUMP_STR / 2:
			velocity.y = JUMP_STR / 2
	
	if is_wall_sliding and jump_input:
		var wall_normal
		if left_ray_cast_2d.is_colliding():
			wall_normal = left_ray_cast_2d.get_collision_normal()
		elif left_up_ray_cast_2d.is_colliding():
			wall_normal = left_up_ray_cast_2d.get_collision_normal()
		elif right_ray_cast_2d.is_colliding():
			wall_normal = right_ray_cast_2d.get_collision_normal()
		elif right_up_ray_cast_2d.is_colliding():
			wall_normal = right_up_ray_cast_2d.get_collision_normal()
		else:
			wall_normal = get_wall_normal()
		velocity.y = WALL_JUMP_STR
		velocity.x = wall_normal.x * WALL_PUSH_STR
		uncapped_speed_timer.start(WALL_JUMP_SUPER_LENGTH)
		no_control_timer.start(WALL_JUMP_SUPER_LENGTH)

func update_animations(input_axis):
	animated_sprite_2d.speed_scale = velocity.x / SPEED
	if input_axis:
		animated_sprite_2d.flip_h = input_axis < 0.0
	if is_on_floor():
		if input_axis:
			animated_sprite_2d.play("Run")
		else:
			animated_sprite_2d.play("Idle")
	else:
		animated_sprite_2d.play("Jump")


func _on_area_2d_area_entered(area):
	dead = true
	velocity = Vector2.ZERO
	animation_player.play("Death")


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "Death":
		get_tree().reload_current_scene()


func _on_dash_floor_stop_timer_timeout():
	dash_timer.stop()

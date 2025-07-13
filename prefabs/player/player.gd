# https://github.com/AlayandeWork/TheSideScroller/tree/main
extends CharacterBody2D

@export_group("Attack/Defense")
# Player Status
@export var playerHealth = 100
@export var attackDamage = 20

# @onready var main_progress_bar = $"../CanvasLayer/ProgressBar"

# Player Movement Constants
@export_group("Movement")
@export var speed = 190
@export var jumpPower = 370
@export var gravity = 1000
@export var knockBackForce = 150

@export_group("Zoom")
@export var zoom_levels = [0.25, 0.5, 1, 1.25, 1.5]
var current_zoom_level = 0

@onready var camera_2d = get_node("Camera2D")

# State Variables
var currentDirection = 1
var playerAttacking = false
var isDead = false
var isHit = false
var health_increase = false

var isJumping = false
var isFalling = false

func _ready() -> void:
	release_mouse_cursor()
	set_zoom(1)

func debugmsg() -> String:
	var msg = "Player Debug Info:"
	msg += "\n"
	msg += "pos: %3.2f/%3.2f" % [position.x, position.y]
	msg += "\n"
	msg += "currentDir: %d" % [currentDirection]
	msg += "\n"
	msg += "onfloor: %s" % [is_on_floor()]
	msg += "\n"
	msg += "onceil: %s" % [is_on_ceiling()]
	msg += "\n"
	msg += "jumping: %s" % [isJumping]
	msg += "\n"
	msg += "falling: %s" % [isFalling]
	msg += "\n"
	return msg


func detect_below() -> void:
	
	pass

func get_player_tile() -> void:
	var player_pos = self.position
	var tilemap_layer = %TileMapLayer
	# var cell_coords = tilemaplayer.local_to_map(tilemaplayer.to_local(player_pos))
	var cell_coords = tilemap_layer.local_to_map(tilemap_layer.to_local(player_pos))
	var tile_data = tilemap_layer.get_cell_tile_data(cell_coords)
	print(str(tile_data))
	if tile_data:
		print("Zelle ", cell_coords, " enthält Tile-ID: ", tile_data.get_tile_id())
	else:
		print("Zelle ", cell_coords, " ist leer.")
	print("pos %s - %s" % [str(player_pos), str(cell_coords)])



func paint_debug_msg() -> void:
	%PlayerDebugInfo.text = debugmsg()

func release_mouse_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func set_zoom(zoomlevel: int) -> void:
	current_zoom_level = zoomlevel
	current_zoom_level = clampf(current_zoom_level, 0, zoom_levels.size() - 1)
	print("Setting zoom lvl to %f - %f" % [current_zoom_level, zoom_levels[current_zoom_level]])
	camera_2d.zoom = Vector2(zoom_levels[current_zoom_level], zoom_levels[current_zoom_level])

func _process(delta: float):
	paint_debug_msg()
	get_player_tile()
	if health_increase and playerHealth < 100:
		playerHealth += 10 * delta
		if playerHealth >= 100:
			playerHealth = 100
		print("new player health = ", playerHealth)

func _physics_process(delta):
	# player_health_update()
	# Apply gravity if in the air
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if isHit:
		apply_knockback(delta)
	
	# Zoom
	if Input.is_action_just_pressed("zoom_in_camera"):
		set_zoom(current_zoom_level + 1)

	if Input.is_action_just_pressed("zoom_out_camera"):
		set_zoom(current_zoom_level - 1)

	# Player movement
	var playerDirection = Input.get_axis("move_left", "move_right")
	
	# Check player is on the floor
	if is_on_floor() and not isDead and not isHit:
		if Input.is_action_just_pressed("jump") and not playerAttacking:
			velocity.y = - jumpPower
			$AnimationPlayer.play("Jump")
			isJumping = true
		elif playerDirection and not playerAttacking:
			move_horizontally(playerDirection)
			isJumping = false
		else:
			idle_animation()

		isJumping = false
		isFalling = false
	else:
		if not isDead and not isHit:
			if velocity.y > 0:
				isFalling = true
				isJumping = false
			else:
				isJumping = true
				isFalling = false

			$AnimationPlayer.play("Fall" if velocity.y > 0 else "Jump")
			
	if Input.is_action_just_pressed("primary_weapon") and is_on_floor() and not isDead and not isHit:
		playerAttacking = true
		$AnimationPlayer.play("attackRight" if currentDirection > 0 else "attackLeft")
			
	move_and_slide()
		
func move_horizontally(direction):
	velocity.x = speed * direction
	currentDirection = sign(direction)
	$AnimationPlayer.play("rightRun" if currentDirection > 0 else "leftRun")
		
func idle_animation():
	velocity.x = 0
	if not playerAttacking:
		$AnimationPlayer.play("IdleRight" if currentDirection > 0 else "IdleLeft")
		
# Function for animation finished
func _on_animation_player_animation_finished(anim_name):
	if anim_name in ["attackRight", "attackLeft"]:
		playerAttacking = false
	elif anim_name == "Death":
		get_tree().reload_current_scene()
	elif anim_name == "Hit":
		isHit = false

func _on_area_2d_area_entered(area):
	if area.is_in_group("enemygroup") and playerAttacking:
		area.get_parent().take_damage(attackDamage)
	
# Function for player damage	
func take_damage(damage_amount):
	if isDead:
		return
	playerHealth -= damage_amount
	print(playerHealth)
	
	if playerHealth <= 0:
		die()
	else:
		isHit = true
		$AnimationPlayer.play("Hit")
		initial_knockback()
			
# Function for player death	
func die():
	isDead = true
	$AnimationPlayer.play("Death")

# Function for player health update
# func player_health_update():
# 	main_progress_bar.value = playerHealth

func initial_knockback():
	velocity.x = - knockBackForce * currentDirection

func apply_knockback(delta):
	velocity.x = lerp(velocity.x, 0.0, 5 * delta)

func _on_health_zone_body_entered(body):
	if body.name == "Player":
		health_increase = true
		
func _on_health_zone_body_exited(body):
	if body.name == "Player":
		health_increase = false

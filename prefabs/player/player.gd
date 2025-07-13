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
@export var max_jumps = 2
var jumps: int = 0
@export var gravity = 1000
@export var knockBackForce = 150

@export_group("Zoom")
@export var zoom_levels = [0.25, 0.5, 1, 1.25, 1.5]
var current_zoom_level = 0

@export_category("Inventory")
@export var generator: Resource
@export var inventory_menu := NodePath()
@export var inventory_tooltip := NodePath()
@export var ground_items := NodePath()

var _mouse_pressed := false

@export_category("Debug")
@export var show_debug_info: bool = true

@onready var camera_2d = get_node("Camera2D")

# State Variables
var currentDirection = 1
var playerAttacking = false
var isDead = false
var isHit = false
var health_increase = false

var isJumping = false
var isFalling = false

@onready var tilemap_layer: TileMapLayer = %TileMapLayer
var original_tile_id: int
var highlight_tile_id: int = 7 # Ersetzen Sie dies mit der ID Ihres Highlight-Tiles
var tilemaplayer_position: Vector2i

func _ready() -> void:
	release_mouse_cursor()
	set_zoom(2)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		_mouse_pressed = event.is_pressed()

	if event.is_action(&"ui_cancel") && event.is_pressed():
		get_node(inventory_menu).hide()

	if event.is_action(&"menu_inventory") && event.is_pressed():
		get_node(inventory_menu).visible = !get_node(inventory_menu).visible
		get_node(inventory_tooltip).visible = false

func _on_Generator_pressed():
	var item_manager = get_node(ground_items)
	for i in 8:
		for x in generator.get_items():
			item_manager.add_item(x, global_position)

func _on_ItemPickup_area_entered(area: Area2D):
	if area.is_in_group(&"ground_item") && !area.filter_hidden:
		# Inventory? Inventory. Don't hard-code paths, kids.
#		area.try_pickup($"../../../Inventory/Inventory/Inventory".inventory)
		area.try_pickup(get_node(inventory_menu).main_inventory)

func _on_inworld_inv_button_pressed(inventory_view: Control, inventory_name: String):
		get_node(inventory_menu).open_inworld_inventory(inventory_view, inventory_name)

func _on_items_item_clicked(item_node: Node):
	_on_ItemPickup_area_entered(item_node)

func debugmsg() -> String:
	var msg = "Player Debug Info:"
	var tile_position: Vector2i = get_tilemaplayer_position()

	msg += "\n"
	msg += "pos: %3.2f/%3.2f" % [position.x, position.y]
	msg += "\n"
	msg += "pos2: %3.2f/%3.2f" % [tile_position.x, tile_position.y]
	msg += "\n"
	msg += "Y-Force: %3.2f" % [velocity.y]
	msg += "\n"
	msg += "currentDir: %d" % [currentDirection]
	msg += "\n"
	msg += "zoom: %3.2f" % [zoom_levels[current_zoom_level]]
	msg += "\n"
	msg += "isonfloor: %s" % [is_on_floor()]
	msg += "\n"
	msg += "isonceil: %s" % [is_on_ceiling()]
	msg += "\n"
	msg += "isjumping: %s" % [isJumping]
	msg += "\n"
	msg += "jumps: %d/%d" % [jumps, max_jumps]
	msg += "\n"
	msg += "isfalling: %s" % [isFalling]
	msg += "\n"
	msg += "isHit: %s" % [isHit]
	msg += "\n"
	msg += "isDead: %s" % [isDead]
	msg += "\n"
	return msg

func highlight_cell(_x: int, _y: int, duration: float = 2.0):
	var cell_coords = get_tilemaplayer_position()

	var tile_data = tilemap_layer.get_cell_tile_data(cell_coords)
	print(str(tile_data))

	# Setzen Sie die Zelle auf den Highlight-Tile
	tilemap_layer.set_cell(cell_coords, 0, Vector2i(0, 7))
	
	# Timer, um den Tile nach der gewünschten Zeit zurückzusetzen
	var timer = Timer.new()
	timer.wait_time = duration
	# timer.timeout.connect(_on_Timer_timeout, ["x", "y"])
	timer.timeout.connect(_on_Timer_timeout)
	add_child(timer)
	timer.start()

func _on_Timer_timeout(x: int, y: int):
	# Setzen Sie die Zelle zurück auf den ursprünglichen Tile
	# tilemap_layer.tilemap.set_cell(x, y, original_tile_id)
	tilemap_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 1))
	queue_free() # Optional: Timer entfernen

func get_tilemaplayer_position() -> Vector2i:
	tilemaplayer_position = tilemap_layer.local_to_map(tilemap_layer.to_local(self.position))
	return tilemaplayer_position

func detect_below() -> void:
	pass

func get_player_tile() -> void:
	var cell_coords = get_tilemaplayer_position()
	var tile_data = tilemap_layer.get_cell_tile_data(cell_coords)
	#print(str(tile_data))
	if tile_data:
		print("Zelle ", cell_coords, " enthält Tile-ID: ", tile_data.get_tile_id())
	else:
		print("Zelle ", cell_coords, " ist leer.")
	#print("pos %s - %s" % [str(self.position), str(cell_coords)])

func paint_debug_msg() -> void:
	%PlayerDebugInfo.text = debugmsg()

func release_mouse_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func set_zoom(zoomlevel: int) -> void:
	current_zoom_level = zoomlevel
	current_zoom_level = clampf(current_zoom_level, 0, zoom_levels.size() - 1)
	# print("Setting zoom lvl to %f - %f" % [current_zoom_level, zoom_levels[current_zoom_level]])
	camera_2d.zoom = Vector2(zoom_levels[current_zoom_level], zoom_levels[current_zoom_level])

func _process(delta: float):
	paint_debug_msg()
	# get_player_tile()
	if health_increase and playerHealth < 100:
		playerHealth += 10 * delta
		if playerHealth >= 100:
			playerHealth = 100
		print("new player health = ", playerHealth)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		toggle_debug_info()

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

	if is_on_floor():
		isFalling = false
		isJumping = false
		jumps = 0

	# Check player is on the floor
	if not isDead and not isHit:
		if playerDirection:
			move_horizontally(playerDirection)
		else:
			idle_animation()

		if jumps < max_jumps:
			if Input.is_action_just_pressed("jump"):
				velocity.y = - jumpPower
				jumps += 1
				isJumping = true
				$AnimationPlayer.play("Jump")

		if not is_on_floor():
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

func toggle_debug_info() -> void:
	show_debug_info = !show_debug_info

	if show_debug_info:
		%DebugPanel.show()
	else:
		%DebugPanel.hide()

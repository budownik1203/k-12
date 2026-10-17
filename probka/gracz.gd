extends CharacterBody3D
## Prosty kontroler FPS do oglądania próbki.
## WSAD ruch, Shift bieg, Ctrl kucanie, F latarka, LPM łapie mysz, Esc ją puszcza.

@export var walk_speed := 2.6
@export var run_speed := 4.6
@export var crouch_speed := 1.4
@export var mouse_sens := 0.0022
@export var stand_height := 1.62
@export var crouch_height := 1.0

@onready var head: Node3D = $Glowa
@onready var camera: Camera3D = $Glowa/Kamera
@onready var flashlight: SpotLight3D = $Glowa/Kamera/Latarka

var controls_enabled := true
var _bob := 0.0
var _gravity := 9.8


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F:
				flashlight.visible = not flashlight.visible
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		head.rotate_x(-event.relative.y * mouse_sens)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return
	var crouch := Input.is_key_pressed(KEY_CTRL)
	var run := Input.is_key_pressed(KEY_SHIFT) and not crouch
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir.z -= 1
	if Input.is_key_pressed(KEY_S): dir.z += 1
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	dir = (transform.basis * dir).normalized()
	var speed := crouch_speed if crouch else (run_speed if run else walk_speed)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	move_and_slide()

	# wysokość głowy i lekkie kołysanie przy chodzie
	var target_h := crouch_height if crouch else stand_height
	var moving := dir.length() > 0.1 and is_on_floor()
	_bob += delta * speed * 3.2 if moving else 0.0
	var bob := sin(_bob) * 0.035 if moving else 0.0
	head.position.y = lerp(head.position.y, target_h + bob, 10.0 * delta)

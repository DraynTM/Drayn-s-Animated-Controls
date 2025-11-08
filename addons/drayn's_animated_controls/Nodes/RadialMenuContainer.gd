@tool
extends Container 
## Container that places Control nodes radially. Can be switched in the Menu Mode.
class_name RadialContainer

func _display_warning(message: String):
	if Engine.is_editor_hint():
		push_warning("[RadialContainer Warning]: " + message)
	else:
		push_warning("[RadialContainer Warning]: " + message)

func _display_error(message: String, instruction: String):
	var full_message = "[RadialContainer ERROR]: " + message + "\n[INSTRUCTION]: " + instruction
	if Engine.is_editor_hint():
		push_error(full_message)
	else:
		printerr(full_message)

@export_category("Base Radial Settings")
@export_group("Radius and Angle")
@export_range(10.0, 1000.0, 1.0, "suffix:px") var radius: float = 100.0 : set = set_radius
@export_range(0.0, 360.0, 0.1, "suffix:°") var start_angle_deg: float = 0.0 : set = set_start_angle_deg
@export_range(0.0, 360.0, 0.1, "suffix:°") var end_angle_deg: float = 360.0 : set = set_end_angle_deg
@export var buttons_face_center: bool = false : set = set_buttons_face_center

@export_group("Appearance Animations")
@export var animate_on_ready: bool = true
@export var animation_duration: float = 0.5
@export var animation_curve: Curve
@export_tool_button("Preview Animation (Editor Only)") var preview_animation_button: Callable = _on_preview_animation_button_pressed

@export_category("Menu Mode (Radial Menu)")
@export var RadialMenuMode: bool = false : set = set_RadialMenuMode

@export_group("Focus Control")
@export_range(0.0, 360.0, 1.0, "suffix:°") var focus_target_angle_deg: float = 180.0
@export var clockwise_movement: bool = true

@export_group("Movement Settings")
@export_range(0.1, 20.0, 0.1) var move_speed: float = 5.0
@export var focus_move_curve: Curve

@export_group("Opacity Settings")
@export_range(0.0, 1.0, 0.01) var min_opacity: float = 0.1
@export_range(0.0, 1.0, 0.01) var max_opacity: float = 1.0

var current_radius: float = 0.0 : set = set_current_radius
var target_radius: float = 0.0
var tween: Tween
var current_focus_index: int = -1
var current_start_angle_deg: float = 0.0 : set = set_current_start_angle_deg

func _ready():
	if RadialMenuMode and get_child_count() == 0:
		_display_warning("Menu mode is enabled, but the container has no children.")
		
	if not Engine.is_editor_hint():
		current_start_angle_deg = start_angle_deg
		
		if RadialMenuMode:
			_setup_focus_menu_mode()
			if get_child_count() > 0:
				var first_child = get_child(0) as Control
				if first_child:
					first_child.grab_focus()
				_move_to_focus(0, false)

		if animate_on_ready:
			current_radius = 0.0
			target_radius = radius
			_animate_layout()
		else:
			current_radius = radius
			_resort_children()

func _setup_focus_menu_mode():
	for i in range(get_child_count()):
		var child = get_child(i) as Control
		if child:
			child.focus_mode = Control.FOCUS_ALL
			if not child.focus_entered.is_connected(Callable(self, "_on_child_focus_entered")):
				child.focus_entered.connect(Callable(self, "_on_child_focus_entered").bind(i))
			if not child.focus_exited.is_connected(Callable(self, "_on_child_focus_exited")):
				child.focus_exited.connect(Callable(self, "_on_child_focus_exited").bind(i))
		else:
			_display_error(
				"Child node '" + get_child(i).name + "' is not of type Control, which is required for RadialMenuMode.",
				"Ensure that all children inherit from Control (e.g., Button, PanelContainer)."
			)
			
	_update_focus_visuals()

func _notification(what):
	if what == NOTIFICATION_SORT_CHILDREN:
		if Engine.is_editor_hint() and get_size() == Vector2.ZERO:
			_display_warning("Container size is zero. Set 'Min Size' or attach the script to a node with a non-zero size.")
			
		if Engine.is_editor_hint():
			current_radius = radius
			current_start_angle_deg = start_angle_deg
		_resort_children()

func _resort_children():
	var children_count = get_child_count()
	if children_count == 0:
		return

	var total_angle = end_angle_deg - start_angle_deg
	if total_angle == 0.0:
		_display_warning("Total angle is 0.0. Change 'end_angle_deg' to a different value to arrange children.")
		return

	var angle_step = deg_to_rad(total_angle) / children_count
	var current_angle = deg_to_rad(current_start_angle_deg)
	var center = get_size() / 2.0

	for i in range(children_count):
		var child = get_child(i) as Control
		if child:
			var x = cos(current_angle) * current_radius
			var y = sin(current_angle) * current_radius
			
			var child_center_position = Vector2(x, y)
			child.position = center + child_center_position

			if child.size == Vector2.ZERO:
				_display_error(
					"Child element '" + child.name + "' has a zero size (0, 0).",
					"Set 'Min Size' for the child element or ensure it gets a size from the parent container."
				)
				continue
				
			child.pivot_offset = child.size / 2.0
			
			var target_rotation_angle = 0.0
			if buttons_face_center:
				target_rotation_angle = current_angle + deg_to_rad(180.0)
			
			child.rotation = target_rotation_angle
			
			current_angle += angle_step

func _on_child_focus_entered(index: int):
	if RadialMenuMode:
		current_focus_index = index
		_update_focus_visuals()
		_move_to_focus(index, true)

func _on_child_focus_exited(index: int):
	if RadialMenuMode:
		_update_focus_visuals()

func _update_focus_visuals():
	var children_count = get_child_count()
	if children_count == 0:
		return
	
	for i in range(children_count):
		var child = get_child(i) as Control
		if not child: continue

		if RadialMenuMode and current_focus_index != -1:
			
			var distance = abs(i - current_focus_index)
			var wrapped_distance = min(distance, children_count - distance)
			
			var max_distance = floor(children_count / 2.0)
			
			var normalized_distance: float
			if max_distance > 0:
				normalized_distance = float(wrapped_distance) / max_distance
			else:
				normalized_distance = 0.0 
				
			var target_alpha = lerp(max_opacity, min_opacity, normalized_distance)
			
			child.modulate = Color(1, 1, 1, target_alpha)
		else:
			child.modulate = Color(1, 1, 1, 1.0)

func _move_to_focus(index: int, animated: bool = true):
	var children_count = get_child_count()
	if children_count == 0: return

	var total_angle = end_angle_deg - start_angle_deg
	if total_angle == 0.0: return

	var angle_per_child = total_angle / children_count
	
	var desired_child_angle = focus_target_angle_deg

	var target_start_angle = desired_child_angle - (index * angle_per_child + angle_per_child / 2.0)
	
	var current = current_start_angle_deg
	var target_abs = target_start_angle 
	
	var diff = target_abs - fmod(current, 360.0)

	if diff > 180:
		diff -= 360
	elif diff <= -180:
		diff += 360
   
	var final_target_angle: float
	var shortest_diff = diff 

	if clockwise_movement:
		if shortest_diff < 0:
			diff = shortest_diff
	else: 
		if shortest_diff > 0:
			diff = shortest_diff
			
	final_target_angle = current + diff

	if tween and tween.is_running():
		tween.kill()

	if animated:
		tween = create_tween()
		if focus_move_curve == null:
			_display_warning("'Focus Move Curve' property is not set. Using default easing.")
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "current_start_angle_deg", final_target_angle, 1.0 / move_speed)
		else:
			var start_angle = current_start_angle_deg
			var end_angle = final_target_angle
			var duration = 1.0 / move_speed
			tween.tween_method(
				Callable(self, "_update_focus_angle_by_curve").bind(start_angle, end_angle), 
				0.0, 
				1.0, 
				duration
			)
	else:
		self.current_start_angle_deg = final_target_angle

func _update_focus_angle_by_curve(value: float, start_angle: float, end_angle: float):
	var curved_value = focus_move_curve.sample(value)
	var animated_angle = lerp(start_angle, end_angle, curved_value)
	self.current_start_angle_deg = animated_angle

func _animate_layout():
	if tween and tween.is_running():
		tween.kill()

	tween = create_tween()
	
	if animation_curve == null:
		_display_warning("'Animation Curve' property is not set. Using default easing for animation.")
		tween.tween_property(self, "current_radius", target_radius, animation_duration)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		tween.tween_method(_update_animation_by_curve, 0.0, 1.0, animation_duration)

func _update_animation_by_curve(value: float):
	var curved_value = animation_curve.sample(value)
	var animated_radius = lerp(0.0, target_radius, curved_value)
	self.current_radius = animated_radius

func _on_preview_animation_button_pressed():
	if Engine.is_editor_hint():
		current_radius = 0.0
		target_radius = radius
		_animate_layout()
	else:
		_display_warning("'Preview' button only works in the editor.")

func set_radius(value):
	radius = value
	if Engine.is_editor_hint():
		queue_sort()

func set_start_angle_deg(value):
	start_angle_deg = value
	if Engine.is_editor_hint():
		queue_sort()

func set_end_angle_deg(value):
	end_angle_deg = value
	if Engine.is_editor_hint():
		queue_sort()

func set_buttons_face_center(value):
	buttons_face_center = value
	queue_sort()

func set_current_radius(value):
	current_radius = value
	_resort_children()

func set_current_start_angle_deg(value: float):
	current_start_angle_deg = value
	_resort_children()

func set_RadialMenuMode(value):
	RadialMenuMode = value
	
	if Engine.is_editor_hint():
		_update_focus_visuals()
		return
	
	if is_inside_tree():
		if value:
			_setup_focus_menu_mode()
		else:
			_update_focus_visuals()

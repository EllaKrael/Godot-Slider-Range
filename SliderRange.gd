"""
HSliderRange
Version: 1.0.0
Author(s): Gemma "Ella Krael" and Glen "Iku Krael"
----------------------------------------------------------------------------------------------------
A simple script which can be added to an HSlider and then use two child elements as grabbers 
to act as a RangeSlider with a range min/max value working within the HSliders min/max
----------------------------------------------------------------------------------------------------
ToDo: Allow attaching to a VSlider?
"""
tool
class_name HSliderRange
extends HSlider

# Used to determing what handle we are talking about in functions
enum DraggingHandle { None, Min, Max }

# New signals to connect to which can be used to read our new range values
signal range_changed(new_min, new_max)
signal range_min_changed(new_min)
signal range_max_changed(new_max)

# We will ignore the value property of slider and use range_min and range_max as our value holders
export var range_min: float = 0 setget set_range_min
func set_range_min(new_value: float):
	new_value = _validate_range_min(new_value)
	if new_value != range_min:
		#emit_signal("range_min_changed", range_min)
		pass
	range_min = new_value
	handle_grabber_changed(DraggingHandle.Min)

export var range_max: float = 100 setget set_range_max
func set_range_max(new_value: float):
	new_value = _validate_range_max(new_value)
	if new_value != range_max:
		#emit_signal("range_max_changed", range_max)
		pass
	range_max = new_value
	handle_grabber_changed(DraggingHandle.Max)

# Ensure there is a value gap of (y * step) between range_min and range_max
export var range_gap: int = 1 setget set_range_gap
func set_range_gap(new_value: int):
# allow setting to zero for min and max to be the same value
	if new_value < 0 or new_value > abs(min_value - max_value):
		return
	range_gap = new_value
	# ToDo: Adjust either max or min to keep gap on change or refuse change
	#handle_grabber_changed(DraggingHandle.Min)
	#handle_grabber_changed(DraggingHandle.Max)

# We need two grabbers (within containers, works if within the slider itself) to act as the value setters
export var grabber_min_nodepath: NodePath setget set_grabber_min
func set_grabber_min(new_value: NodePath): 
	# set to left of component
	grabber_min_nodepath = new_value
	update_grabber(DraggingHandle.Min, true)
	update_configuration_warning()

export var grabber_max_nodepath: NodePath setget set_grabber_max
func set_grabber_max(new_value: NodePath): 
	# set to right of component
	grabber_max_nodepath = new_value
	update_grabber(DraggingHandle.Max, true)
	update_configuration_warning()

# Our two new grabbers may be different shapes (like book ends) and so need to offset their position (default to dots/center)
enum DraggingPosition { Left, Center, Right }

export(DraggingPosition) var grabber_min_drag_from = DraggingPosition.Center setget set_grabber_min_drag_from
func set_grabber_min_drag_from(new_value):# DraggingPosition):
	grabber_min_drag_from = new_value
	handle_grabber_changed(DraggingHandle.Min)
	
export(DraggingPosition) var grabber_max_drag_from = DraggingPosition.Center setget set_grabber_max_drag_from
func set_grabber_max_drag_from(new_value):# DraggingPosition):
	grabber_max_drag_from = new_value
	handle_grabber_changed(DraggingHandle.Max)

# Overflow buffer (silly little thing that gives space for the control to move into if allow greater/lesser is active)
export(float) var overflow_buffer = 0.0 setget set_overflow_buffer
func set_overflow_buffer(new_value: float):
	overflow_buffer = new_value
	handle_slider_changed()


var slider: Slider
var grabber_min: Control
var grabber_max: Control

# these will get set on every click of a grabber (as grabbers could exist outside of Slider)
var drag_handle    = DraggingHandle.None
var drag_position  = null
var drag_container = null
var drag_tick      := 0.0  # range of motion in pixels
var drag_distance  := 0.0  # shortest drag/step
var drag_movement  := Vector2(0.0, 0.0)
var last_position  = null
var range_values   = [0.0, 0.0]
var drag_offset    := 0


# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.editor_hint:
		return
	
	# Bar style doesn't matter but we should not have any grabber images
	#add_icon_override("custom_icons/grabber", Texture.new())
	#add_icon_override("custom_icons/grabber_highlight", Texture.new())
	#add_icon_override("custom_icons/grabber_disabled", Texture.new())
	
	slider = get_node(".") as Slider
	update_grabber(DraggingHandle.Min, false)
	update_grabber(DraggingHandle.Max, false)
	
	validate_component()
	handle_slider_changed() # reset our step measurements and grabbers
	
	slider.connect("changed", self, "handle_slider_changed")
	slider.connect("resized", self, "handle_slider_changed") # if element resizes update handles (works best if child of slider)
	grabber_min.connect("gui_input", self, "handle_grabber_gui_input", [grabber_min, DraggingHandle.Min])
	grabber_max.connect("gui_input", self, "handle_grabber_gui_input", [grabber_max, DraggingHandle.Max])
	pass # Replace with function body.


func _enter_tree():
	slider = get_node(".") as Slider
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Testing if _process is more responsive than gui_input
	#if drag_handle != DraggingHandle.None: 
	#	_drag_element_along_x(fetch_grabber_for_handle(drag_handle), get_global_mouse_position())
	pass


func get_position_along_bar(value_to_calculate: float, offset_by: float = 0.0):
	var overflow_by = 0.0
	var value_to_portray = value_to_calculate - min_value
	var bar_tick = slider.rect_size.x / abs(min_value - max_value)
	if ((value_to_portray < min_value and allow_lesser) or (value_to_portray > max_value and allow_greater)) and overflow_buffer > 0.0:
		overflow_by = (0 - overflow_buffer) if (value_to_portray < min_value) else (0 + overflow_buffer)
	return (bar_tick * value_to_portray) - offset_by + overflow_by


func update_grabber(method, force: bool = false):
	# Set for Min
	if method == DraggingHandle.Min and (force or grabber_min == null):
		if not grabber_min_nodepath.is_empty():
			grabber_min = get_node(grabber_min_nodepath) as Control
	# Set for Max
	if method == DraggingHandle.Max and (force or grabber_max == null):
		if not grabber_max_nodepath.is_empty():
			grabber_max = get_node(grabber_max_nodepath) as Control
	pass


func fetch_grabber_for_handle(method) -> Control:
	match method:
		DraggingHandle.Min:
			return grabber_min
		DraggingHandle.Max:
			return grabber_max
		_:
			# will lead to issues
			assert(false, "Failed to specify a valid handle")
			return null


func fetch_grabber_center(method, grabber) -> float:
	var adjust = 0.0
	#grabber = fetch_grabber_for_handle(method)
	if grabber == null:
		return adjust 
	var drag_from = grabber_min_drag_from if method == DraggingHandle.Min else grabber_max_drag_from
	match drag_from:
		DraggingPosition.Center:
			adjust = (grabber.rect_size.x/2)
		DraggingPosition.Left:
			if method == DraggingHandle.Max:
				adjust = 0.0
			pass
		DraggingPosition.Right:
			adjust = (grabber.rect_size.x)
	return adjust 


func handle_slider_changed():
	handle_grabber_changed(DraggingHandle.Min)
	handle_grabber_changed(DraggingHandle.Max) 
	pass


func handle_grabber_changed(method): 
	if method == DraggingHandle.Min:
		_drag_element_grab(grabber_min) # populate temp variables
		handle_grabber_move(method)
	if method == DraggingHandle.Max:
		_drag_element_grab(grabber_max) # populate temp variables
		handle_grabber_move(method)


func handle_grabber_move(method): 
	if method == DraggingHandle.Min:
		if grabber_min == null:
			return
		var overflow_by = 0.0
		var value_to_portray = (min_value if range_min < min_value else range_min) - min_value
		if allow_greater and range_min > max_value: # correct for overflow on + max_value
			value_to_portray = (max_value if range_max > max_value else range_max) - min_value
		if allow_lesser and overflow_buffer > 0.0 and range_min < min_value:
			overflow_by = overflow_buffer # handle allow_lesser with overflow_buffer
		grabber_min.rect_position = Vector2((drag_tick * value_to_portray) - fetch_grabber_center(method, grabber_min) - overflow_by, grabber_min.rect_position.y)
	if method == DraggingHandle.Max:
		if grabber_max == null:
			return 
		var overflow_by = 0.0
		var value_to_portray = (max_value if range_max > max_value else range_max) - min_value
		if allow_lesser and range_max < min_value: # correct for overflow on - min_value
			value_to_portray = (min_value if range_min < min_value else range_min) - min_value
		if allow_greater and overflow_buffer > 0.0 and range_max > max_value:
			overflow_by = overflow_buffer # handle allow_greater with overflow_buffer
		grabber_max.rect_position = Vector2((drag_tick * value_to_portray) - fetch_grabber_center(method, grabber_max) + overflow_by, grabber_max.rect_position.y) 


func handle_grabber_gui_input(event, grabber, method):
	#grabber = fetch_grabber_for_handle(method)
	if event is InputEventMouseButton:
		if (event.is_pressed() and event.button_index == BUTTON_LEFT):
			# start dragging
			_drag_element_begin(method)
		else: 
			# end dragging
			# snap to nearest allowed value ?
			_drag_element_begin(DraggingHandle.None)
	if event is InputEventMouseMotion and drag_handle != DraggingHandle.None: 
		_drag_element_along_x(grabber, get_global_mouse_position())# - drag_position) 
		pass


func _drag_element_grab(grabber):
	if grabber == null:
		return 
	drag_position = get_global_mouse_position()
	drag_container = grabber.get_parent()
	# get container size and adjust for buffer/overflow allowances
	var container_size_x = drag_container.rect_size.x
	drag_tick = container_size_x / abs(min_value - max_value)
	container_size_x -= fetch_grabber_center(drag_handle, grabber)
	drag_distance = round(container_size_x / (abs(min_value - max_value)/step))


func _drag_element_begin(method):
	drag_handle = method
	match method:
		DraggingHandle.Min, DraggingHandle.Max:
			last_position = get_global_mouse_position()
			var grabber = fetch_grabber_for_handle(method)
			_drag_element_grab(grabber)
		_:
			# end dragging
			drag_position = null
			drag_container = null
			last_position = null


func _validate_range_min(new_value: float) -> float:
	if new_value >= (range_max - (range_gap * step)):
		new_value = (range_max - (range_gap * step))
	elif (new_value < min_value and not allow_lesser):
		new_value = min_value
	return new_value


func _validate_range_max(new_value: float) -> float:
	if (new_value) <= (range_min + (range_gap * step)):
		new_value = (range_min + (range_gap * step))
	elif (new_value > max_value and not allow_greater):
		new_value = max_value
	return new_value


func _drag_element_along_x(grabber: Node, dragged_position: Vector2):
	# calculate drag travel
	var distance_travelled = dragged_position - last_position
	var value_adjust = 0.0
	# this "locking" movement is kinda janky and might need a smoother tween for movement
	if abs(distance_travelled.x) >= drag_distance:
		var movement = round(distance_travelled.x / drag_distance) # int as you can't have part of a pixel
		value_adjust = step * movement
	else:
		return # only allow steps of travel
	# calculate representing value and emit
	match drag_handle:
		DraggingHandle.Min:
			range_min = _validate_range_min(range_min + value_adjust)
			emit_signal("range_min_changed", range_min)
			pass
		DraggingHandle.Max:
			range_max = _validate_range_max(range_max + value_adjust)
			emit_signal("range_max_changed", range_max)
			pass
		_:
			return
	last_position = dragged_position
	# update handle position by value
	handle_grabber_move(drag_handle)
	emit_signal("range_changed", range_min, range_max)


func _get_configuration_warning() -> String:
	# validate settings (whilst editing)
	if grabber_min_nodepath.is_empty():
		return "Grabber Min NodePath needs to point to a node within a container in which it can be dragged."
	if grabber_max_nodepath.is_empty():
		return "Grabber Max NodePath needs to point to a node within a container in which it can be dragged."
	return ""


func validate_component():
	# validate component (whilst running)
	if Engine.editor_hint:
		update_configuration_warning()
		return
	assert(slider != null, "This script must be attatched to a slider")
	assert(grabber_min != null, "Grabber Min NodePath needs to point to a node within a container in which it can be dragged.")
	assert(grabber_max != null, "Grabber Max NodePath needs to point to a node within a container in which it can be dragged.")

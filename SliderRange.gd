@tool
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
class_name HSliderRange
extends HSlider

# Used to determing what handle we are talking about in functions
enum DraggingHandle { None, Min, Max }

# New signals to connect to which can be used to read our new range values
signal range_changed(new_min, new_max)
signal range_min_changed(new_min)
signal range_max_changed(new_max)

# We will ignore the value property of slider and use range_min and range_max as our value holders
@export var range_min: float = 0: set = set_range_min
func set_range_min(new_value: float):
	if range_min < min_value and not allow_lesser:
		range_min = min_value
	range_min = new_value
	handle_grabber_changed(DraggingHandle.Min)

@export var range_max: float = 100: set = set_range_max
func set_range_max(new_value: float):
	if new_value > max_value and not allow_greater:
		new_value = max_value
	range_max = new_value
	handle_grabber_changed(DraggingHandle.Max)

# Ensure there is a value gap of (y * step) between range_min and range_max
@export var range_gap: int = 1: set = set_range_gap
func set_range_gap(new_value: int):
# allow setting to zero for min and max to be the same value
	if new_value < 0 or new_value > abs(min_value - max_value):
		return
	range_gap = new_value
	# ToDo: Adjust either max or min to keep gap on change or refuse change
	#handle_grabber_changed(DraggingHandle.Min)
	#handle_grabber_changed(DraggingHandle.Max)

# We need two grabbers (within containers, works if within the slider itself) to act as the value setters
@export var grabber_min_nodepath: NodePath: set = set_grabber_min
func set_grabber_min(new_value: NodePath): 
	# set to left of component
	grabber_min_nodepath = new_value
	update_grabber(DraggingHandle.Min, true)
	update_configuration_warnings()

@export var grabber_max_nodepath: NodePath: set = set_grabber_max
func set_grabber_max(new_value: NodePath): 
	# set to right of component
	grabber_max_nodepath = new_value
	update_grabber(DraggingHandle.Max, true)
	update_configuration_warnings()

# Our two new grabbers may be different shapes (like book ends) and so need to offset their position (default to dots/center)
enum DraggingPosition { Left, Center, Right }

@export var grabber_min_drag_from: DraggingPosition = DraggingPosition.Center: set = set_grabber_min_drag_from
func set_grabber_min_drag_from(new_value):# DraggingPosition):
	grabber_min_drag_from = new_value
	handle_grabber_changed(DraggingHandle.Min)
	
@export var grabber_max_drag_from: DraggingPosition = DraggingPosition.Center: set = set_grabber_max_drag_from
func set_grabber_max_drag_from(new_value):# DraggingPosition):
	grabber_max_drag_from = new_value
	handle_grabber_changed(DraggingHandle.Max)

# Overflow buffer (silly little thing that gives space for the control to move into if allow greater/lesser is active)
@export var overflow_buffer: float = 0.0: set = set_overflow_buffer
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
	if Engine.is_editor_hint():
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
	
	slider.connect("changed", Callable(self, "handle_slider_changed"))
	slider.connect("resized", Callable(self, "handle_slider_changed")) # if element resizes update handles (works best if child of slider)
	grabber_min.connect("gui_input", Callable(self, "handle_grabber_gui_input").bind(grabber_min, DraggingHandle.Min))
	grabber_max.connect("gui_input", Callable(self, "handle_grabber_gui_input").bind(grabber_max, DraggingHandle.Max))
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
			adjust = (grabber.size.x/2)
		DraggingPosition.Left:
			if method == DraggingHandle.Max:
				adjust = 0.0
			pass
		DraggingPosition.Right:
			adjust = (grabber.size.x)
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
		if allow_lesser and overflow_buffer > 0.0 and range_min < min_value:
			overflow_by = overflow_buffer # handle allow_lesser with overflow_buffer
		grabber_min.position = Vector2((drag_tick * value_to_portray) - fetch_grabber_center(method, grabber_min) - overflow_by, grabber_min.position.y)
	if method == DraggingHandle.Max:
		if grabber_max == null:
			return 
		var overflow_by = 0.0
		var value_to_portray = (max_value if range_max > max_value else range_max) - min_value
		if allow_greater and overflow_buffer > 0.0 and range_max > max_value:
			overflow_by = overflow_buffer # handle allow_greater with overflow_buffer
		grabber_max.position = Vector2((drag_tick * value_to_portray) - fetch_grabber_center(method, grabber_max) + overflow_by, grabber_max.position.y) 


func handle_grabber_gui_input(event, grabber, method):
	#grabber = fetch_grabber_for_handle(method)
	if event is InputEventMouseButton:
		if (event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT):
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
	var container_size_x = drag_container.size.x
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
			if (range_min + value_adjust) >= (range_max - (range_gap * step)):
				range_min = range_max - (range_gap * step)
				value_adjust = 0
			elif ((range_min + value_adjust) < min_value and not allow_lesser):
				return
			range_min += value_adjust
			emit_signal("range_min_changed", range_min)
			pass
		DraggingHandle.Max:
			if (range_max + value_adjust) <= (range_min + (range_gap * step)):
				range_max = range_min + (range_gap * step)
				value_adjust = 0
			elif ((range_max + value_adjust) > max_value and not allow_greater):
				return
			range_max += value_adjust
			emit_signal("range_max_changed", range_max)
			pass
		_:
			return
	last_position = dragged_position
	# update handle position by value
	handle_grabber_move(drag_handle)
	emit_signal("range_changed", range_min, range_max)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings = []
	# validate settings (whilst editing)
	if grabber_min_nodepath.is_empty():
		warnings.push_back("Grabber Min NodePath needs to point to a node within a container in which it can be dragged.")
	if grabber_max_nodepath.is_empty():
		warnings.push_back("Grabber Max NodePath needs to point to a node within a container in which it can be dragged.")
	return warnings


func validate_component():
	# validate component (whilst running)
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	assert(slider != null, "This script must be attatched to a slider")
	assert(grabber_min != null, "Grabber Min NodePath needs to point to a node within a container in which it can be dragged.")
	assert(grabber_max != null, "Grabber Max NodePath needs to point to a node within a container in which it can be dragged.")

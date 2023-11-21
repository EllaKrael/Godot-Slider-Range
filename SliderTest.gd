extends Control


# Declare member variables here. Examples:
onready var HSliderRange = $VBoxContainer/VBoxContainer/MarginContainer/HSliderRange


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_UpdateButton_button_up():
	HSliderRange.min_value = $VBoxContainer/Panel/HBoxContainer/MinSpinBox.value
	HSliderRange.step = $VBoxContainer/Panel/HBoxContainer/StepSpinBox.value
	HSliderRange.max_value = $VBoxContainer/Panel/HBoxContainer/MaxSpinBox.value
	HSliderRange.range_gap = $VBoxContainer/Panel/HBoxContainer/GapSpinBox.value
	HSliderRange.overflow_buffer = $VBoxContainer/Panel/HBoxContainer/BufferSpinBox.value
	HSliderRange.allow_lesser = $VBoxContainer/Panel/HBoxContainer/LesserCheckBox.pressed
	HSliderRange.allow_greater = $VBoxContainer/Panel/HBoxContainer/GreaterCheckBox.pressed
	pass # Replace with function body.


func _on_HSliderRange_range_changed(new_min, new_max):
	$VBoxContainer/Panel2/HBoxContainer/MarginContainer/Label.text = str("Current range is %s to %s" % [new_min, new_max])
	pass # Replace with function body.

# game_ui.gd
extends CanvasLayer

@onready var order_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer/OrdersToggle
@onready var clear_orders: Button = $MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer/ClearOrders
@onready var panel: Panel = $Panel

func _ready():
	if order_button:
		order_button.toggled.connect(_on_order_button_toggled)
		order_button.toggle_mode = true
		# Set mouse filter to stop event propagation
		order_button.mouse_filter = Control.MOUSE_FILTER_STOP
		# Also set it for the parent containers
		var parent = order_button.get_parent()
		while parent and parent is Control:
			parent.mouse_filter = Control.MOUSE_FILTER_STOP
			parent = parent.get_parent()

func _on_order_button_toggled(button_pressed: bool) -> void:
	OrderMgmtAuto.toggle_orders(button_pressed)
	panel.visible = OrderMgmtAuto.is_ordering

func _on_clear_orders_pressed() -> void:
	OrderMgmtAuto.clear_orders()

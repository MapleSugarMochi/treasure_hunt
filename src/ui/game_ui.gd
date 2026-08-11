class_name GameUI
extends Control

signal celebration_finished

@onready var start_overlay: Control = %StartOverlay
@onready var celebration_overlay: Control = %CelebrationOverlay
@onready var celebration_timer: Timer = $CelebrationTimer

func _ready() -> void:
    celebration_timer.timeout.connect(_on_celebration_timeout)
    show_start()

func show_start() -> void:
    start_overlay.visible = true
    celebration_overlay.visible = false
    celebration_timer.stop()

func hide_start() -> void:
    start_overlay.visible = false

func play_celebration() -> void:
    start_overlay.visible = false
    celebration_overlay.visible = true
    celebration_timer.start()

func _on_celebration_timeout() -> void:
    celebration_overlay.visible = false
    celebration_finished.emit()

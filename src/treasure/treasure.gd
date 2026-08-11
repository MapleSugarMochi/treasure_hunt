class_name Treasure
extends Area2D

signal found

var consumed := false

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if consumed or not (body is Player):
        return
    consumed = true
    monitoring = false
    found.emit()

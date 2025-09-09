extends Resource
class_name EnemyData

@export var max_health := 3
@export var score_on_death := 30
@export var damage := 2
@export var speed := 120
@export var gravity: float = 800.0
@export var interactable_faction = 2

@export var knockback: Variant = Vector2.ZERO
@export var knockup: float = 0.0
@export var hitstun: float = 0.0
@export var hitstop_duration: float = 0.0

extends Resource
class_name AttackData

@export var damage: int = 1
@export var knockback: Vector2 = Vector2.ZERO
@export var hitstun: float = 0.0
@export var knockback_scale: float = 1.0
@export var damage_type: String = "physical"
@export var hitstop_duration: float = 0.006 #freezes on attack for power
@export var is_crit: bool = true #just incase we want to add critical chances :) 

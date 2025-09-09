extends Resource
class_name AchievementData

@export var id: String
@export var title: String
@export var description: String
@export var unlocked: bool = false
@export var icon: Texture2D

@export var progressive: bool = false
@export var required_amount: int = 0

var current_amount: int = 0

func progress_ratio() -> float:
	if not progressive or required_amount <= 0:
		return 0.0
	return clamp(float(current_amount) / float(required_amount), 0.0, 1.0)

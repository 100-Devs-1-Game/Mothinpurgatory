extends CharacterBody2D

func _death(source: Node):
	print("Dummy died!!!!!!!!!")
	queue_free()

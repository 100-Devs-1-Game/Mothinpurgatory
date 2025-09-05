extends Resource
class_name PlayerStats

@export_category("Movement")
@export var move_speed := 230.0
@export var accel_ground := 2600.0
@export var accel_air := 1800.0
@export var friction := 2000.0

@export_category("Gravity / Jump")
@export var gravity_up := 1600.0
@export var gravity_down := 2300.0
@export var max_fall_speed := 1000.0
@export var jump_speed := 430.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.12
@export var enable_double_jump := false
@export var second_jump_speed := 430.0
@export var allow_second_jump_from_ground := false
@export var jump_cut_multiplier := 0.5
@export var short_hop_multiplier := 0.3

@export_category("Dash")
@export var dash_speed := 520.0
@export var dash_time := 0.14
@export var dash_cooldown := 0.35

@export_category("Attack")
@export var attack_windup := 0.08
@export var attack_active := 0.10
@export var attack_recovery := 0.12
@export var attack_cooldown := 0.18
@export var recoil_on_hit := 90.0
@export var hitstop_on_hit := 0.06

@export_category("Cone Attack")
@export var cone_range := 100.0
@export var cone_half_angle_deg := 45.0
@export var cone_forward_offset := 16.0
@export var cone_vertical_offset := -6.0
@export var cone_damage := 1
@export var cone_mask := 1 << 6

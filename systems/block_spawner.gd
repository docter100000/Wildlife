class_name BlockSpawner
extends Node

@export var land_manager: LandManager
@export var spawn_root:   Node3D

const BLOCK_SIZE_VISIT   := Vector3(0.4, 0.4, 0.4)
const BLOCK_SIZE_RESIDE  := Vector3(0.6, 0.6, 0.6)
const FLORA_BLOCK_SIZE   := Vector3(0.5, 0.8, 0.5)

func _ready() -> void:
	land_manager.connect("animal_state_changed", _on_state_changed)

func _on_state_changed(
	inst: AnimalInstance,
	_old_s: SpeciesData.State,
	new_s: SpeciesData.State
) -> void:

	# Remove old block if transitioning away from visible state
	if inst.block_node:
		inst.block_node.queue_free()
		inst.block_node = null

	match new_s:
		SpeciesData.State.VISITING:
			inst.block_node = _spawn_block(
				inst.data.block_color,
				BLOCK_SIZE_VISIT,
				0.45,             # alpha — semi-transparent visitor
				inst.data.display_name
			)
		SpeciesData.State.RESIDENT:
			inst.block_node = _spawn_block(
				inst.data.block_color,
				BLOCK_SIZE_RESIDE,
				1.0,              # fully opaque resident
				inst.data.display_name
			)
		SpeciesData.State.ABSENT:
			pass  # block already freed above

func spawn_flora_block(
	flora: FloraData,
	position: Vector3
) -> Node3D:
	return _spawn_block(
		flora.block_color, FLORA_BLOCK_SIZE, 1.0,
		flora.display_name, position
	)

func _spawn_block(
	color:    Color,
	size:     Vector3,
	alpha:    float,
	label:    String,
	pos:      Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh  = box
	var mat  := StandardMaterial3D.new()
	mat.albedo_color         = Color(color.r, color.g, color.b, alpha)
	mat.transparency         = BaseMaterial3D.TRANSPARENCY_ALPHA \
							   if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mi.material_override     = mat
	mi.position              = pos
	mi.name                  = label
	spawn_root.add_child(mi)
	return mi

func update_flora_scale(inst: FloraInstance) -> void:
	if not inst.block_node:
		return

	# Scale: seed=hidden, seedling=0.2, mature=1.0
	var s := _maturity_to_scale(inst.maturity)
	inst.block_node.scale = Vector3(s, s, s)

	# Tint: darken and saturate as plant matures
	var mat := inst.block_node.material_override as StandardMaterial3D
	if mat:
		var base := inst.data.block_color
		if inst.growth_stage == FloraInstance.GrowthStage.VETERAN:
			# Veteran: slightly golden tint
			mat.albedo_color = base.lerp(Color(0.9, 0.8, 0.3), 0.2)
		elif inst.health < 0.3:
			# Dying: desaturate toward grey-brown
			mat.albedo_color = base.lerp(Color(0.5, 0.4, 0.3), 0.6)
		else:
			# Normal: blend toward full colour with maturity
			mat.albedo_color = Color(base.r, base.g, base.b,
									 lerpf(0.4, 1.0, inst.maturity))

static func _maturity_to_scale(m: float) -> float:
	if   m <= 0.0:  return 0.0   # seed — invisible
	elif m < 0.25:  return 0.2   # seedling
	elif m < 0.5:   return 0.45  # juvenile
	elif m < 0.75:  return 0.7   # establishing
	else:           return 1.0   # mature / veteran

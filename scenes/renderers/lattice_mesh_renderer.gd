extends Renderer

const LatticeMesh = preload("res://scenes/lattice_mesh.gd")

@export var lattice: LatticeMesh

var simulator: Simulator


func _on_sim_update() -> void:
	if disabled:
		return
	simulator.get_draw_data_async(_data_get)
	lattice.scale = Vector3.ONE * 100.0 / simulator.get_grid_size()


func _data_get(data: PackedByteArray) -> void:
	lattice.update_texture(data)


func change_render_setting(_by: int) -> void: pass


func set_disabled(to: bool) -> void:
	set_process(not to)
	if lattice:
		lattice.visible = not disabled


func set_simulator(sim: Simulator) -> void:
	if simulator:
		simulator.simulation_updated.disconnect(_on_sim_update)
	simulator = sim
	sim.simulation_updated.connect(_on_sim_update)
	var gs := sim.get_grid_size()
	lattice.generate(gs)

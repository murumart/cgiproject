extends Renderer

@export var lattice: LatticeMeshInstance

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
	disabled = to
	print("lattice_mesh_renderer.gd::set_disabled : setting disabled to ", to)
	if lattice:
		lattice.visible = not disabled
		print("lattice_mesh_renderer.gd::set_disabled : lattice visible: ", lattice.visible)


func set_simulator(sim: Simulator) -> void:
	if simulator:
		simulator.simulation_updated.disconnect(_on_sim_update)
	simulator = sim
	sim.simulation_updated.connect(_on_sim_update)
	var gs := sim.get_grid_size()
	lattice.generate(gs)

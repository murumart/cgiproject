extends Simulator

@export var grid_size := 64
var life: StupitTreeLife

@export var running := false

var _cells: PackedByteArray
var _newcells: PackedByteArray
var thread := Thread.new()
var semaphore := Semaphore.new()


func _ready() -> void:
	super()
	reset()


func reset() -> void:
	if thread.is_started():
		semaphore.post()
		_stop_thread = true
		thread.wait_to_finish()
	life = StupitTreeLife.new()
	_cells = PackedByteArray()
	life.init(_cells, grid_size)
	(func() -> void:
		if running:
			_stop_thread = false
			print("asdasasd")
			thread.start(_simulate_thread)
	).call_deferred()


func _process(_delta: float) -> void:
	while _give_data_cb.size() > 0:
		if _give_data_cb.front().is_valid():
			#print("sending data to ", _give_data_cb.front().get_object().to_string() + "::" + _give_data_cb.front().get_method())
			_give_data_cb.front().call(_cells.slice(0, grid_size * grid_size * grid_size))
			_give_data_cb.pop_front()
	if running:
		if not _simulating:
			simulation_updated.emit()
			semaphore.post()


var _give_data_cb: Array[Callable]
func get_draw_data_async(callback: Callable) -> void:
	_give_data_cb.append(callback)


func get_grid_size() -> int: return grid_size
func set_grid_size(to: int) -> void: grid_size = to


func is_sim_running() -> bool: return running


func sim_set_running(to: bool) -> void:
	running = to


func update_data(data: PackedByteArray) -> void:
	if running and _simulating:
		_newcells = data
		return
	_cells = data
	var flesh := PackedByteArray(); flesh.resize(grid_size * grid_size * grid_size)
	var leaf := PackedByteArray(); leaf.resize(grid_size * grid_size * grid_size)
	var bark := PackedByteArray(); bark.resize(grid_size * grid_size * grid_size)
	var ks := [null, flesh, leaf, bark]
	# set types of cells when edited by user
	for i in grid_size * grid_size * grid_size:
		var ct := data[i]
		if ct != 0:
			ks[ct][i] = 254
	_cells.append_array(flesh)
	_cells.append_array(leaf)
	_cells.append_array(bark)
	#sprint(_cells)
	simulation_updated.emit()


func _simulate() -> void:
	_simulating = true
	if _newcells:
		update_data(_newcells)
		_newcells = []
	var newc := life.generation(PackedByteArray(_cells), grid_size)
	_cells = newc
	_simulating = false


var _simulating := false
var _stop_thread := false
func _simulate_thread() -> void:
	while not _stop_thread:
		print("ass")
		semaphore.wait()
		_simulate()

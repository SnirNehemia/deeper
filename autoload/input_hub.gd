extends Node

## Central input registry (autoload: "InputHub").
##
## Owns one InputProvider per player and exposes their PlayerInput snapshots to
## the rest of the game. Gameplay code does `InputHub.get_input(player_index)`
## and reads the snapshot — it never knows or cares whether that player is on the
## keyboard, a gamepad, or a phone.
##
## Runs before scene nodes each physics frame (autoloads sit first in the tree),
## so every consumer reads a snapshot that was already refreshed this frame.

var _providers: Array[InputProvider] = []

func _ready() -> void:
	# Make sure we poll and hand out fresh input before any gameplay node runs.
	process_physics_priority = -100
	_register_milestone1_players()

## Milestone 1: two players sharing one keyboard.
func _register_milestone1_players() -> void:
	_providers.append(KeyboardProvider.make_player_one())
	_providers.append(KeyboardProvider.make_player_two())

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		for provider in _providers:
			provider.handle_event(event)

func _physics_process(delta: float) -> void:
	for provider in _providers:
		provider.poll(delta)

func _notification(what: int) -> void:
	# If the window loses focus we may miss key-up events; clear held state so
	# nothing sticks on (e.g. the sub doesn't keep driving after alt-tab).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		for provider in _providers:
			provider.reset()

## The current input snapshot for a player, or null if the index is unused.
func get_input(player_index: int) -> PlayerInput:
	if player_index < 0 or player_index >= _providers.size():
		return null
	return _providers[player_index].input

## How many players currently have a provider registered.
func player_count() -> int:
	return _providers.size()

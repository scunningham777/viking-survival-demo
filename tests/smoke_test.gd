extends Node
## Headless smoke test: loads every scene, plays a few seconds of the world,
## exercises combat/pickups/campfire, and exits non-zero on failure.
##   godot --headless --path . res://tests/smoke_test.tscn

const SCENES: PackedStringArray = [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/sound_browser.tscn",
	"res://scenes/world/world.tscn",
]

var _failures: PackedStringArray = []


func _ready() -> void:
	await _run()
	for failure in _failures:
		printerr("FAIL: ", failure)
	print("SMOKE TEST ", "PASSED" if _failures.is_empty() else "FAILED (%d)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	# Audio: every event in the bank should resolve, all but music should have placeholder audio.
	var ids := AudioManager.get_event_ids()
	_check(ids.size() >= 20, "expected >= 20 sound events, got %d" % ids.size())
	for id in ids:
		var event := AudioManager.get_event(id)
		if not String(id).begins_with("music_"):
			_check(not event.streams.is_empty(), "event '%s' has no audio" % id)
	_check(AudioManager.play(&"ui_click") != null, "play(ui_click) returned null")
	_check(AudioManager.play_at(&"wolf_growl", Vector2.ZERO) != null, "play_at(wolf_growl) returned null")

	for path in SCENES:
		var packed := load(path) as PackedScene
		_check(packed != null, "could not load " + path)
		if packed == null:
			continue
		var scene := packed.instantiate()
		add_child(scene)
		await _frames(10)
		if path.ends_with("world.tscn"):
			await _exercise_world(scene)
		if path.ends_with("sound_browser.tscn"):
			_check(scene.get_node("%EventList").get_child_count() == ids.size(), "sound browser row count mismatch")
		scene.queue_free()
		await _frames(2)


func _exercise_world(world: Node) -> void:
	var player := world.get_node("Entities/Player") as Player
	var campfire := world.get_node("Entities/Campfire")
	_check(world.get_tree().get_node_count_in_group(&"wolves") == 0, "wolves present at start")
	_check(world.get_node("Entities").get_child_count() > 50, "trees were not scattered")

	# Walk into a tree and chop until it falls.
	var tree := _nearest_tree(world, player)
	player.global_position = tree.global_position + Vector2(0, 20)
	player.facing = Vector2.UP
	await _frames(3)
	for i in 6:
		player._attack_cooldown = 0.0
		player._attack()
		await _seconds(0.15)
	_check(not is_instance_valid(tree), "tree did not fall after 6 chops")
	await _collect_pickups(world, player)
	_check(GameState.count(&"wood") >= 1, "wood was not picked up (have %d)" % GameState.count(&"wood"))

	# Feed the campfire.
	var fuel_before: float = campfire.fuel
	player.global_position = campfire.global_position + Vector2(0, 25)
	await _frames(3)
	player._interact()
	_check(campfire.fuel > fuel_before, "campfire fuel did not increase")

	# Spawn a wolf next to the player, kill it, collect the meat, eat it.
	world.spawn_wolf()
	var wolf := world.get_tree().get_first_node_in_group(&"wolves") as Node2D
	_check(wolf != null, "spawn_wolf() did not add a wolf")
	if wolf:
		player.global_position = Vector2(300, 300)
		wolf.global_position = player.global_position + Vector2(0, -22)
		player.facing = Vector2.UP
		await _frames(3)
		for i in 4:
			if not is_instance_valid(wolf):
				break
			wolf.global_position = player.global_position + Vector2(0, -22)
			player._attack_cooldown = 0.0
			player._attack()
			await _seconds(0.15)
		_check(not is_instance_valid(wolf), "wolf survived 4 hits")
		await _collect_pickups(world, player)
		_check(GameState.count(&"meat") == 1, "meat was not picked up")
		player.hunger = 10.0
		player._eat()
		_check(player.hunger > 10.0 and GameState.count(&"meat") == 0, "eating meat failed")

	await _exercise_herbs(world, player)
	await _exercise_inventory(world)
	await _exercise_cooking(world, player, campfire)

	# Night transition and death flow.
	world._begin_phase(1, true)
	_check(GameState.is_night, "night did not start")
	player.take_hit(1000.0, player)
	await _frames(3)
	_check(player.is_dead, "player did not die")
	_check(world.get_node("HUD/Root/GameOverPanel").visible, "game over panel not shown")
	var inventory := (world.get_node("HUD") as Hud).inventory
	_check(not inventory.can_open, "inventory can still open after death")


## Harvests one plant of each herb variety with the interact key, then uses each herb.
func _exercise_herbs(world: Node, player: Player) -> void:
	for kind in HerbPlant.KINDS:
		var herb := _isolated_herb(world, kind)
		_check(herb != null, "no %s plants were scattered" % kind)
		if herb == null:
			continue
		player.global_position = herb.global_position + Vector2(0, 8)
		await _frames(3)
		player._interact()
		_check(GameState.count(kind) == 1, "%s was not harvested" % kind)
		_check(not herb.is_grown, "%s plant did not become picked" % kind)
		await _frames(3)
		player._interact()
		_check(GameState.count(kind) == 1, "picked %s plant was harvested twice" % kind)

	player.health = 40.0
	_check(player.use_herb(&"yarrow") and player.health > 40.0, "yarrow did not heal")
	player.hunger = 40.0
	_check(player.use_herb(&"angelica") and player.hunger > 40.0, "angelica did not restore hunger")
	_check(player.use_herb(&"wolfsbane") and player.wolfsbane_time > 0.0, "wolfsbane did not poison the axe")
	_check(not player.use_herb(&"yarrow"), "used yarrow with none in the inventory")
	for kind in HerbPlant.KINDS:
		_check(GameState.count(kind) == 0, "%s was not spent" % kind)


## Opens the inventory, checks the grid contents, clicks a slot and closes it again.
func _exercise_inventory(world: Node) -> void:
	var inventory := (world.get_node("HUD") as Hud).inventory
	GameState.add(&"wood", 3)
	GameState.add(&"yarrow")
	GameState.spend(&"meat", GameState.count(&"meat"))
	inventory.open()
	await _frames(3)
	_check(inventory.visible and get_tree().paused, "inventory did not open and pause the game")
	var shown := inventory.shown_items()
	_check(shown.find(&"wood") != -1 and shown.find(&"wood") < shown.find(&"yarrow"),
			"inventory grid order wrong: %s" % [shown])
	_check(&"meat" not in shown, "inventory shows an item with a count of 0")

	var yarrow_slot: Button = inventory._slot_for(&"yarrow")
	_check(yarrow_slot != null, "no slot for yarrow")
	if yarrow_slot:
		yarrow_slot.pressed.emit()
		var name_label := inventory.get_node("%NameLabel") as Label
		_check(inventory.selected_item == &"yarrow" and name_label.text == "Yarrow", "clicking a slot did not select it")
		_check(not (inventory.get_node("%DescriptionLabel") as Label).text.is_empty(), "no item description shown")
	GameState.spend(&"yarrow")
	_check(inventory.selected_item.is_empty(), "selection kept after the item ran out")

	inventory.close()
	await _frames(3)
	_check(not inventory.visible and not get_tree().paused, "inventory did not close and unpause")


## Cooks raw meat on the spit (only while the fire is lit), collects it and eats it.
func _exercise_cooking(world: Node, player: Player, campfire: Node) -> void:
	var spit := world.get_node("Entities/CookingSpit") as CraftingStation
	spit.craft_time_sec = 0.3
	GameState.spend(&"meat", GameState.count(&"meat"))
	GameState.add(&"meat")
	# Stand right at the spit, so it beats the campfire as the nearest interactable.
	player.global_position = spit.global_position + Vector2(0, 2)
	await _frames(3)

	campfire._set_lit(false)
	player._interact()
	_check(not spit.is_crafting and GameState.count(&"meat") == 1, "spit cooked with the fire out")
	campfire._set_lit(true)
	player._interact()
	_check(spit.is_crafting and GameState.count(&"meat") == 0, "spit did not start cooking")
	await _seconds(0.5)
	_check(not spit.is_crafting, "spit did not finish cooking")
	await _collect_pickups(world, player)
	_check(GameState.count(&"cooked_meat") == 1, "cooked meat was not picked up")

	GameState.add(&"meat")
	player.hunger = 10.0
	player._eat()
	_check(GameState.count(&"cooked_meat") == 0 and GameState.count(&"meat") == 1,
			"eating did not prefer cooked meat")
	_check(is_equal_approx(player.hunger, 10.0 + player.cooked_meat_hunger_restore),
			"cooked meat restored %.1f hunger" % (player.hunger - 10.0))


## A plant of `kind` with no other plant in interact range, so _interact() can only hit it.
func _isolated_herb(world: Node, kind: StringName) -> HerbPlant:
	var herbs: Array[HerbPlant] = []
	for child in world.get_node("Entities").get_children():
		if child is HerbPlant:
			herbs.append(child)
	for herb in herbs:
		if herb.kind != kind:
			continue
		var crowded := herbs.any(func(other: HerbPlant) -> bool:
			return other != herb and other.position.distance_to(herb.position) < 60.0)
		if not crowded:
			return herb
	return null


## Waits for pickups to pop out and arm, then walks the player over each one.
func _collect_pickups(world: Node, player: Node2D) -> void:
	await _seconds(0.5)
	for child in world.get_node("Entities").get_children():
		if child is Pickup:
			player.global_position = child.global_position
			await _frames(3)


func _nearest_tree(world: Node, player: Node2D) -> Node2D:
	var best: Node2D
	for child in world.get_node("Entities").get_children():
		if child.has_method(&"take_hit") and child is StaticBody2D:
			if best == null or child.global_position.distance_to(player.global_position) \
					< best.global_position.distance_to(player.global_position):
				best = child
	return best


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _seconds(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

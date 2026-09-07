# Boss Arena Minion Trial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a one-shot, two-wave boss-room minion trial that reuses the existing slime, skeleton, ranged-enemy, spike-row, and fire-sweep scenes, then exposes a clean future boss spawn point.

**Architecture:** A focused `BossEncounter` scene owns its spawn markers, traps, active actors, and a state-machine controller. `Dungeon.tscn` instances that scene in the existing boss room, while `dungeon.gd` only starts it on Level 4 and mirrors its progress into the existing HUD; the controller prevalidates whole waves and uses `SpawnPositionResolver` before committing any spawn.

**Tech Stack:** Godot 4.6, GDScript, `.tscn` scenes, headless `SceneTree` tests

**Spec:** `docs/superpowers/specs/2026-09-06-boss-arena-minion-trial-design.md`

## Global Constraints

- Keep the real boss, boss health UI, boss victory/rewards, new enemy types, new trap art, randomized waves, and additional preparation waves out of scope.
- Use exactly five slimes in Wave 1 and exactly three skeletons plus two ranged enemies in Wave 2.
- Add every spawned trial minion to `boss_minion` and `boss_enemy`, and never add it to `level1_enemy`, `level2_enemy`, or `level3_enemy`.
- Never allow both spike rows to damage simultaneously; keep the fire sweep inactive in Wave 1 and stop all traps after Wave 2.
- Preserve the authored entrance safe area and abort a whole wave if any required scene, node, marker, or valid spawn is unavailable.
- Do not overwrite or broadly reserialize the user's existing uncommitted `Dungeon.tscn` layout. Integrate only the new external resource, `BossEncounter` instance, and its required connection/hunks.
- Every new or modified boss-encounter script section and hand-authored boss-encounter test section must include a concise comment containing `Huang Wan Jun 2204536`.
- Commit only files named by each task; never stage `.superpowers/` or unrelated working-tree changes.

## File Structure

- Create `BossEncounter/boss_encounter_controller.gd`: encounter state, validation, spawning, trap sequencing, living-minion tracking, cleanup, and future-boss API.
- Create `BossEncounter/BossEncounter.tscn`: authored arena markers, entrance trigger/safe area, reused trap instances, active containers, and hidden boss marker.
- Create `tests/test_boss_encounter.gd`: focused controller behavior, safety, groups, traps, failure handling, and one-shot progression.
- Modify `dungeon.gd`: Level 4 HUD text and the single call that starts the encounter.
- Modify `Dungeon.tscn`: instance the focused encounter scene in the existing boss room.
- Modify `tests/test_dungeon_lifecycle.gd`: assert Dungeon-to-boss-encounter integration without duplicating controller unit coverage.
- Modify `tests/test_dungeon_minimap.gd`: assert Level 4 displays living `boss_enemy` trial minions only.

---

### Task 1: One-shot controller shell and configuration validation

**Files:**
- Create: `BossEncounter/boss_encounter_controller.gd`
- Create: `tests/test_boss_encounter.gd`

**Interfaces:**
- Consumes: existing global class `SpawnPositionResolver`; later tasks supply children at the exported node paths.
- Produces: `BossEncounterController.State`, `start_encounter() -> void`, `get_encounter_state() -> State`, `is_boss_ready() -> bool`, `get_boss_spawn_point() -> Marker2D`, `get_wave_total() -> int`, `get_wave_remaining() -> int`, `boss_ready(spawn_point: Marker2D)`, and `encounter_changed()`.

- [ ] **Step 1: Write the failing controller-contract test**

Create `tests/test_boss_encounter.gd` with a small factory that supplies the complete required node structure. Include the attribution comment above the test section.

```gdscript
extends SceneTree

const CONTROLLER_SCRIPT := preload("res://BossEncounter/boss_encounter_controller.gd")
var failures: int = 0


func _initialize() -> void:
	await process_frame
	# Huang Wan Jun 2204536 - Verify the boss trial starts once and exposes its future-boss API.
	var encounter := _make_encounter()
	root.add_child(encounter)
	await process_frame
	_expect(encounter.get_encounter_state() == BossEncounterController.State.WAITING, "trial starts waiting")
	encounter.start_encounter()
	encounter.start_encounter()
	_expect(encounter.get_encounter_state() == BossEncounterController.State.WAVE_1, "start enters Wave 1 only once")
	_expect(encounter.get_node("ActiveMinions").get_child_count() == 5, "re-entry cannot duplicate Wave 1")
	_expect(not encounter.is_boss_ready(), "future boss is not ready during Wave 1")
	_expect(encounter.get_boss_spawn_point() == encounter.get_node("BossSpawnPoint"), "boss marker API returns authored marker")
	encounter.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
```

The factory must create named children `EntranceTrigger`, `EntranceSafeArea` with a `RectangleShape2D`, `Wave1SpawnPoints` with five `Marker2D`s, `Wave2SkeletonSpawnPoints` with three markers, `Wave2RangedSpawnPoints` with two markers, `SpikeRows` with two real `SpikeRow.tscn` instances, `FireSweep`, `FireStartMarker`, `FireEndMarker`, `ActiveMinions`, `ActiveProjectiles`, and `BossSpawnPoint`. Assign the three real enemy scenes and shorten trap timings to `0.02` seconds.

- [ ] **Step 2: Run the test and confirm the missing controller fails**

Run:

```powershell
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/test_boss_encounter.gd
```

Expected: non-zero exit with `Cannot open file res://BossEncounter/boss_encounter_controller.gd`.

- [ ] **Step 3: Implement the minimal controller shell and atomic Wave 1 validation**

Create the script with these exact public properties and helpers. Each logical section receives one concise attribution comment.

```gdscript
class_name BossEncounterController
extends Node2D

signal boss_ready(spawn_point: Marker2D)
signal encounter_changed

enum State { WAITING, WAVE_1, WAVE_2, BOSS_READY }

@export var slime_scene: PackedScene
@export var skeleton_scene: PackedScene
@export var ranged_enemy_scene: PackedScene
@export var entrance_safe_area_path := NodePath("EntranceSafeArea")
@export var wave_1_spawn_points_path := NodePath("Wave1SpawnPoints")
@export var wave_2_skeleton_spawn_points_path := NodePath("Wave2SkeletonSpawnPoints")
@export var wave_2_ranged_spawn_points_path := NodePath("Wave2RangedSpawnPoints")
@export var spike_rows_path := NodePath("SpikeRows")
@export var fire_sweep_path := NodePath("FireSweep")
@export var fire_start_marker_path := NodePath("FireStartMarker")
@export var fire_end_marker_path := NodePath("FireEndMarker")
@export var active_minions_path := NodePath("ActiveMinions")
@export var active_projectiles_path := NodePath("ActiveProjectiles")
@export var boss_spawn_point_path := NodePath("BossSpawnPoint")
@export var trap_interval: float = 0.65

var _state: State = State.WAITING
var _run_serial: int = 0
var _boss_ready_emitted: bool = false


# Huang Wan Jun 2204536 - Start the one-shot preparation trial only from its waiting state.
func start_encounter() -> void:
	if _state != State.WAITING:
		return
	if not _validate_wave_1_configuration():
		_abort_current_wave("BossEncounter Wave 1 configuration is incomplete.")
		return
	_state = State.WAVE_1
	_run_serial += 1
	if not _spawn_wave(slime_scene, _get_markers(wave_1_spawn_points_path), "Slime"):
		_state = State.WAITING
		return
	encounter_changed.emit()
	_run_wave_1_traps.call_deferred(_run_serial)
	_watch_current_wave.call_deferred(_run_serial)


# Huang Wan Jun 2204536 - Expose stable encounter state for the dungeon HUD and future boss integration.
func get_encounter_state() -> State:
	return _state

func is_boss_ready() -> bool:
	return _state == State.BOSS_READY

func get_boss_spawn_point() -> Marker2D:
	return get_node_or_null(boss_spawn_point_path) as Marker2D

func get_wave_total() -> int:
	return 5 if _state == State.WAVE_1 or _state == State.WAVE_2 else 0

func get_wave_remaining() -> int:
	return _living_minions().size()
```

Implement `_validate_wave_1_configuration()` so it checks the slime scene, exactly five markers, two `SpikeRow` children, `ActiveMinions`, `EntranceSafeArea`, and `BossSpawnPoint` before state advancement. `_get_markers(path)` must reject non-marker children. `_spawn_wave(...)` is completed atomically in Task 2; for this first green test it can instantiate exactly one actor per validated marker, name it with the prefix, add both boss groups, and parent it under `ActiveMinions`.

- [ ] **Step 4: Run the focused test**

Run the same Godot command. Expected: exit 0 and all controller-contract assertions print `PASS`.

- [ ] **Step 5: Commit the controller shell**

```powershell
git add BossEncounter/boss_encounter_controller.gd tests/test_boss_encounter.gd
git commit -m "feat: add boss trial controller shell"
```

---

### Task 2: Safe atomic wave spawning and living-minion progression

**Files:**
- Modify: `BossEncounter/boss_encounter_controller.gd`
- Modify: `tests/test_boss_encounter.gd`

**Interfaces:**
- Consumes: Task 1 controller state and named node paths; `SpawnPositionResolver.place_clear_of_walls(body, preferred_position, toward_position) -> Vector2`.
- Produces: atomic `_spawn_wave(scene, markers, prefix) -> bool`, `_living_minions() -> Array[Node]`, and automatic `WAVE_1 -> WAVE_2` transition.

- [ ] **Step 1: Add failing Wave 2, ownership, and death-state tests**

Append test sections that:

```gdscript
# Huang Wan Jun 2204536 - Count only living minions owned by this boss trial.
encounter.start_encounter()
var wave_1 := encounter.get_node("ActiveMinions").get_children()
_expect(wave_1.size() == 5, "Wave 1 creates exactly five slimes")
for minion in wave_1:
	_expect(minion.is_in_group("boss_minion") and minion.is_in_group("boss_enemy"), "trial minion has both boss groups")
	_expect(not minion.is_in_group("level1_enemy") and not minion.is_in_group("level2_enemy") and not minion.is_in_group("level3_enemy"), "trial minion cannot affect earlier levels")

wave_1[0].call("take_damage", wave_1[0].get("current_health"))
for minion in wave_1.slice(1):
	minion.queue_free()
await process_frame
await process_frame
_expect(encounter.get_encounter_state() == BossEncounterController.State.WAVE_2, "dead animating slime does not block Wave 2")
var wave_2 := encounter.get_node("ActiveMinions").get_children()
_expect(_count_script(wave_2, "res://skeleton.gd") == 3, "Wave 2 creates three skeletons")
_expect(_count_script(wave_2, "res://RangedEnemy.gd") == 2, "Wave 2 creates two ranged enemies")
```

Add a separate missing-scene case that sets `ranged_enemy_scene = null`, clears Wave 1, then asserts state remains `WAVE_1`, zero Wave 2 actors exist, and a captured `configuration_error(message)` signal names `ranged_enemy_scene`.

- [ ] **Step 2: Run and verify the tests fail before Wave 2 exists**

Run the focused test command. Expected: failures for the Wave 2 state/count assertions.

- [ ] **Step 3: Implement atomic spawn preparation and Wave 2 transition**

Add `signal configuration_error(message: String)` and use this algorithm:

```gdscript
# Huang Wan Jun 2204536 - Prepare and resolve an entire wave before attaching any actor permanently.
func _spawn_wave(scene: PackedScene, markers: Array[Marker2D], prefix: String) -> bool:
	var container := get_node_or_null(active_minions_path) as Node2D
	if scene == null or container == null or markers.is_empty():
		return _abort_current_wave("BossEncounter cannot spawn %s: scene, container, or markers are missing." % prefix)
	var prepared: Array[CollisionObject2D] = []
	for index in markers.size():
		var minion := scene.instantiate() as CollisionObject2D
		if minion == null:
			_free_prepared(prepared)
			return _abort_current_wave("BossEncounter %s scene must instantiate CollisionObject2D." % prefix)
		minion.name = "%s%d" % [prefix, index + 1]
		container.add_child(minion)
		minion.add_to_group("boss_minion")
		minion.add_to_group("boss_enemy")
		var resolved := SpawnPositionResolver.place_clear_of_walls(
			minion, markers[index].global_position, get_boss_spawn_point().global_position
		)
		if not _spawn_is_safe(minion, resolved):
			_free_prepared(prepared + [minion])
			return _abort_current_wave("BossEncounter found no safe position for %s%d." % [prefix, index + 1])
		prepared.append(minion)
	return true
```

`_spawn_is_safe` must reject points within `EntranceSafeArea` and overlap against solid-world/spike collision. Use a `PhysicsShapeQueryParameters2D` copied from the actor collision shape, `collision_mask = 1`, plus `Area2D.overlaps_body(minion)` for the safe area after one physics frame where necessary. Ensure abort removes every actor prepared for that wave and leaves traps safe.

Implement `_living_minions()` to filter descendants of this encounter's `ActiveMinions`, queued nodes, `current_health <= 0`, and known death states. Do not query the global `boss_minion` group for progression.

```gdscript
# Huang Wan Jun 2204536 - Progress only when every locally owned minion is truly defeated.
func _watch_current_wave(serial: int) -> void:
	while serial == _run_serial and _state in [State.WAVE_1, State.WAVE_2]:
		await get_tree().process_frame
		if serial != _run_serial or not is_inside_tree():
			return
		encounter_changed.emit()
		if not _living_minions().is_empty():
			continue
		if _state == State.WAVE_1:
			_begin_wave_2()
		else:
			_finish_trial()
		return
```

`_begin_wave_2()` must prevalidate `skeleton_scene`, `ranged_enemy_scene`, exactly three skeleton markers, exactly two ranged markers, `FireSweep`, and both endpoint markers before retracting spikes or changing state. Spawn both species as one transaction: if either species fails, free actors from both batches and keep `WAVE_1` with traps stopped and a clear error.

- [ ] **Step 4: Run the focused encounter test**

Expected: exit 0; five-slime count, group isolation, dead-animation progression, Wave 2 composition, and missing-scene atomicity pass.

- [ ] **Step 5: Commit safe progression**

```powershell
git add BossEncounter/boss_encounter_controller.gd tests/test_boss_encounter.gd
git commit -m "feat: add boss trial wave progression"
```

---

### Task 3: Wave-specific trap orchestration and boss-ready cleanup

**Files:**
- Modify: `BossEncounter/boss_encounter_controller.gd`
- Modify: `tests/test_boss_encounter.gd`

**Interfaces:**
- Consumes: Task 2 states and wave watcher; `SpikeRow.activate()`, `SpikeRow.force_safe()`, `FireSweep.sweep(from, to)`, and `FireSweep.force_safe()`.
- Produces: alternating Wave 1 spikes, repeating Wave 2 fire, `_finish_trial()`, one `boss_ready` emission, and owned-projectile cleanup.

- [ ] **Step 1: Add failing trap and completion tests**

Add assertions that sample both rows during Wave 1 for at least four activation cycles and record that each row becomes busy while the maximum simultaneous busy rows is one. Assert `FireSweep.State.SAFE` throughout Wave 1. After clearing Wave 1, assert both rows are safe, then observe the fire sweep reach `WARNING` and `ACTIVE` during Wave 2. Add two dummy children under `ActiveProjectiles`, clear all Wave 2 actors, then assert:

```gdscript
# Huang Wan Jun 2204536 - Finish preparation with a clean arena and one future-boss notification.
_expect(encounter.get_encounter_state() == BossEncounterController.State.BOSS_READY, "Wave 2 completion readies the boss arena")
_expect(encounter.get_node("FireSweep").state == FireSweep.State.SAFE, "fire sweep stops after Wave 2")
_expect(encounter.get_node("ActiveProjectiles").get_child_count() == 0, "owned projectiles are cleared")
_expect(encounter.get_node("BossSpawnPoint").visible, "boss marker becomes visible")
_expect(boss_ready_count == 1, "boss_ready emits exactly once")
encounter.start_encounter()
_expect(boss_ready_count == 1 and encounter.get_node("ActiveMinions").get_child_count() == 0, "re-entry after completion cannot restart")
```

- [ ] **Step 2: Run and confirm trap/completion assertions fail**

Expected: non-zero exit because trap coroutines and `_finish_trial()` are not implemented.

- [ ] **Step 3: Implement alternating spikes, fire loop, and terminal cleanup**

Use serial-guarded coroutines so synchronous stop or state changes cannot arm the next trap:

```gdscript
# Huang Wan Jun 2204536 - Alternate one warned spike row at a time while Wave 1 remains active.
func _run_wave_1_traps(serial: int) -> void:
	var rows := _get_spike_rows()
	var index := 0
	while serial == _run_serial and _state == State.WAVE_1:
		rows[index].activate()
		await rows[index].activation_finished
		if serial != _run_serial or _state != State.WAVE_1:
			return
		index = 1 - index
		await get_tree().create_timer(trap_interval).timeout


# Huang Wan Jun 2204536 - Repeat the warned fire crossing only while Wave 2 remains active.
func _run_wave_2_fire(serial: int) -> void:
	var fire := get_node(fire_sweep_path) as FireSweep
	var start := get_node(fire_start_marker_path) as Marker2D
	var finish := get_node(fire_end_marker_path) as Marker2D
	while serial == _run_serial and _state == State.WAVE_2:
		fire.sweep(start.global_position, finish.global_position)
		await fire.sweep_finished
		if serial != _run_serial or _state != State.WAVE_2:
			return
		await get_tree().create_timer(trap_interval).timeout
```

When Wave 1 clears, increment `_run_serial`, force both rows safe, validate/spawn Wave 2, set `WAVE_2`, increment `_run_serial` again, emit `encounter_changed`, then defer both the fire loop and watcher with the new serial.

```gdscript
# Huang Wan Jun 2204536 - End the preparation trial without pretending the unfinished boss was defeated.
func _finish_trial() -> void:
	if _state != State.WAVE_2:
		return
	_run_serial += 1
	_force_all_traps_safe()
	for projectile in get_node(active_projectiles_path).get_children():
		projectile.queue_free()
	_state = State.BOSS_READY
	get_boss_spawn_point().visible = true
	encounter_changed.emit()
	if not _boss_ready_emitted:
		_boss_ready_emitted = true
		boss_ready.emit(get_boss_spawn_point())
```

Make `_abort_current_wave(message) -> bool` increment the serial, force every trap safe, free only actors created for the failed incoming wave, call `push_error(message)`, emit `configuration_error(message)`, and return `false`.

- [ ] **Step 4: Run encounter and existing trap regression tests**

```powershell
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/test_boss_encounter.gd
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/test_spike_row.gd
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/test_fire_sweep.gd
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/test_level_3_trap_controller.gd
```

Expected: all four commands exit 0. Existing resource-leak and invalid-UID warnings may remain, but no new parse errors or assertion failures are acceptable.

- [ ] **Step 5: Commit trap orchestration**

```powershell
git add BossEncounter/boss_encounter_controller.gd tests/test_boss_encounter.gd
git commit -m "feat: orchestrate boss trial hazards"
```

---

### Task 4: Author the reusable boss encounter scene

**Files:**
- Create: `BossEncounter/BossEncounter.tscn`
- Modify: `tests/test_boss_encounter.gd`

**Interfaces:**
- Consumes: Task 3 controller and existing scenes at `res://Enemy/slime.tscn`, `res://skeleton.tscn`, `res://RangedEnemy.tscn`, `res://Level3Traps/SpikeRow.tscn`, and `res://Level3Traps/FireSweep.tscn`.
- Produces: a self-contained scene with the exact node tree required by the spec and coordinates relative to the existing boss-room focal point.

- [ ] **Step 1: Add a failing real-scene structure test**

Load `res://BossEncounter/BossEncounter.tscn`, instantiate it, and assert every required node and count. Also assert `BossSpawnPoint.visible == false`, the two spike rows are distinct, all five spawn collections have their exact marker counts, and both fire markers lie outside the entrance safe polygon.

```gdscript
# Huang Wan Jun 2204536 - Keep the authored boss-room scene compatible with the controller contract.
var packed := load("res://BossEncounter/BossEncounter.tscn") as PackedScene
_expect(packed != null, "boss encounter scene loads")
var authored := packed.instantiate() as BossEncounterController
_expect(authored.get_node("Wave1SpawnPoints").get_child_count() == 5, "authored scene has five slime markers")
_expect(authored.get_node("Wave2SkeletonSpawnPoints").get_child_count() == 3, "authored scene has three skeleton markers")
_expect(authored.get_node("Wave2RangedSpawnPoints").get_child_count() == 2, "authored scene has two ranged markers")
```

- [ ] **Step 2: Run and verify the missing scene fails**

Expected: non-zero exit naming `BossEncounter.tscn`.

- [ ] **Step 3: Create the scene with exact authored nodes and positions**

Create a `Node2D` root named `BossEncounter`, attach the controller, and assign all three enemy scene exports. Author the root around the boss-room focal point when instanced: Dungeon-local `(1054, -2268)`. Use these local coordinates:

| Node | Local position / shape |
|---|---|
| `EntranceTrigger` | `(-233, 777)`, rectangle `Vector2(300, 180)` |
| `EntranceSafeArea` | `(-170, 625)`, rectangle `Vector2(360, 260)` |
| Wave 1 `Slime1..5` | `(-260, 330)`, `(0, 300)`, `(260, 330)`, `(-150, -40)`, `(150, -40)` |
| Wave 2 `Skeleton1..3` | `(-220, 190)`, `(0, 100)`, `(220, 190)` |
| Wave 2 `Ranged1..2` | `(-240, -250)`, `(240, -250)` |
| `SpikeRowA` | `(-250, 250)`, `tile_count = 3`, `tile_step = Vector2(128, -64)` |
| `SpikeRowB` | `(-125, 15)`, `tile_count = 3`, `tile_step = Vector2(128, -64)` |
| `FireStartMarker` | `(-330, 260)` |
| `FireEndMarker` | `(330, -70)` |
| `BossSpawnPoint` | `(0, -100)`, initially hidden |

Give `EntranceTrigger` collision layer 0 and player collision mask 2, and connect its `body_entered` signal to `_on_entrance_trigger_body_entered` in the controller. That handler must require `body.is_in_group("player")` before calling `start_encounter()`.

Do not add editor-only duplicate spike art; the real `SpikeRow` scenes already build their isometric visuals. Do not place any spawn marker inside `EntranceSafeArea`.

- [ ] **Step 4: Run the real-scene structure and behavior tests**

Expected: focused encounter test exits 0. Inspect any physics warning from spawn resolution; if one appears, adjust only the listed local marker that overlaps actual boss-room collision and update the test’s expected position in the same commit.

- [ ] **Step 5: Commit the authored encounter scene**

```powershell
git add BossEncounter/BossEncounter.tscn BossEncounter/boss_encounter_controller.gd tests/test_boss_encounter.gd
git commit -m "feat: author boss trial arena layout"
```

---

### Task 5: Integrate the trial into Dungeon and the existing HUD

**Files:**
- Modify: `Dungeon.tscn`
- Modify: `dungeon.gd`
- Modify: `tests/test_dungeon_lifecycle.gd`

**Interfaces:**
- Consumes: `BossEncounterController` public state/count API from Task 1 and the authored scene from Task 4.
- Produces: one `BossEncounter` instance in the boss room, automatic start when `BossEntrance` selects Level 4, and accurate Wave 1/Wave 2/ready HUD copy.

- [ ] **Step 1: Add failing Dungeon integration assertions**

Extend the lifecycle test after instantiating `Dungeon.tscn`:

```gdscript
# Huang Wan Jun 2204536 - Connect the existing Level 4 entrance and HUD to the reusable boss trial.
var boss_encounter := dungeon.get_node_or_null("BossEncounter") as BossEncounterController
_expect(boss_encounter != null, "Dungeon instances the boss encounter")
dungeon.call("_on_level_entrance_entered", 4)
await process_frame
_expect(boss_encounter.get_encounter_state() == BossEncounterController.State.WAVE_1, "entering Level 4 starts Wave 1")
dungeon.call("_update_enemy_counter")
var counter := dungeon.get_node("LevelClearUI/EnemyCounterLabel") as Label
_expect(counter.visible and counter.text.contains("BOSS TRIAL - WAVE 1"), "Level 4 HUD announces Wave 1")
```

Add direct controller state transitions in a fixture or call a test-only actor-clear helper to assert the HUD later shows `BOSS TRIAL - WAVE 2`, then exactly `BOSS ARENA READY` without `LEVEL CLEAR` or `Enemies Left`.

- [ ] **Step 2: Run the lifecycle test and confirm integration fails**

Run the headless command for `res://tests/test_dungeon_lifecycle.gd`. Expected: failure because `Dungeon/BossEncounter` does not exist.

- [ ] **Step 3: Make the minimal scene and script integration**

Before editing, record `git diff -- Dungeon.tscn` and keep it available for comparison. Add one external packed-scene resource and one root child instance only:

```text
[ext_resource type="PackedScene" path="res://BossEncounter/BossEncounter.tscn" id="74_boss_encounter"]

[node name="BossEncounter" parent="." instance=ExtResource("74_boss_encounter")]
position = Vector2(1054, -2268)
```

Do not normalize resource IDs, reorder existing nodes, or touch tilemap/collision data. In `dungeon.gd`, add:

```gdscript
@onready var boss_encounter: BossEncounterController = $BossEncounter


# Huang Wan Jun 2204536 - Start the authored boss trial when the unlocked boss room becomes current.
func _on_level_entrance_entered(level_number: int) -> void:
	current_level = level_number
	# existing minimap and counter-position code remains unchanged
	if level_number == 3:
		level_3_traps.start_encounter()
	elif level_number == 4:
		boss_encounter.start_encounter()
```

Extend `_update_enemy_counter()` with a Level 4 branch:

```gdscript
		4:
			enemy_counter_label.show()
			match boss_encounter.get_encounter_state():
				BossEncounterController.State.WAVE_1:
					enemy_counter_label.text = "BOSS TRIAL - WAVE 1\nEnemies Defeated: %d / 5\nEnemies Left: %d" % [5 - boss_encounter.get_wave_remaining(), boss_encounter.get_wave_remaining()]
				BossEncounterController.State.WAVE_2:
					enemy_counter_label.text = "BOSS TRIAL - WAVE 2\nEnemies Defeated: %d / 5\nEnemies Left: %d" % [5 - boss_encounter.get_wave_remaining(), boss_encounter.get_wave_remaining()]
				BossEncounterController.State.BOSS_READY:
					enemy_counter_label.text = "BOSS ARENA READY"
				_:
					enemy_counter_label.text = "BOSS TRIAL"
```

- [ ] **Step 4: Verify focused integration and inspect the scene diff**

Run `test_dungeon_lifecycle.gd` and `test_boss_encounter.gd`, then run:

```powershell
git diff --check
git diff -- Dungeon.tscn
```

Expected: tests exit 0; scene diff contains only the encounter resource/instance plus the user’s exact pre-existing 48-line layout diff. If unrelated scene lines changed, restore those individual lines with `apply_patch`; never reset the entire scene.

- [ ] **Step 5: Commit only the intended integration hunks**

Because `Dungeon.tscn` already contains user changes, stage the new scene hunks interactively or apply the integration in an isolated worktree and commit there. Confirm `git diff --cached -- Dungeon.tscn` contains only the new external resource and instance before committing.

```powershell
git add dungeon.gd tests/test_dungeon_lifecycle.gd
git add -p Dungeon.tscn
git diff --cached --check
git commit -m "feat: integrate boss trial into dungeon"
```

---

### Task 6: Verify Level 4 minimap isolation

**Files:**
- Modify: `tests/test_dungeon_minimap.gd`
- Modify only if the test exposes a real omission: `UI/dungeon_minimap.gd`

**Interfaces:**
- Consumes: existing `{4: "boss_enemy"}` minimap mapping and Task 4 boss encounter.
- Produces: regression coverage that the boss room shows only living trial enemies.

- [ ] **Step 1: Add the failing-or-already-green Level 4 marker test**

Add a focused section using the real authored encounter:

```gdscript
# Huang Wan Jun 2204536 - Show only living trial minions while the player occupies Level 4.
var authored := (load("res://BossEncounter/BossEncounter.tscn") as PackedScene).instantiate() as BossEncounterController
root.add_child(authored)
await process_frame
authored.start_encounter()
minimap.set_current_level(4)
minimap.refresh_markers()
_expect(minimap.get_enemy_markers().size() == 5, "Level 4 minimap shows five Wave 1 minions")
var unrelated := Node2D.new()
unrelated.add_to_group("level3_enemy")
root.add_child(unrelated)
minimap.refresh_markers()
_expect(minimap.get_enemy_markers().size() == 5, "Level 4 minimap hides inactive-level enemies")
var dead := authored.get_node("ActiveMinions").get_child(0)
dead.call("take_damage", dead.get("current_health"))
minimap.refresh_markers()
_expect(minimap.get_enemy_markers().size() == 4, "dead animating trial minion disappears immediately")
```

- [ ] **Step 2: Run the minimap test**

Expected: this should already pass because `DungeonMinimap` maps Level 4 to `boss_enemy` and recognizes all three existing enemy death states. If it fails, confirm whether the controller omitted a group or the minimap lacks the actor script path before changing production code.

- [ ] **Step 3: Make only the minimal production correction if required**

The expected production mapping remains:

```gdscript
# Huang Wan Jun 2204536 - Keep Level 4 markers isolated to the boss encounter.
const ENEMY_GROUP_BY_LEVEL := {1: "level1_enemy", 2: "level2_enemy", 3: "level3_enemy", 4: "boss_enemy"}
```

Do not change the map geometry, panel location, reveal rules, or marker styling in this task.

- [ ] **Step 4: Run minimap and encounter tests**

Expected: both exit 0 with no new assertions or parse errors.

- [ ] **Step 5: Commit minimap coverage**

```powershell
git add tests/test_dungeon_minimap.gd
git add UI/dungeon_minimap.gd
git commit -m "test: cover boss trial minimap markers"
```

If `UI/dungeon_minimap.gd` did not need a change, omit it from `git add`.

---

### Task 7: Final focused verification and visual arena check

**Files:**
- Modify only if verification finds a defect: files already named in Tasks 1–6

**Interfaces:**
- Consumes: completed encounter, authored scene, Dungeon integration, HUD, and minimap behavior.
- Produces: a verified two-wave arena ready for the friend’s future boss scene.

- [ ] **Step 1: Run the complete focused suite**

Run these tests individually so one known warning cannot hide another result:

```powershell
$godot = 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/test_boss_encounter.gd
& $godot --headless --path . --script res://tests/test_spike_row.gd
& $godot --headless --path . --script res://tests/test_fire_sweep.gd
& $godot --headless --path . --script res://tests/test_level_3_trap_controller.gd
& $godot --headless --path . --script res://tests/test_dungeon_minimap.gd
& $godot --headless --path . --script res://tests/test_level_3_ranged_enemies.gd
& $godot --headless --path . --script res://tests/test_dungeon_lifecycle.gd
```

Expected: every command exits 0. Document the known pre-existing `room_fade_area.gd:205` null-scene, invalid slime UID, and resource/RID leak warnings separately; do not claim they were introduced or fixed here.

- [ ] **Step 2: Run static scene/script checks**

```powershell
& $godot --headless --path . --editor --quit-after 3
git diff --check
rg -n '<<<<<<<|=======|>>>>>>>' --glob '*.gd' --glob '*.tscn'
rg -n 'pass$|push_error\("unfinished' BossEncounter tests/test_boss_encounter.gd
```

Expected: no parse errors, conflict markers, whitespace errors, empty function bodies, or unfinished-error branches in the boss work.

- [ ] **Step 3: Perform the visual play-through**

Run `Dungeon.tscn`, use existing debug clearing to unlock Levels 2 and 3, enter Level 4, and verify:

- the entrance remains safe on arrival;
- five slimes appear away from walls;
- only one spike row warns/activates at a time with a walkable gap;
- Wave 2 waits for every slime death animation state;
- three skeletons and two ranged enemies appear in readable positions;
- the fire warning is visible and its path does not cross the safe entrance area;
- the HUD changes through both exact wave labels to `BOSS ARENA READY`;
- the minimap shows only living Level 4 enemies;
- the final marker appears and no fake boss or victory text appears.

- [ ] **Step 4: Correct only observed authored-coordinate defects and rerun affected tests**

If a spawn or hazard intersects the current wall collision, change that exact marker coordinate in `BossEncounter.tscn`, add its regression assertion to `tests/test_boss_encounter.gd`, and rerun the focused suite. Do not change enemy AI or Level 1–3 layout to compensate for a boss-room placement issue.

- [ ] **Step 5: Commit any verification fixes and report the handoff API**

```powershell
git add BossEncounter Dungeon.tscn dungeon.gd tests/test_boss_encounter.gd tests/test_dungeon_lifecycle.gd tests/test_dungeon_minimap.gd
git diff --cached --check
git commit -m "fix: validate boss trial arena placement"
```

Skip this commit if verification required no changes. In the final handoff, tell the boss developer to connect to `BossEncounter.boss_ready(spawn_point)` or call `is_boss_ready()` and instantiate the future boss at `get_boss_spawn_point().global_position`.

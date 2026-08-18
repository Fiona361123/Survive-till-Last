# Level 2 Collapsing Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dry Level 2 chasm with a short three-section collapsing bridge, a longer safe bridge, player damage and safe respawn, enemy removal, and automatic rebuilding.

**Architecture:** A reusable `FallHazard` Area2D owns player/enemy fall consequences. Each reusable `CollapsingBridgeSection` owns one bridge tile, an independent warning timer, a disabled-until-collapse FallHazard, and its rebuild timer. Dungeon.tscn composes three sections, permanent chasm fall zones, two safe markers, and a separate safe bridge.

**Tech Stack:** Godot 4.6, GDScript, Area2D, TileMapLayer, CollisionPolygon2D, Timer, Marker2D.

**Spec:** `docs/superpowers/specs/2026-08-17-level-2-collapsing-bridge-design.md`

## Global Constraints

- Add `# Huang Wan Jun 2204536` near the top of every new `.gd` file.
- Warning duration is exactly 3 seconds in production.
- The open gap lasts exactly 5 seconds in production.
- Each unstable section operates independently.
- Player fall calls `take_damage(1)` and respawns at the closest safe marker.
- Enemy fall calls `queue_free()`.
- Do not modify the existing Player or Enemy health/death behavior unless a verified integration defect requires it.
- Level 2 contains no water asset.

---

## File Structure

- Create `fall_hazard.gd`: reusable fall consequence and closest-marker selection.
- Create `collapsing_bridge_section.gd`: isolated state machine for one unstable section.
- Create `CollapsingBridgeSection.tscn`: reusable visual/collision/timer scene.
- Create `level_2_bridge_system.gd`: supplies shared safe markers to sections and permanent hazards.
- Create `tests/test_collapsing_bridge.gd`: behavior tests for hazards and sections.
- Modify `Dungeon.tscn`: dry chasm layout, permanent fall areas, safe bridge, three unstable sections, and respawn markers.
- Modify `tests/test_level_clear.gd`: structural checks for the Level 2 bridge system without changing existing level-clear behavior.

---

### Task 1: Reusable Fall Hazard

**Files:**
- Create: `fall_hazard.gd`
- Create: `tests/test_collapsing_bridge.gd`

**Interfaces:**
- Consumes: bodies in groups `player`, `enemy`, or `level1_enemy`; player method `take_damage(amount: int)`.
- Produces: `configure_respawn_markers(left: Marker2D, right: Marker2D) -> void`; `_on_body_entered(body: Node2D) -> void`; `_on_body_exited(body: Node2D) -> void`.

- [ ] **Step 1: Write the failing fall-hazard tests**

Create `tests/test_collapsing_bridge.gd` with the author comment and a minimal fake player:

```gdscript
# Huang Wan Jun 2204536
extends SceneTree

var failures: int = 0

class FakePlayer extends CharacterBody2D:
	var damage_taken: int = 0
	func take_damage(amount: int) -> void:
		damage_taken += amount

func _initialize() -> void:
	await process_frame
	await _test_player_fall_damages_once_and_respawns()
	await _test_enemy_fall_removes_enemy()
	quit(0 if failures == 0 else 1)

func _test_player_fall_damages_once_and_respawns() -> void:
	var hazard := Area2D.new()
	hazard.set_script(load("res://fall_hazard.gd"))
	root.add_child(hazard)
	var left := Marker2D.new()
	left.global_position = Vector2(20, 10)
	root.add_child(left)
	var right := Marker2D.new()
	right.global_position = Vector2(300, 10)
	root.add_child(right)
	hazard.configure_respawn_markers(left, right)
	var player := FakePlayer.new()
	player.add_to_group("player")
	player.global_position = Vector2(40, 10)
	root.add_child(player)
	hazard._on_body_entered(player)
	hazard._on_body_entered(player)
	_expect(player.damage_taken == 1, "one overlap applies one fall damage")
	_expect(player.global_position == left.global_position, "player uses closest safe marker")
	player.queue_free()
	hazard.queue_free()
	left.queue_free()
	right.queue_free()
	await process_frame

func _test_enemy_fall_removes_enemy() -> void:
	var hazard := Area2D.new()
	hazard.set_script(load("res://fall_hazard.gd"))
	root.add_child(hazard)
	var enemy := CharacterBody2D.new()
	enemy.add_to_group("enemy")
	root.add_child(enemy)
	hazard._on_body_entered(enemy)
	await process_frame
	_expect(not is_instance_valid(enemy), "enemy is removed by a fall")
	hazard.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
```

- [ ] **Step 2: Run the test and verify the missing script failure**

Run:

```powershell
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\USER\Documents\Survive-till-Last' --script res://tests/test_collapsing_bridge.gd
```

Expected: FAIL because `res://fall_hazard.gd` does not exist. If Godot crashes with the known engine signal 11 before script execution, record that limitation and run the static checks from Task 4 as an additional verification path.

- [ ] **Step 3: Implement the minimal fall hazard**

Create `fall_hazard.gd`:

```gdscript
# Huang Wan Jun 2204536
extends Area2D
class_name FallHazard

@export var fall_damage: int = 1

var left_marker: Marker2D
var right_marker: Marker2D
var handled_body_ids: Dictionary = {}

func configure_respawn_markers(left: Marker2D, right: Marker2D) -> void:
	left_marker = left
	right_marker = right

func _on_body_entered(body: Node2D) -> void:
	var body_id := body.get_instance_id()
	if handled_body_ids.has(body_id):
		return
	handled_body_ids[body_id] = true
	if body.is_in_group("player"):
		_handle_player_fall(body)
	elif body.is_in_group("enemy") or body.is_in_group("level1_enemy"):
		body.queue_free()

func _on_body_exited(body: Node2D) -> void:
	handled_body_ids.erase(body.get_instance_id())

func reset_handled_bodies() -> void:
	handled_body_ids.clear()

func _handle_player_fall(player: Node2D) -> void:
	if player.has_method("take_damage"):
		player.take_damage(fall_damage)
	var marker := _closest_marker(player.global_position)
	if marker:
		player.global_position = marker.global_position

func _closest_marker(from_position: Vector2) -> Marker2D:
	if left_marker == null:
		return right_marker
	if right_marker == null:
		return left_marker
	if from_position.distance_squared_to(left_marker.global_position) <= from_position.distance_squared_to(right_marker.global_position):
		return left_marker
	return right_marker
```

- [ ] **Step 4: Connect the Area2D signals in code**

Add to `fall_hazard.gd`:

```gdscript
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
```

- [ ] **Step 5: Run the fall-hazard tests**

Run the Task 1 command again. Expected: both assertions pass, or the previously documented Godot engine crash occurs before test execution.

- [ ] **Step 6: Commit Task 1**

```powershell
git add fall_hazard.gd tests/test_collapsing_bridge.gd
git commit -m "feat: add reusable chasm fall hazard"
```

---

### Task 2: Independent Collapsing Bridge Section

**Files:**
- Create: `collapsing_bridge_section.gd`
- Create: `CollapsingBridgeSection.tscn`
- Modify: `tests/test_collapsing_bridge.gd`

**Interfaces:**
- Consumes: `FallHazard.configure_respawn_markers(left, right)` and `FallHazard.reset_handled_bodies()`.
- Produces: enum `SectionState`; `configure_respawn_markers(left: Marker2D, right: Marker2D) -> void`; `_on_trigger_body_entered(body: Node2D) -> void`; `state: SectionState`.

- [ ] **Step 1: Add failing state-transition tests**

Append these calls inside `_initialize()` before `quit`:

```gdscript
	await _test_section_collapses_and_rebuilds()
	await _test_sections_are_independent()
```

Append the tests:

```gdscript
func _make_section() -> Area2D:
	var scene := load("res://CollapsingBridgeSection.tscn") as PackedScene
	var section := scene.instantiate() as Area2D
	section.warning_duration = 0.02
	section.rebuild_delay = 0.03
	root.add_child(section)
	return section

func _test_section_collapses_and_rebuilds() -> void:
	var section := _make_section()
	var player := FakePlayer.new()
	player.add_to_group("player")
	root.add_child(player)
	section._on_trigger_body_entered(player)
	_expect(section.state == section.SectionState.WARNING, "section starts warning")
	await create_timer(0.03).timeout
	_expect(section.state == section.SectionState.COLLAPSED, "section collapses after warning")
	_expect(not section.get_node("BridgeTile").enabled, "collapsed tile collision is disabled")
	await create_timer(0.04).timeout
	_expect(section.state == section.SectionState.READY, "section rebuilds")
	_expect(section.get_node("BridgeTile").enabled, "rebuilt tile collision returns")
	player.queue_free()
	section.queue_free()

func _test_sections_are_independent() -> void:
	var first := _make_section()
	var second := _make_section()
	var enemy := CharacterBody2D.new()
	enemy.add_to_group("enemy")
	root.add_child(enemy)
	first._on_trigger_body_entered(enemy)
	_expect(first.state == first.SectionState.WARNING, "triggered section warns")
	_expect(second.state == second.SectionState.READY, "other section remains ready")
	enemy.queue_free()
	first.queue_free()
	second.queue_free()
```

- [ ] **Step 2: Run the tests and verify the scene-missing failure**

Run the Task 1 command. Expected: FAIL because `CollapsingBridgeSection.tscn` does not exist.

- [ ] **Step 3: Implement the section state machine**

Create `collapsing_bridge_section.gd`:

```gdscript
# Huang Wan Jun 2204536
extends Area2D
class_name CollapsingBridgeSection

enum SectionState { READY, WARNING, COLLAPSED, REBUILDING }

@export var warning_duration: float = 3.0
@export var rebuild_delay: float = 5.0

@onready var bridge_tile: TileMapLayer = $BridgeTile
@onready var gap_area: FallHazard = $GapArea
@onready var warning_timer: Timer = $WarningTimer
@onready var rebuild_timer: Timer = $RebuildTimer

var state: SectionState = SectionState.READY
var base_tile_position: Vector2

func _ready() -> void:
	base_tile_position = bridge_tile.position
	body_entered.connect(_on_trigger_body_entered)
	warning_timer.timeout.connect(_collapse)
	rebuild_timer.timeout.connect(_rebuild)
	gap_area.monitoring = false

func configure_respawn_markers(left: Marker2D, right: Marker2D) -> void:
	gap_area.configure_respawn_markers(left, right)

func _on_trigger_body_entered(body: Node2D) -> void:
	if state != SectionState.READY:
		return
	if not body.is_in_group("player") and not body.is_in_group("enemy") and not body.is_in_group("level1_enemy"):
		return
	state = SectionState.WARNING
	warning_timer.start(warning_duration)

func _process(_delta: float) -> void:
	if state == SectionState.WARNING:
		bridge_tile.position = base_tile_position + Vector2(sin(Time.get_ticks_msec() * 0.045) * 3.0, 0)
		bridge_tile.modulate = Color(1.0, 0.55, 0.45) if int(Time.get_ticks_msec() / 150) % 2 == 0 else Color.WHITE

func _collapse() -> void:
	state = SectionState.COLLAPSED
	bridge_tile.position = base_tile_position
	bridge_tile.modulate = Color.WHITE
	bridge_tile.visible = false
	bridge_tile.enabled = false
	gap_area.monitoring = true
	for body in gap_area.get_overlapping_bodies():
		gap_area._on_body_entered(body)
	rebuild_timer.start(rebuild_delay)

func _rebuild() -> void:
	state = SectionState.REBUILDING
	gap_area.monitoring = false
	gap_area.reset_handled_bodies()
	bridge_tile.enabled = true
	bridge_tile.visible = true
	state = SectionState.READY
```

- [ ] **Step 4: Create the reusable scene**

Create `CollapsingBridgeSection.tscn` with:

- Root `Area2D` using `collapsing_bridge_section.gd`.
- `BridgeTile` as a one-cell `TileMapLayer` using `bridgeBroken_E.png` and a diamond collision polygon matching the 256 by 128 isometric footprint.
- Root `TriggerShape` as a `CollisionPolygon2D` covering the bridge footprint.
- `GapArea` as `Area2D` using `fall_hazard.gd`, initially `monitoring = false`.
- `GapArea/GapShape` as the same footprint polygon.
- `WarningTimer` and `RebuildTimer`, both `one_shot = true`.
- Collision mask set to the layers used by Player and Enemy bodies in the existing scenes.

- [ ] **Step 5: Run the bridge-section tests**

Run the Task 1 command. Expected: fall-hazard tests and section tests pass, or the documented Godot signal-11 crash occurs first.

- [ ] **Step 6: Commit Task 2**

```powershell
git add collapsing_bridge_section.gd CollapsingBridgeSection.tscn tests/test_collapsing_bridge.gd
git commit -m "feat: add independently collapsing bridge section"
```

---

### Task 3: Compose the Level 2 Two-Route Chasm

**Files:**
- Create: `level_2_bridge_system.gd`
- Modify: `Dungeon.tscn`
- Modify: `tests/test_level_clear.gd`

**Interfaces:**
- Consumes: `CollapsingBridgeSection.configure_respawn_markers(left, right)`; `FallHazard.configure_respawn_markers(left, right)`.
- Produces: Dungeon nodes `Level2BridgeSystem`, `SafeBridge`, `UnstableSection1`, `UnstableSection2`, `UnstableSection3`, `SafeRespawnLeft`, and `SafeRespawnRight`.

- [ ] **Step 1: Add failing Dungeon structure checks**

Add to `_test_dungeon_scene_has_level_clear_nodes()` in `tests/test_level_clear.gd`:

```gdscript
	# Huang Wan Jun 2204536
	_expect(dungeon.get_node_or_null("Level2BridgeSystem") is Node2D,
		"Dungeon has the Level 2 bridge system")
	_expect(dungeon.get_node_or_null("Level2BridgeSystem/SafeBridge") is TileMapLayer,
		"Level 2 has a safe alternative bridge")
	for section_name in ["UnstableSection1", "UnstableSection2", "UnstableSection3"]:
		_expect(dungeon.get_node_or_null("Level2BridgeSystem/" + section_name) is CollapsingBridgeSection,
			"Level 2 has independent " + section_name)
	_expect(dungeon.get_node_or_null("Level2BridgeSystem/SafeRespawnLeft") is Marker2D,
		"Level 2 has a left safe respawn marker")
	_expect(dungeon.get_node_or_null("Level2BridgeSystem/SafeRespawnRight") is Marker2D,
		"Level 2 has a right safe respawn marker")
```

- [ ] **Step 2: Run the level-clear test and verify it fails**

Run:

```powershell
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\USER\Documents\Survive-till-Last' --script res://tests/test_level_clear.gd
```

Expected: FAIL because `Level2BridgeSystem` is missing, unless the known engine crash happens first.

- [ ] **Step 3: Build the dry chasm floor silhouette**

In `Dungeon.tscn`:

- Preserve the corridor entering Level 2.
- Remove a broad band of Level 2 dirt cells to form empty space between two solid islands.
- Keep enough solid dirt around both bridge endpoints for combat and respawn.
- Do not add water textures.
- Keep the current Level 2 cave props only on solid island cells.

- [ ] **Step 4: Add the bridge system nodes**

Add `Level2BridgeSystem` under `Dungeon` with:

- `SafeRespawnLeft` on solid ground before both bridge routes.
- `SafeRespawnRight` on solid ground after both bridge routes.
- A short straight main crossing containing `UnstableSection1`, `UnstableSection2`, and `UnstableSection3` with small safe bridge tiles between endpoints.
- A longer side crossing made entirely from `SafeBridge` tiles.
- Multiple permanent chasm `Area2D` pieces using `fall_hazard.gd` around the bridge corridors so walking beside either bridge counts as falling.

Set production values on every unstable section:

```text
warning_duration = 3.0
rebuild_delay = 5.0
```

- [ ] **Step 5: Configure marker references**

Create `level_2_bridge_system.gd`:

```gdscript
# Huang Wan Jun 2204536
extends Node2D

@onready var safe_respawn_left: Marker2D = $SafeRespawnLeft
@onready var safe_respawn_right: Marker2D = $SafeRespawnRight
@onready var permanent_fall_areas: Node2D = $PermanentFallAreas

func _ready() -> void:
	for child in get_children():
		if child is CollapsingBridgeSection:
			child.configure_respawn_markers(safe_respawn_left, safe_respawn_right)
	for child in permanent_fall_areas.get_children():
		if child is FallHazard:
			child.configure_respawn_markers(safe_respawn_left, safe_respawn_right)
```

Attach this script to `Level2BridgeSystem`. Name the permanent-hazard container exactly `PermanentFallAreas`.

- [ ] **Step 6: Connect the three section trigger shapes and permanent fall areas**

Confirm each Area2D mask detects both the current Player CharacterBody2D and Enemy CharacterBody2D collision layers. Confirm safe bridge cells have solid collision and permanent fall areas do not overlap the safe walkway.

- [ ] **Step 7: Run both automated test scripts**

Run the Task 1 and Task 3 commands. Expected: all behavior and structure assertions pass, or the known signal-11 crash is recorded before execution.

- [ ] **Step 8: Commit Task 3**

```powershell
git add Dungeon.tscn tests/test_level_clear.gd level_2_bridge_system.gd
git commit -m "feat: build Level 2 collapsing bridge encounter"
```

---

### Task 4: Integration and Visual Verification

**Files:**
- Modify: `tests/test_collapsing_bridge.gd`
- Modify: `Dungeon.tscn` only if verification exposes a bridge placement or collision defect.

**Interfaces:**
- Consumes: completed Level 2 bridge system.
- Produces: verified timing, damage, enemy removal, independent rebuilding, safe route, and clear visual feedback.

- [ ] **Step 1: Add a complete-cycle integration test**

Add a test that instantiates `Dungeon.tscn`, finds all three unstable sections, sets short test durations, triggers only the middle section, and asserts:

```gdscript
func _test_dungeon_bridge_cycle() -> void:
	var dungeon := (load("res://Dungeon.tscn") as PackedScene).instantiate()
	root.add_child(dungeon)
	var sections: Array[CollapsingBridgeSection] = []
	for section_name in ["UnstableSection1", "UnstableSection2", "UnstableSection3"]:
		sections.append(dungeon.get_node("Level2BridgeSystem/" + section_name))
	for section in sections:
		section.warning_duration = 0.02
		section.rebuild_delay = 0.03
	var enemy := CharacterBody2D.new()
	enemy.add_to_group("enemy")
	root.add_child(enemy)
	sections[1]._on_trigger_body_entered(enemy)
	_expect(sections[0].state == sections[0].SectionState.READY, "first section stays ready")
	_expect(sections[2].state == sections[2].SectionState.READY, "third section stays ready")
	await create_timer(0.03).timeout
	_expect(sections[1].state == sections[1].SectionState.COLLAPSED, "middle section collapses alone")
	await create_timer(0.04).timeout
	_expect(sections[1].state == sections[1].SectionState.READY, "middle section rebuilds")
	dungeon.queue_free()
	enemy.queue_free()
```

- [ ] **Step 2: Run all automated checks**

Run both test commands and `git diff --check`. Expected: zero script failures and no whitespace errors, subject to the documented Godot engine crash.

- [ ] **Step 3: Perform manual Godot verification**

In the Godot editor:

1. Reload `Dungeon.tscn` from disk if prompted.
2. Run the project and enter Level 2.
3. Walk onto unstable section 1 and confirm a visible 3-second shake/flash.
4. Confirm only section 1 disappears.
5. Step into its open gap and confirm exactly 1 HP is removed and the player moves to the closest marker.
6. Lead an enemy into an open gap and confirm the enemy disappears.
7. Confirm the section remains missing for 5 seconds and then returns with collision.
8. Trigger two different sections at different times and confirm their timers remain independent.
9. Cross the longer safe bridge and confirm it never shakes or collapses.
10. Try walking beside both bridges and confirm permanent chasm areas apply the same fall behavior.

- [ ] **Step 4: Commit verification adjustments**

```powershell
git add tests/test_collapsing_bridge.gd Dungeon.tscn
git commit -m "test: verify Level 2 bridge encounter"
```

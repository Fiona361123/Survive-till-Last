# Progression Minimap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bottom-right dungeon minimap that reveals sections after level clears, always tracks the player, and shows living enemies from the current level only.

**Architecture:** A reusable `DungeonMinimap` Control draws a fixed panel, authored dungeon-section polygons, and live markers using one aspect-preserving world-to-panel transform. `dungeon.gd` remains the progression source of truth and tells the minimap when the current level changes or the next section is unlocked.

**Tech Stack:** Godot 4.6, GDScript, Control/CanvasLayer drawing, SceneTree headless tests

**Spec:** `docs/superpowers/specs/2026-09-06-progression-minimap-design.md`

## Global Constraints

- Place the minimap approximately 24 pixels from the bottom-right corner at approximately 230 by 160 pixels.
- Level 1 is initially revealed; clearing Levels 1, 2, and 3 reveals Levels 2, 3, and boss respectively.
- Only the current level's living enemy group is shown; the player marker is always shown.
- Preserve aspect ratio and clamp marker positions inside the drawable map region.
- Unrevealed sections are fully omitted, not drawn as silhouettes.
- Existing Guard Halo, enemy-counter, and weapon-store UI must remain unchanged.
- Do not discard or overwrite the user's existing uncommitted `Dungeon.tscn` trap, boundary, unique-ID, or enemy-position changes.
- Every new or modified minimap script section and hand-authored minimap test section must contain a concise comment with `Huang Wan Jun 2204536` explaining its purpose.
- Do not commit `.superpowers/` browser-session data.

---

## File Structure

- Create `UI/dungeon_minimap.gd`: owns revealed-level state, active enemy filtering, world conversion, marker snapshots, and custom drawing.
- Create `UI/DungeonMinimap.tscn`: configures the fixed-size bottom-right Control and its exported world boundary.
- Create `tests/test_dungeon_minimap.gd`: focused headless coverage for layout, reveal rules, transform, marker filtering, freed nodes, and missing groups.
- Modify `dungeon.gd`: connects existing progression and entrance events to the minimap's public interface.
- Modify `Dungeon.tscn`: instances the minimap below `LevelClearUI` without altering the user's other scene edits.

### Task 1: Minimap Layout, Reveal State, and Coordinate Transform

**Files:**
- Create: `UI/dungeon_minimap.gd`
- Create: `UI/DungeonMinimap.tscn`
- Create: `tests/test_dungeon_minimap.gd`

**Interfaces:**
- Consumes: Godot `Control`, `Rect2`, `Vector2`, and `_draw()`.
- Produces: `class_name DungeonMinimap`, `reveal_level(level_number: int) -> void`, `is_level_revealed(level_number: int) -> bool`, `get_revealed_levels() -> Array[int]`, and `world_to_minimap(world_position: Vector2) -> Vector2`.

- [ ] **Step 1: Write failing scene, reveal, and transform tests**

Create `tests/test_dungeon_minimap.gd` as a `SceneTree` test. Include the attribution comment immediately above the hand-authored assertions:

```gdscript
extends SceneTree

var failures: int = 0

func _initialize() -> void:
	var packed := load("res://UI/DungeonMinimap.tscn") as PackedScene
	_expect(packed != null, "minimap scene loads")
	if packed == null:
		quit(1)
		return
	var minimap := packed.instantiate() as DungeonMinimap
	root.add_child(minimap)
	await process_frame

	# Huang Wan Jun 2204536 - Verify the minimap layout, initial reveal, and shared transform.
	_expect(minimap.anchor_left == 1.0 and minimap.anchor_top == 1.0, "minimap anchors to bottom-right")
	_expect(minimap.offset_right == -24.0 and minimap.offset_bottom == -24.0, "minimap keeps a 24 pixel edge gap")
	_expect(minimap.size == Vector2(230.0, 160.0), "minimap has the designed compact size")
	_expect(minimap.get_revealed_levels() == [1], "only Level 1 starts revealed")
	minimap.reveal_level(2)
	minimap.reveal_level(2)
	_expect(minimap.get_revealed_levels() == [1, 2], "reveals are permanent and idempotent")
	var top_left := minimap.world_to_minimap(minimap.world_bounds.position)
	var bottom_right := minimap.world_to_minimap(minimap.world_bounds.end)
	_expect(minimap.get_drawable_rect().has_point(top_left), "world minimum maps inside drawable area")
	_expect(minimap.get_drawable_rect().has_point(bottom_right), "world maximum maps inside drawable area")
	_expect(top_left.x < bottom_right.x and top_left.y < bottom_right.y, "world transform preserves direction")

	minimap.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures += 1
	push_error("FAIL: %s" % message)
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\USER\Documents\Survive-till-Last' --script res://tests/test_dungeon_minimap.gd
```

Expected: non-zero exit because `res://UI/DungeonMinimap.tscn` does not exist.

- [ ] **Step 3: Implement the reusable scene and state/transform API**

Create `UI/DungeonMinimap.tscn` with root `Control` using:

```text
layout_mode = 3
anchors_preset = 3
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -254.0
offset_top = -184.0
offset_right = -24.0
offset_bottom = -24.0
mouse_filter = 2
```

Attach `UI/dungeon_minimap.gd` and export `world_bounds = Rect2(-7100, -1700, 12000, 6200)`. Implement these exact members and include attribution comments above each logical section:

```gdscript
class_name DungeonMinimap
extends Control

const PANEL_PADDING: float = 10.0
const LEVEL_POLYGONS := {
	1: PackedVector2Array([Vector2(-6500, 300), Vector2(-3600, -1150), Vector2(-1800, -250), Vector2(-4550, 1500)]),
	2: PackedVector2Array([Vector2(-1850, -950), Vector2(850, -450), Vector2(2050, 700), Vector2(-750, 950)]),
	3: PackedVector2Array([Vector2(2200, -900), Vector2(4650, -350), Vector2(4750, 1450), Vector2(2450, 1050)]),
	4: PackedVector2Array([Vector2(700, 1250), Vector2(2600, 1550), Vector2(1550, 3300), Vector2(-200, 2600)]),
}

@export var world_bounds: Rect2 = Rect2(-7100, -1700, 12000, 6200)
var _revealed_levels: Array[int] = [1]

# Huang Wan Jun 2204536 - Permanently reveal one valid dungeon section.
func reveal_level(level_number: int) -> void:
	if LEVEL_POLYGONS.has(level_number) and not _revealed_levels.has(level_number):
		_revealed_levels.append(level_number)
		_revealed_levels.sort()
		queue_redraw()

func is_level_revealed(level_number: int) -> bool:
	return _revealed_levels.has(level_number)

func get_revealed_levels() -> Array[int]:
	return _revealed_levels.duplicate()

func get_drawable_rect() -> Rect2:
	return Rect2(Vector2.ONE * PANEL_PADDING, size - Vector2.ONE * PANEL_PADDING * 2.0)

# Huang Wan Jun 2204536 - Map world coordinates with one centered, aspect-preserving transform.
func world_to_minimap(world_position: Vector2) -> Vector2:
	var drawable := get_drawable_rect()
	var safe_world_size := Vector2(maxf(world_bounds.size.x, 1.0), maxf(world_bounds.size.y, 1.0))
	var scale_factor := minf(drawable.size.x / safe_world_size.x, drawable.size.y / safe_world_size.y)
	var fitted_size := safe_world_size * scale_factor
	var fitted_origin := drawable.position + (drawable.size - fitted_size) * 0.5
	var normalized := (world_position - world_bounds.position) / safe_world_size
	var mapped := fitted_origin + normalized * fitted_size
	return mapped.clamp(drawable.position, drawable.end)
```

Add `_draw()` to paint the dark translucent panel, gold border, and only the polygons whose keys are in `_revealed_levels`. Convert every polygon vertex through `world_to_minimap()` before calling `draw_colored_polygon()` and `draw_polyline()`.

- [ ] **Step 4: Run the focused test and verify it passes**

Run the Task 1 test command again. Expected: exit code 0 and all layout/reveal/transform assertions print `PASS`.

- [ ] **Step 5: Commit the independent minimap component**

```powershell
git add UI/dungeon_minimap.gd UI/DungeonMinimap.tscn tests/test_dungeon_minimap.gd
git commit -m "feat: add progression minimap component"
```

### Task 2: Player and Current-Level Enemy Markers

**Files:**
- Modify: `UI/dungeon_minimap.gd`
- Modify: `tests/test_dungeon_minimap.gd`

**Interfaces:**
- Consumes: `world_to_minimap(world_position: Vector2) -> Vector2` from Task 1 and SceneTree groups `player`, `level1_enemy`, `level2_enemy`, `level3_enemy`, `boss_enemy`.
- Produces: `set_current_level(level_number: int) -> void`, `get_current_level() -> int`, `refresh_markers() -> void`, `get_player_marker() -> Variant`, and `get_enemy_markers() -> PackedVector2Array`.

- [ ] **Step 1: Add failing marker filtering and cleanup tests**

Before freeing the minimap in `tests/test_dungeon_minimap.gd`, create one `Node2D` in `player`, one in `level1_enemy`, and one in `level2_enemy`; give each a distinct global position. Add this attributed assertion section:

```gdscript
# Huang Wan Jun 2204536 - Show the player and only living enemies from the active level.
minimap.set_current_level(1)
minimap.refresh_markers()
_expect(minimap.get_player_marker() == minimap.world_to_minimap(player.global_position), "player marker follows player")
_expect(minimap.get_enemy_markers().size() == 1, "Level 1 hides Level 2 enemies")
minimap.set_current_level(2)
minimap.refresh_markers()
_expect(minimap.get_enemy_markers()[0] == minimap.world_to_minimap(level_2_enemy.global_position), "Level 2 shows its own enemy")
level_2_enemy.queue_free()
await process_frame
minimap.refresh_markers()
_expect(minimap.get_enemy_markers().is_empty(), "freed enemies disappear")
player.queue_free()
await process_frame
minimap.refresh_markers()
_expect(minimap.get_player_marker() == null, "missing player is tolerated")
minimap.set_current_level(4)
minimap.refresh_markers()
_expect(minimap.get_enemy_markers().is_empty(), "missing boss group is tolerated")
```

- [ ] **Step 2: Run the test and verify the new assertions fail**

Run the focused minimap test command. Expected: parse failure or missing-method failure for `set_current_level`/`refresh_markers`.

- [ ] **Step 3: Implement marker snapshots, filtering, refresh, and drawing**

Add:

```gdscript
const ENEMY_GROUP_BY_LEVEL := {1: "level1_enemy", 2: "level2_enemy", 3: "level3_enemy", 4: "boss_enemy"}
var _current_level: int = 1
var _player_marker: Variant = null
var _enemy_markers: PackedVector2Array = PackedVector2Array()

# Huang Wan Jun 2204536 - Select the one enemy group allowed to appear on the map.
func set_current_level(level_number: int) -> void:
	_current_level = level_number
	refresh_markers()

func get_current_level() -> int:
	return _current_level

# Huang Wan Jun 2204536 - Snapshot valid player and active-level enemy positions safely.
func refresh_markers() -> void:
	_player_marker = null
	_enemy_markers.clear()
	var scene_tree := get_tree()
	if scene_tree == null:
		return
	var player := scene_tree.get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and player.is_inside_tree():
		_player_marker = world_to_minimap(player.global_position)
	var group_name := StringName(ENEMY_GROUP_BY_LEVEL.get(_current_level, ""))
	if not group_name.is_empty():
		for candidate in scene_tree.get_nodes_in_group(group_name):
			var enemy := candidate as Node2D
			if is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.is_queued_for_deletion():
				_enemy_markers.append(world_to_minimap(enemy.global_position))
	queue_redraw()
```

Return snapshots from `get_player_marker()` and `get_enemy_markers()`. Call `refresh_markers()` from `_process()` so moving actors update continuously, and extend `_draw()` to draw enemy circles in red radius 3 and the player in blue radius 5 with a light radius-6 outline.

- [ ] **Step 4: Run the focused test and verify it passes**

Run the focused minimap test command. Expected: exit code 0, including current-level filtering, freed-node, and missing-group assertions.

- [ ] **Step 5: Commit live markers**

```powershell
git add UI/dungeon_minimap.gd tests/test_dungeon_minimap.gd
git commit -m "feat: track player and current-level enemies"
```

### Task 3: Dungeon Progression Integration

**Files:**
- Modify: `dungeon.gd`
- Modify: `Dungeon.tscn`
- Modify: `tests/test_dungeon_minimap.gd`
- Modify: `tests/test_level_clear.gd`

**Interfaces:**
- Consumes: `DungeonMinimap.reveal_level(level_number: int)` and `DungeonMinimap.set_current_level(level_number: int)` from Tasks 1-2.
- Produces: Dungeon startup/current-level/unlock events synchronized with `$LevelClearUI/DungeonMinimap`.

- [ ] **Step 1: Add failing integration tests**

Extend `tests/test_dungeon_minimap.gd` to instantiate `Dungeon.tscn` and assert the HUD path exists, `get_current_level()` starts at 1, and `_on_level_entrance_entered(2)` changes it to 2. Then verify one next section is revealed for each call to `unlock_path_after_level(1)`, `(2)`, and `(3)`. Use `get_revealed_levels()` to assert `[1]`, `[1, 2]`, `[1, 2, 3]`, then `[1, 2, 3, 4]`.

In `tests/test_level_clear.gd`, add one concise attributed block near the existing LevelClearUI assertions:

```gdscript
# Huang Wan Jun 2204536 - The dungeon HUD must contain the progression minimap.
_expect(dungeon.get_node_or_null("LevelClearUI/DungeonMinimap") is DungeonMinimap,
	"Dungeon has a bottom-right progression minimap")
```

- [ ] **Step 2: Run integration tests and verify they fail**

Run:

```powershell
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\USER\Documents\Survive-till-Last' --script res://tests/test_dungeon_minimap.gd
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\USER\Documents\Survive-till-Last' --script res://tests/test_level_clear.gd
```

Expected: minimap test fails because the dungeon has no minimap instance; level-clear test reports the missing HUD node.

- [ ] **Step 3: Instance the minimap while preserving the dirty scene**

Add an external resource for `res://UI/DungeonMinimap.tscn` and this child beneath `LevelClearUI`:

```text
[node name="DungeonMinimap" parent="LevelClearUI" instance=ExtResource("minimap_resource_id")]
```

Before and after editing, inspect `git diff -- Dungeon.tscn`. The final diff must retain every pre-existing user edit to spike counts, fire markers, safe-area polygon, ranged-enemy positions, map boundary, and generated unique IDs. Do not restore or reserialize unrelated scene sections.

- [ ] **Step 4: Connect progression in `dungeon.gd`**

Add:

```gdscript
@onready var dungeon_minimap: DungeonMinimap = $LevelClearUI/DungeonMinimap
```

In `_ready()`, add an attributed minimap section calling `reveal_level(1)` and `set_current_level(current_level)`. In `unlock_path_after_level()`, reveal exactly `completed_level + 1` for completed levels 1 through 3. In `_on_level_entrance_entered()`, call `set_current_level(level_number)`. Keep the enemy-counter positioning and Level 3 trap logic unchanged.

- [ ] **Step 5: Run both integration tests and verify they pass**

Run both Task 3 commands. Expected: both exit 0. Existing known headless warnings about `room_fade_area.gd` or missing imported slime resources may print, but no minimap assertion may fail.

- [ ] **Step 6: Stage only the intended integration changes and commit**

Because `Dungeon.tscn` was already dirty, first inspect `git diff -- Dungeon.tscn` and `git diff --cached -- Dungeon.tscn`. Stage only the new minimap external resource and node instance; leave the user's pre-existing scene hunks unstaged. Stage `dungeon.gd` and the two tests normally, then commit:

```powershell
git add dungeon.gd tests/test_dungeon_minimap.gd tests/test_level_clear.gd
git commit -m "feat: connect minimap to dungeon progression"
```

The commit must also include only the minimap-specific staged lines from `Dungeon.tscn`; verify with `git diff --cached` before committing.

### Task 4: Final Visual and Regression Verification

**Files:**
- Modify only if a focused check exposes a minimap defect: `UI/dungeon_minimap.gd`, `UI/DungeonMinimap.tscn`, `dungeon.gd`, `Dungeon.tscn`, or corresponding tests.

**Interfaces:**
- Consumes: completed minimap component and dungeon integration.
- Produces: verified bottom-right layout and passing focused regression checks.

- [ ] **Step 1: Run focused automated verification**

Run the minimap, level-clear, and Level 3 ranged-enemy tests:

```powershell
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\USER\Documents\Survive-till-Last' --script res://tests/test_dungeon_minimap.gd
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\USER\Documents\Survive-till-Last' --script res://tests/test_level_clear.gd
& 'C:\Users\USER\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\USER\Documents\Survive-till-Last' --script res://tests/test_level_3_ranged_enemies.gd
```

Expected: all three commands exit 0. Record unrelated pre-existing warnings separately rather than treating them as minimap failures.

- [ ] **Step 2: Run a manual dungeon smoke check**

Launch `Dungeon.tscn` and verify at 1152x648:

1. The panel sits 24 pixels from the bottom and right edges and does not overlap the Guard Halo, counter, or weapon-store UI.
2. Only Level 1 geometry appears initially.
3. The blue player dot moves with the player.
4. Only current-level red dots appear when entering Levels 1, 2, and 3.
5. Clearing each level adds the next section permanently.
6. Defeated enemies disappear from the map.

- [ ] **Step 3: Inspect attribution, scope, and repository state**

Run:

```powershell
rg -n "Huang Wan Jun 2204536" UI/dungeon_minimap.gd dungeon.gd tests/test_dungeon_minimap.gd tests/test_level_clear.gd
git diff --check
git status --short
git log -4 --oneline
```

Expected: all modified minimap script/test sections have attribution, `git diff --check` is clean, `.superpowers/` remains untracked, and the user's original `Dungeon.tscn` edits remain present and uncommitted.

- [ ] **Step 4: Commit only if verification required a fix**

If Step 1 or 2 required a minimap correction, rerun all three tests, stage only that correction, and commit:

```powershell
git commit -m "fix: polish dungeon minimap"
```

If no correction was needed, do not create an empty commit.

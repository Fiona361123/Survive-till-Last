# Level 3 Action Traps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add telegraphed spike rows, sweeping fire, and falling-rock strikes that run alongside enemies in the Level 3 arena.

**Architecture:** Three focused trap scenes own their warning, active, and reset behavior. A Level 3 controller sequences authored trap instances, while `dungeon.gd` starts and stops the controller at the existing Level 3 lifecycle boundaries.

**Tech Stack:** Godot 4.6, GDScript, Area2D collision, Tween, SceneTree integration tests

**Spec:** `docs/superpowers/specs/2026-09-04-level-3-action-traps-design.md`

## Global Constraints

- Every damaging phase must have a visible warning first.
- Each trap damages a body at most once per activation.
- Traps affect both the player collision layer (`2`) and enemy collision layer (`4`).
- The entrance remains safe and every phase leaves a reachable safe route.
- Trap activity stops after `_complete_level_three()`.
- Trap kills use the existing `take_damage(amount)` interface.

---

### Task 1: Shared Trap Damage Area

**Files:**
- Create: `Level3Traps/trap_damage_area.gd`
- Create: `tests/test_trap_damage_area.gd`

**Interfaces:**
- Consumes: bodies with `take_damage(amount: int) -> void`
- Produces: `TrapDamageArea.begin_activation(damage: int) -> void`, `end_activation() -> void`, and `damage_overlapping_bodies() -> void`

- [ ] **Step 1: Write the failing test**

Create a test SceneTree that adds a `TrapDamageArea`, a player-layer dummy, and an enemy-layer dummy. Give each dummy a `take_damage` implementation, call `begin_activation(20)` followed by `damage_overlapping_bodies()` twice, and assert that both dummies receive exactly 20 damage rather than 40.

```gdscript
area.begin_activation(20)
area.damage_overlapping_bodies()
area.damage_overlapping_bodies()
_expect(player.damage_received == 20, "player is damaged once per activation")
_expect(enemy.damage_received == 20, "enemy is damaged once per activation")
```

- [ ] **Step 2: Run the test and confirm the missing class failure**

Run:

```powershell
Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tests/test_trap_damage_area.gd
```

Expected: failure because `res://Level3Traps/trap_damage_area.gd` does not exist.

- [ ] **Step 3: Implement the shared damage area**

```gdscript
class_name TrapDamageArea
extends Area2D

var activation_damage: int = 0
var damaged_bodies: Dictionary = {}

func begin_activation(damage: int) -> void:
	activation_damage = maxi(damage, 0)
	damaged_bodies.clear()
	monitoring = true

func damage_overlapping_bodies() -> void:
	for body in get_overlapping_bodies():
		if body in damaged_bodies or not body.has_method("take_damage"):
			continue
		body.take_damage(activation_damage)
		damaged_bodies[body] = true

func end_activation() -> void:
	monitoring = false
	damaged_bodies.clear()
```

Configure created damage areas with `collision_layer = 0` and `collision_mask = 6`.

- [ ] **Step 4: Run the focused test**

Expected: both layer-2 and layer-4 bodies pass the once-per-activation assertions.

- [ ] **Step 5: Commit**

```powershell
git add Level3Traps/trap_damage_area.gd tests/test_trap_damage_area.gd
git commit -m "feat: add reusable trap damage area"
```

---

### Task 2: Telegraphing Spike Row

**Files:**
- Create: `Level3Traps/spike_row.gd`
- Create: `Level3Traps/SpikeRow.tscn`
- Create: `tests/test_spike_row.gd`

**Interfaces:**
- Consumes: `TrapDamageArea`
- Produces: signal `activation_finished`; `activate() -> void`; `force_safe() -> void`; exported `warning_duration`, `active_duration`, and `damage`

- [ ] **Step 1: Write the failing spike-state test**

Instantiate `SpikeRow.tscn`, set durations to `0.05`, call `activate()`, and assert the sequence begins in `WARNING`, reaches `ACTIVE` only after the warning, and ends in `SAFE`. Assert a body present throughout loses health once.

```gdscript
spikes.activate()
_expect(spikes.state == spikes.State.WARNING, "spikes warn before damage")
await create_timer(0.06).timeout
_expect(spikes.state == spikes.State.ACTIVE, "spikes become active after warning")
await spikes.activation_finished
_expect(spikes.state == spikes.State.SAFE, "spikes retract after activation")
```

- [ ] **Step 2: Run the test and confirm `SpikeRow.tscn` is missing**

- [ ] **Step 3: Implement the spike scene**

Use a `Node2D` root with a warning `Polygon2D`, an active spike `Polygon2D`, and a rectangular `TrapDamageArea`. Implement:

```gdscript
class_name SpikeRow
extends Node2D

signal activation_finished
enum State { SAFE, WARNING, ACTIVE }

@export var warning_duration := 0.7
@export var active_duration := 0.8
@export var damage := 20
var state := State.SAFE

func activate() -> void:
	if state != State.SAFE:
		return
	state = State.WARNING
	$Warning.visible = true
	await get_tree().create_timer(warning_duration).timeout
	state = State.ACTIVE
	$Warning.visible = false
	$Spikes.visible = true
	$DamageArea.begin_activation(damage)
	$DamageArea.damage_overlapping_bodies()
	await get_tree().create_timer(active_duration).timeout
	$DamageArea.end_activation()
	$Spikes.visible = false
	state = State.SAFE
	activation_finished.emit()

func force_safe() -> void:
	$DamageArea.end_activation()
	$Warning.visible = false
	$Spikes.visible = false
	state = State.SAFE
```

Connect `body_entered` during the active state so a body entering after activation also receives damage once.

- [ ] **Step 4: Run spike and shared-damage tests**

- [ ] **Step 5: Commit**

```powershell
git add Level3Traps/spike_row.gd Level3Traps/SpikeRow.tscn tests/test_spike_row.gd
git commit -m "feat: add telegraphed spike rows"
```

---

### Task 3: Sweeping Fire Lane

**Files:**
- Create: `Level3Traps/fire_sweep.gd`
- Create: `Level3Traps/FireSweep.tscn`
- Create: `tests/test_fire_sweep.gd`

**Interfaces:**
- Consumes: `TrapDamageArea`
- Produces: signal `sweep_finished`; `sweep(from: Vector2, to: Vector2) -> void`; `force_safe() -> void`; exported `warning_duration`, `travel_duration`, and `damage`

- [ ] **Step 1: Write the failing sweep test**

Set short durations, call `sweep(Vector2.ZERO, Vector2(200, 0))`, assert the warning is visible before movement, await `sweep_finished`, and assert the root reaches `(200, 0)` and the damage area is disabled.

- [ ] **Step 2: Run the test and confirm the scene is missing**

- [ ] **Step 3: Implement the fire sweep**

Build a `Node2D` with a warning strip, animated fire polygons/particles, and a `TrapDamageArea`. After the warning timer, begin one activation and tween `global_position` from `from` to `to` using linear interpolation. Call `damage_overlapping_bodies()` each physics frame while sweeping, then end the activation and emit `sweep_finished`.

```gdscript
func sweep(from: Vector2, to: Vector2) -> void:
	global_position = from
	$Warning.visible = true
	await get_tree().create_timer(warning_duration).timeout
	$Warning.visible = false
	$Fire.visible = true
	$DamageArea.begin_activation(damage)
	var tween := create_tween()
	tween.tween_property(self, "global_position", to, travel_duration)
	await tween.finished
	$DamageArea.end_activation()
	$Fire.visible = false
	sweep_finished.emit()

func force_safe() -> void:
	$DamageArea.end_activation()
	$Warning.visible = false
	$Fire.visible = false
```

- [ ] **Step 4: Run fire and shared-damage tests**

- [ ] **Step 5: Commit**

```powershell
git add Level3Traps/fire_sweep.gd Level3Traps/FireSweep.tscn tests/test_fire_sweep.gd
git commit -m "feat: add sweeping fire trap"
```

---

### Task 4: Falling-Rock Strike

**Files:**
- Create: `Level3Traps/rock_strike.gd`
- Create: `Level3Traps/RockStrike.tscn`
- Create: `tests/test_rock_strike.gd`

**Interfaces:**
- Consumes: `TrapDamageArea`
- Produces: signal `strike_finished`; `strike_at(target: Vector2) -> void`; exported `warning_duration`, `impact_duration`, and `damage`

- [ ] **Step 1: Write the failing strike test**

Call `strike_at(Vector2(120, 80))`, assert the warning circle appears at that exact point before damage, await `strike_finished`, and assert an overlapping player and enemy each receive damage once.

- [ ] **Step 2: Run the test and confirm the scene is missing**

- [ ] **Step 3: Implement warning and impact states**

Create a `Node2D` containing a translucent warning circle, a rock/impact visual, and circular `TrapDamageArea`. Keep the warning visible for `0.9` seconds, show the impact, apply damage once, hide after `impact_duration`, and emit completion.

- [ ] **Step 4: Run rock and shared-damage tests**

- [ ] **Step 5: Commit**

```powershell
git add Level3Traps/rock_strike.gd Level3Traps/RockStrike.tscn tests/test_rock_strike.gd
git commit -m "feat: add falling rock strikes"
```

---

### Task 5: Level 3 Trap Sequence Controller

**Files:**
- Create: `Level3Traps/level_3_trap_controller.gd`
- Create: `tests/test_level_3_trap_controller.gd`

**Interfaces:**
- Consumes: spike-row children, `FireSweep`, rock-strike packed scene, authored `Marker2D` rock targets, and entrance-safe `Area2D`
- Produces: `start_encounter() -> void`, `stop_encounter() -> void`, and `is_running: bool`

- [ ] **Step 1: Write the failing controller test**

Construct three fake-duration spike rows, one fire sweep, and rock markers. Start the controller and assert that no more than two of three spike rows enter warning/active state together. Stop it and assert all damage areas are disabled and no later phase begins.

- [ ] **Step 2: Run the test and confirm the controller is missing**

- [ ] **Step 3: Implement the phase loop**

```gdscript
func start_encounter() -> void:
	if is_running:
		return
	is_running = true
	_run_cycle.call_deferred()

func stop_encounter() -> void:
	is_running = false
	for row in spike_rows:
		row.force_safe()
	fire_sweep.force_safe()

func _run_cycle() -> void:
	while is_running:
		await _activate_spike_pattern()
		if not is_running: return
		await _activate_fire_sweep()
		if not is_running: return
		await _activate_rock_strikes()
```

Alternate spike patterns `[0, 2]` and `[1]`. Select two distinct rock markers, rejecting any marker whose global position lies inside the entrance-safe collision polygon. If a reference is missing, emit `push_warning()` and continue to the next phase.

- [ ] **Step 4: Run all Level 3 trap tests**

- [ ] **Step 5: Commit**

```powershell
git add Level3Traps/level_3_trap_controller.gd tests/test_level_3_trap_controller.gd
git commit -m "feat: sequence level 3 action traps"
```

---

### Task 6: Author the Level 3 Arena Layout and Lifecycle

**Files:**
- Modify: `Dungeon.tscn`
- Modify: `dungeon.gd`
- Modify: `tests/test_level_clear.gd`

**Interfaces:**
- Consumes: `Level3TrapController.start_encounter()` and `stop_encounter()`
- Produces: a Level 3 scene containing three spike rows, one fire sweep lane, two or more rock target markers, and one entrance-safe area

- [ ] **Step 1: Extend the Dungeon integration test**

Assert these exact paths exist:

```gdscript
_expect(dungeon.get_node_or_null("Level3Traps") is Node2D, "Level 3 has a trap controller")
_expect(dungeon.get_node_or_null("Level3Traps/SpikeRows").get_child_count() == 3,
	"Level 3 has exactly three spike rows")
_expect(dungeon.get_node_or_null("Level3Traps/FireSweep") != null,
	"Level 3 has one fire sweep")
_expect(dungeon.get_node_or_null("Level3Traps/RockTargets").get_child_count() >= 2,
	"Level 3 has authored rock targets")
_expect(dungeon.get_node_or_null("Level3Traps/EntranceSafeArea") is Area2D,
	"Level 3 entrance is protected from random strikes")
```

Call `_on_level_entrance_entered(3)` and assert `is_running`. Call `_complete_level_three()` and assert it becomes false before the clear-message timer completes.

- [ ] **Step 2: Run the integration test and confirm missing-node failures**

- [ ] **Step 3: Add the authored trap nodes to `Dungeon.tscn`**

Place three non-adjacent spike rows across the large Level 3 floor shown in the approved reference image. Place the fire sweep endpoints on opposite horizontal edges. Add rock markers over the central and far floor sections. Cover the entrance corridor and its first safe landing area with `EntranceSafeArea`; do not overlap that area with a spike collision rectangle.

- [ ] **Step 4: Connect the existing Level 3 lifecycle**

Add:

```gdscript
@onready var level_3_traps: Node = $Level3Traps
```

In `_on_level_entrance_entered(level_number)`, call `level_3_traps.start_encounter()` when `level_number == 3`. At the beginning of `_complete_level_three()`, call `level_3_traps.stop_encounter()`.

- [ ] **Step 5: Run the full project test set**

Run each `tests/test_*.gd` SceneTree script headlessly. Expected: zero failures, no trap-reference warnings, and no parser errors.

- [ ] **Step 6: Manually verify the encounter**

Enter Level 3 with enemies active. Confirm warnings are readable, at least one safe route remains in each phase, traps can damage enemies, the entrance never receives random rock strikes, and all traps stop after Level 3 clear.

- [ ] **Step 7: Commit**

```powershell
git add Dungeon.tscn dungeon.gd tests/test_level_clear.gd
git commit -m "feat: integrate action traps into level 3"
```

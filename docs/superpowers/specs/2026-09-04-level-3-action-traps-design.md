# Level 3 Action Traps Design

## Goal

Turn the open Level 3 arena into a fast action encounter where enemies pressure the player while clearly telegraphed traps force continuous repositioning. Every trap must be readable, avoid unavoidable damage, and be usable against enemies.

## Encounter Structure

Level 3 uses a repeating hazard cycle while its enemy encounter is active. The cycle combines three trap types:

1. Spike rows activate across selected floor lanes.
2. Sweeping fire travels across another lane after the spikes retract.
3. Falling rocks target a small number of positions after visible warning markers appear.

Only a limited subset of the arena is dangerous at once. Each phase preserves at least one broad safe route, including safe access near the entrance. Trap activity stops when Level 3 is cleared.

## Trap Behaviors

### Spike Rows

Spike rows occupy authored rectangular strips aligned with the isometric floor. Each activation has three states:

- Safe: spikes are hidden and cause no damage.
- Warning: the affected floor flashes for 0.7 seconds.
- Active: spikes rise for 0.8 seconds and damage overlapping combatants once per activation.

Rows alternate rather than activating together. Adjacent rows must not cover the full width of the arena simultaneously.

### Sweeping Fire

A visible fire front crosses one authored lane at a constant speed. A short glow at its starting edge warns the player before movement begins. The fire damages a body at most once during each sweep. The next trap phase cannot begin until the sweep exits the arena.

### Falling Rocks

The controller selects a small number of target positions within authored target zones. Warning circles remain visible for 0.9 seconds, then rocks strike those positions. Each impact damages bodies inside its radius once. Target selection must exclude the entrance safe area and must not cover every available safe route.

## Damage and Collision Rules

Traps detect the player collision layer and the enemy collision layer. They call the existing `take_damage` interface, so player invincibility and enemy hurt behavior remain authoritative. Each trap tracks bodies already damaged during its current activation to prevent frame-by-frame damage.

Traps affect both players and enemies. XP, kills, and Level 3 completion continue to use the existing enemy lifecycle; a trap kill is equivalent to a weapon kill.

## Level Integration

A `Level3TrapController` node in `Dungeon.tscn` owns the phase schedule and references authored trap nodes. It begins when the player enters Level 3 and stops when `_complete_level_three()` runs. Individual trap scenes own their visuals, collision areas, warning timing, and per-activation damage tracking.

The initial layout uses:

- Three non-adjacent spike rows across the main floor.
- One fire-sweep lane spanning the arena horizontally.
- Two falling-rock target zones covering the central and far sections.
- A protected entrance region where falling rocks cannot target and spike rows do not activate.

Trap visuals render below characters while warnings are active and above the floor when hazardous. All visuals follow the existing isometric stone-and-sand presentation.

## Failure Handling

Missing trap references disable only the affected phase and emit a clear editor warning. An empty falling-rock target zone skips that strike rather than selecting an unsafe fallback. The controller never waits indefinitely for a disabled or removed trap.

## Testing

Automated tests cover:

- Warning state always precedes damaging state.
- One activation damages each overlapping body at most once.
- Both player and enemy collision layers are detected.
- Spike rows never activate all arena lanes simultaneously.
- Falling rocks exclude the entrance safe region.
- The fire sweep completes and reports completion to the controller.
- The controller starts on Level 3 entry and stops after Level 3 clear.
- `Dungeon.tscn` contains the intended trap count and safe entrance area.

Manual verification checks visual alignment with the isometric floor, warning readability during combat, reachable safe routes in every phase, and stable performance with the full enemy encounter active.

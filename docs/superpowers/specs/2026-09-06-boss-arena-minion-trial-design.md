# Boss Arena Minion Trial Design

## Goal

Turn the existing rectangular boss room into a two-wave minion trial that prepares the arena for a future boss. The encounter reuses enemies and traps from Levels 1–3 without requiring the unfinished boss enemy.

## Player Experience

The encounter begins once when the player enters the boss room. Its pace is:

1. Wave 1 spawns five slimes while two isometric spike rows alternate.
2. Wave 2 begins only after all five slimes are defeated. It spawns three skeletons and two ranged enemies while one warned fire sweep crosses the room.
3. After Wave 2 is defeated, all arena traps stop, active encounter projectiles are cleared, `BossSpawnPoint` becomes visible, and the message `BOSS ARENA READY` appears.

No placeholder boss is spawned. The completed trial leaves a clean integration point for the future boss scene.

## Arena Layout

The existing long rectangular boss room remains the arena. The entrance end is protected by an authored safe area so the player is never hit or surrounded immediately after entering.

Wave 1 slime spawn points are distributed across the middle and far portions of the room. Two spike rows run along the room's long direction with walkable gaps around and between them.

Wave 2 skeletons spawn in the middle portion so they can pressure the player at close range. The two ranged enemies spawn toward the far end with separation between them. The fire sweep travels across the combat space between authored start and end markers while preserving a readable escape route.

`BossSpawnPoint` sits in the room's main focal area. It is hidden or visually inactive until the two minion waves are cleared.

## Encounter States

The controller uses four explicit states:

- `WAITING`: no minions or traps are active; the entrance trigger is armed.
- `WAVE_1`: five slimes are active and the alternating spike pattern runs.
- `WAVE_2`: three skeletons and two ranged enemies are active and the warned fire sweep runs.
- `BOSS_READY`: minion spawning is finished, traps and encounter projectiles are stopped, and the boss integration point is available.

Entering the room transitions `WAITING` to `WAVE_1`. The encounter starts only once. Walking out and back in cannot restart a wave or duplicate enemies.

Wave progression is based only on living nodes owned by the boss encounter. An enemy in its death state counts as defeated even if its death animation has not freed the node yet.

## Scene Structure

Add this structure to the boss-room portion of `Dungeon.tscn`:

```text
BossEncounter
├── EntranceTrigger
├── EntranceSafeArea
├── Wave1SpawnPoints
│   ├── Slime1
│   ├── Slime2
│   ├── Slime3
│   ├── Slime4
│   └── Slime5
├── Wave2SkeletonSpawnPoints
│   ├── Skeleton1
│   ├── Skeleton2
│   └── Skeleton3
├── Wave2RangedSpawnPoints
│   ├── Ranged1
│   └── Ranged2
├── SpikeRows
│   ├── SpikeRowA
│   └── SpikeRowB
├── FireSweep
├── FireStartMarker
├── FireEndMarker
├── ActiveMinions
├── ActiveProjectiles
└── BossSpawnPoint
```

The exact authored positions must be validated against the current boss-room floor and wall collision in `Dungeon.tscn`. Spawn resolution must keep minions outside walls, spike collision, and `EntranceSafeArea`.

## Components

### Boss encounter controller

`BossEncounter/boss_encounter_controller.gd` owns the encounter state, spawns each wave, monitors living encounter minions, starts and stops traps, clears owned projectiles, and exposes boss-ready completion.

It provides a narrow future integration surface:

- `start_encounter()` begins Wave 1 if the state is `WAITING`.
- `get_encounter_state()` returns the current state for HUD and tests.
- `is_boss_ready()` reports whether both preparation waves are clear.
- `get_boss_spawn_point()` returns the authored boss marker.
- A `boss_ready(spawn_point)` signal announces that the future boss may be created.

The controller must not instantiate a boss scene itself in this version.

### Minions

Wave 1 uses the existing slime scene. Wave 2 uses the existing skeleton and ranged-enemy scenes.

Every spawned minion is parented below `ActiveMinions` and added to both:

- `boss_minion`, for encounter ownership and progression;
- `boss_enemy`, so the existing minimap shows only boss-room minions while the player is in Level 4.

The controller does not add them to the Level 1, Level 2, or Level 3 progression groups. Therefore earlier enemy counters and clear flags remain unchanged.

### Spike rows

The encounter reuses the existing Level 3 spike-row behavior and isometric spike visuals. During Wave 1, Row A warns and activates while Row B is down, then they swap. Both rows are never damaging simultaneously. The warning timing and safe gaps must give the player a clear route through the room.

Both rows stop and retract before Wave 2 begins.

### Fire sweep

The encounter reuses the existing Level 3 fire-sweep behavior. It remains inactive during Wave 1. During Wave 2 it displays its warning, travels between `FireStartMarker` and `FireEndMarker`, resets, and repeats at a fair interval until the wave ends.

The fire sweep stops immediately when Wave 2 is cleared. It must not enter or damage the authored entrance safe area.

## Progression and UI

The existing `BossEntrance` continues to set the dungeon's current level to 4. This automatically selects the `boss_enemy` minimap group.

The existing top-left enemy counter should show boss-trial progress while the encounter is active:

- Wave 1: `BOSS TRIAL - WAVE 1` and five total enemies.
- Wave 2: `BOSS TRIAL - WAVE 2` and five total enemies.
- Boss ready: `BOSS ARENA READY`.

The permanent arena-ready message may reuse the current dungeon HUD label, but it must not falsely report that the game or boss has been completed.

## Failure Handling

Before beginning a wave, the controller validates all required enemy scenes, spawn containers, spawn markers, and trap nodes.

If required configuration is missing:

- do not partially spawn a wave;
- stop all encounter traps;
- keep the current state from advancing;
- emit a clear Godot error naming the missing scene or node.

If a spawn candidate overlaps walls, spike collision, or the entrance safe area, use the existing spawn-position resolver to find a valid nearby position. If no valid position exists, abort that wave safely rather than silently reducing its enemy count.

Freed minions and minions in a death state are ignored by the living-minion count. Unrelated enemies elsewhere in the dungeon never affect the boss trial.

## Testing

Focused automated tests verify:

- the scene has the required boss-encounter node structure;
- entering the trigger starts the encounter once;
- Wave 1 creates exactly five slimes;
- Wave 2 cannot begin while any Wave 1 slime remains alive;
- clearing Wave 1 retracts the spike rows and creates exactly three skeletons and two ranged enemies;
- spawned minions belong to `boss_minion` and `boss_enemy`, but not Level 1–3 progression groups;
- every spawn resolves outside walls, spike collision, and `EntranceSafeArea`;
- the spike rows alternate with warning time and never damage simultaneously;
- the fire sweep is inactive in Wave 1, active with warnings in Wave 2, and stopped afterward;
- clearing Wave 2 clears encounter-owned projectiles, reveals `BossSpawnPoint`, emits `boss_ready` once, and shows `BOSS ARENA READY`;
- walking out and back in does not duplicate a wave;
- missing scenes or required nodes abort safely with a clear error;
- dead but still animating minions no longer block progression;
- the boss-room minimap shows living trial minions and no enemies from inactive levels.

The focused boss-encounter tests, existing Level 3 trap tests, minimap tests, and Level 3 ranged-enemy tests must pass. Pre-existing unrelated failures in the broad level-clear suite remain documented separately.

## Code Attribution

Every new or modified boss-encounter script section and hand-authored boss-encounter test section must include a concise comment containing `Huang Wan Jun 2204536` and explaining that section's purpose. Generated scene data does not require repeated attribution comments.

## Future Boss Integration

When the real boss scene is ready, it listens for `boss_ready(spawn_point)` or queries `is_boss_ready()` and instances the boss at `BossSpawnPoint`. The future work can add boss health, phases, victory, rewards, and ending flow without changing the two preparation waves.

## Out of Scope

- Creating or balancing the real boss enemy
- Boss health UI
- Boss victory rewards or ending sequence
- New minion enemy types
- New trap art
- Randomized wave composition
- More than two preparation waves

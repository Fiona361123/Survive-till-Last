# Progression Minimap Design

## Goal

Add a small bottom-right dungeon minimap that shows the player's location, reveals level sections as progression is completed, and displays enemies from the player's current level only.

## Player Experience

- The minimap is always visible during dungeon gameplay.
- It is anchored 24 pixels from the bottom-right corner and is approximately 230 by 160 pixels.
- The panel uses a dark translucent background, a gold border, and simplified isometric dungeon outlines.
- The player is represented by a clearly visible blue marker.
- Living enemies in the current level are represented by red markers.
- Enemy markers from other levels are not shown.
- Enemy markers disappear when their enemy leaves the scene or dies.

## Progression Reveal Rules

- Level 1 is visible at the start of a new dungeon run.
- Clearing Level 1 reveals the Level 2 section.
- Clearing Level 2 reveals the Level 3 section.
- Clearing Level 3 reveals the boss section.
- A revealed section remains visible for the rest of the dungeon run.
- Unrevealed sections are hidden, not shown as silhouettes.

## Map Representation

The minimap uses lightweight authored polygons rather than duplicating the game's TileMap layers. Each polygon is a simplified isometric footprint for one combat section or connecting route.

All markers and polygons share one world-to-minimap transform. The transform maps an exported world boundary into the minimap's drawable rectangle, preserves aspect ratio, centers the result, and clamps markers to the drawable region. This keeps player and enemy markers aligned while supporting different window sizes.

## Components

### `DungeonMinimap`

A reusable Control-based HUD scene owns:

- the background panel and border;
- four authored level-section polygons;
- player and enemy marker drawing;
- unlocked-level state;
- the active level used for enemy filtering;
- world-to-minimap coordinate conversion.

Its public interface is:

- `set_current_level(level_number)` updates enemy filtering;
- `reveal_level(level_number)` permanently reveals a map section;
- `world_to_minimap(world_position)` returns a marker position for testing and drawing;
- `refresh_markers()` updates marker data from the scene tree.

The component tolerates missing player or enemy nodes and ignores freed nodes.

### Dungeon integration

`dungeon.gd` owns progression and remains the source of truth:

- on startup it reveals Level 1;
- `_on_level_entrance_entered()` updates the minimap's current level;
- `unlock_path_after_level()` reveals the newly unlocked destination level;
- existing clear flags and enemy groups remain unchanged.

The minimap is added under the dungeon HUD CanvasLayer so it remains fixed on screen while the camera moves.

## Enemy Filtering

The active group is selected by level:

- Level 1: `level1_enemy`
- Level 2: `level2_enemy`
- Level 3: `level3_enemy`
- Boss: a future `boss_enemy` group, with no markers when that group is absent

Only nodes in the active group produce red dots. The minimap does not reveal enemies in locked or inactive sections.

## Visual Priority

- Player marker: blue, larger than enemy markers, with a light outline.
- Enemy markers: red, small, and visually subordinate to the player.
- Revealed floor: muted tan fill with a gold outline.
- Panel: dark translucent navy/black to remain readable over the dungeon.
- Unrevealed areas: fully omitted.

The minimap must not overlap the bottom or right screen edges. Existing Guard Halo, enemy-counter, and weapon-store UI remain unchanged.

## Testing

Automated tests will verify:

- the minimap scene loads and is bottom-right anchored;
- Level 1 alone is visible initially;
- each level-clear operation reveals exactly the next section;
- revealed sections remain visible;
- world positions map consistently inside the minimap bounds;
- the player marker follows the player;
- only current-level enemy markers are included;
- freed enemies disappear from marker data;
- missing groups and nodes do not cause errors.

Focused minimap tests and the existing dungeon level-clear tests must pass before the feature is considered complete.

## Code Attribution

Every new or modified minimap code section must include a concise comment containing `Huang Wan Jun 2204536` and explaining the purpose of that section. Attribution comments apply to scripts and hand-authored test logic. They are not repeated on every line or inserted into generated scene data.

## Out of Scope

- Continuous walk-based fog of war
- A rotating minimap
- Clicking or zooming the minimap
- Pathfinding or route guidance
- Off-screen enemy arrows
- Showing pickups, traps, or projectiles

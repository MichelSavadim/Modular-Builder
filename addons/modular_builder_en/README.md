# Modular Builder

An editor plugin for building modular structures directly in Godot 4.7 and later. Measurements shown in the panel and Inspector are in meters. Godot uses one 3D unit per meter, so the plugin maps meters to Godot units at a 1:1 scale.

## Installation

Copy the `modular_builder_en` folder into your project's `addons` directory, then enable **Modular Builder (English)** under **Project → Project Settings → Plugins**. Open a 3D scene. The plugin panel appears at the bottom of the editor.

## Building structures

Use **Add ModularBuilderPiece** to create a structure container with an initial foundation. Select the container in the Scene tree to show the vertices and placement controls available to the active tool.

Green tools create square or triangular foundations. Their icons also choose the shape used for the next foundation. Click a green `+` next to an open foundation edge to attach another one; the button is hidden when that edge is already connected. A square foundation attached to a triangle's diagonal keeps its square shape and fits along the middle portion of that edge.

Red tools create walls by clicking two blue vertices. Walls that cross multiple foundations are split at intermediate foundation vertices. Yellow tools create square floors from two diagonal vertices or triangular floors from three vertices. The tool stays active after placing a piece; click the active tool again or select another tool to change it. Press `Esc` to clear the current points. Use `Ctrl+Z` to undo created pieces.

New pieces use the center of their geometry as the transform origin. The rotate button turns the last created piece by 90 degrees, or the selected child piece when one is selected in the Scene tree.

## Details

Pink tools add windows and doors to walls, and hatches to foundations or floors. The preview follows the cursor. Choose whether a detail is an opening or an opening with a separate editable object, then adjust its dimensions and style. Frame and panel materials can be assigned separately in the Inspector. Hatches are placed horizontally in the floor plane.

## Collision

Pieces do not receive collision automatically. Select the structure container and click the general collision button to create or update one static concave collision shape from its child meshes. Snap markers, placement buttons, and connected contact faces are excluded.

## Reusable modules

Use the save and insert module buttons to save a selected structure as a reusable `.tscn` scene or insert a saved module into the open scene. Copy the scene and its referenced resources to another project when sharing a module.

Square and triangular foundations use the same modular size. A triangular foundation covers half of a square, allowing the two shapes to form different outlines and corners when rotated.

## Initial scope

The plugin provides vertex-based placement for foundations, walls, and floors; detail previews; general collision generation; and saving structures as reusable scenes. Initial window styles are single pane and cross pane; door styles are flat and paneled. Custom scenes and advanced animation can be added in future versions.

## License

The original Modular Builder code, icons, and documentation in this folder are dedicated to the public domain under CC0 1.0 Universal. This does not apply to Godot Engine, user-created project content, or third-party material distributed separately.

## AI usage disclosure

Generative AI (OpenAI ChatGPT/Codex) assisted with writing and revising GDScript, debugging and fixing issues, translating the plugin and documentation from Portuguese to English, and preparing documentation. The project author defined the plugin's requirements and reviewed and tested the resulting changes.

For the Godot Asset Store submission form, this disclosure can be used:

> Generative AI (OpenAI ChatGPT/Codex) assisted with GDScript implementation and revisions, debugging, bug fixes, and translation of the plugin and documentation from Portuguese to English. The project author defined the requirements and reviewed and tested the resulting changes.

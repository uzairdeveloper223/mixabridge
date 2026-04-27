# MixaBridge

Godot 4.4+ editor addon that automates Mixamo animation retargeting and library construction.

Importing Mixamo animations into Godot means opening Advanced Import Settings for every file, creating BoneMaps, assigning SkeletonProfileHumanoid, configuring retarget options, reimporting, then manually building AnimationLibraries. MixaBridge does all of that in three clicks.

## Why

If you've ever imported Mixamo animations into Godot, you know the pain. The manual workflow looks like this:

1. Open your model's Advanced Import Settings
2. Find the Skeleton3D, create a BoneMap, set the profile to SkeletonProfileHumanoid
3. Map the bones (or auto-map and hope it gets them right)
4. Save the BoneMap as a `.tres` file
5. For **every single animation file**: open its Advanced Import Settings, assign the same BoneMap, configure retarget settings, save
6. Wait for reimport
7. Open your model's AnimationPlayer, create a new AnimationLibrary
8. Manually add each extracted `.res` animation to the library

For a game with 5 animations, that's annoying. For a game with 50+, that's an entire afternoon wasted on clicking through import dialogs. And if you change your model or re-export from Mixamo, you get to do it all over again.

MixaBridge replaces steps 1 through 8 with: select model, link AnimationPlayer, add animation files, click Process.

## How it works

1. Loads your model's `.fbx`, finds the Skeleton3D, reads bone names
2. Matches each `mixamorig:`-prefixed bone to Godot's SkeletonProfileHumanoid using a static lookup table
3. Creates a BoneMap `.tres` resource and injects it into the `.import` file's `[params]` section
4. Calls `EditorFileSystem.reimport_files()` to trigger Godot's import pipeline with retarget settings
5. After reimport, extracts Animation resources from each file and assembles them into an AnimationLibrary attached to your AnimationPlayer

No custom import plugins. No editor hacks. It works with Godot's existing pipeline.

## Usage

1. Drag your Mixamo model `.fbx` into the scene, right-click, Make Local
2. Open the **MixaBridge** tab in the bottom panel
3. **Select Rigged Model** — pick your `.fbx`, bones auto-map
4. **Link AnimationPlayer** — click the AnimationPlayer in the Scene dock, then click "Link Selected AnimationPlayer"
5. **Add Animation Files** — select your animation `.fbx` files (exported without skin from Mixamo)
6. **Rename** — double-click any animation in the list to rename it before processing
7. **Remove** — select an animation and click "Remove Selected" to drop it from the queue
8. **Pick a library** — choose an existing AnimationLibrary on the player, or create a new one with a custom name
9. **Process All** — the library gets built and attached to your AnimationPlayer
10. **Re-process** — changed your mind? Edit the list and hit Re-process without resetting

Full guide with screenshots: [uzair.ct.ws/mixabridge](http://uzair.ct.ws/mixabridge/index.html)

## Install

Copy `addons/mixabridge/` into your project's `addons/` directory. Enable in Project Settings > Plugins.

## Project structure

```
addons/mixabridge/
  plugin.cfg              config
  plugin.gd               entry point
  icon.svg                addon icon
  mixamo_bone_table.gd    Mixamo-to-Humanoid bone name map
  bone_mapper.gd          skeleton analysis + BoneMap creation
  import_configurator.gd  .import file manipulation + reimport
  animation_extractor.gd  animation extraction + library building
  mixabridge_panel.tscn   bottom panel UI layout
  mixabridge_panel.gd     panel controller + workflow orchestration
  generated/              auto-generated BoneMap .tres files
  docs/                   documentation + screenshots
```

## Limitations

- Mixamo rigs only — the bone name table is built for Mixamo's `mixamorig:` naming convention
- Godot 4.4+ — uses APIs that may not exist in earlier versions
- FBX/GLB/GLTF only — other 3D formats aren't tested
- `.import` file editing — writes to `.import` files directly, may break if Godot changes the format
- Blocking reimport — `reimport_files()` freezes the editor momentarily for large batches

## License

MIT License. See [LICENSE](LICENSE).

## Disclaimer

MixaBridge is an independent, community-built tool. It is not affiliated with, endorsed by, or sponsored by Adobe Inc. or Mixamo. "Mixamo" is a trademark of Adobe Inc. This project interacts with files exported from Mixamo but has no connection to Adobe or its services.

## Author

Uzair Mughal
- [uzair.is-a.dev](https://uzair.is-a.dev)
- [contact@uzair.is-a.dev](mailto:contact@uzair.is-a.dev)
- [github.com/uzairdeveloper223](https://github.com/uzairdeveloper223)


# Hexivra: Hex Puzzle 3D

Hexivra is an offline portrait circuit puzzle built in Godot 4.7.2. The Android export uses package `com.mhmmad.hexivra`, version `2.0.0`, and version code `200`.

```sh
godot --headless --editor --import --quit
godot --headless --script res://tests/puzzle_test.gd
XDG_DATA_HOME="$(mktemp -d)" godot --headless --script res://tests/game_test.gd
godot --path .
```

The puzzle test follows generated hints to a valid solution for the 400 campaign boards and 1,000 additional seeds. The scene test uses an isolated save directory because it tests creating and reloading saved games. The Android workflow exports a debug APK for ordinary CI runs and keeps production signing in a manually invoked path on `main`.

- [Verification and remaining release work](docs/VERIFICATION.md)
- [Store copy and captures](docs/store/LISTING.md)
- [Privacy notice for the offline build](docs/PRIVACY.md)
- [Assets and licences](THIRD_PARTY_NOTICES.md)

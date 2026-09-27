# Known Limitations

Per GDD 121 item 15, this file lists only genuine platform limitations. It does not
list unfinished features.

## Web (itch.io / HTML5)

- **Browser storage can be cleared by the browser or the player.** Saves live in
  IndexedDB (`user://`). Private or incognito windows, "clear site data", storage
  pressure eviction, and Safari's policy of deleting script-writable storage after 7
  days without interaction can all erase the three profiles. The game cannot prevent
  this. It keeps one backup generation per profile, but that backup lives in the
  same storage.
- **Audio starts only after a user gesture.** Browser autoplay policies block audio
  until the first tap or click. The start screen asks for that tap (GDD 12.1, 33.4).
- **Single-threaded build.** The Web export disables threads so itch.io works without
  cross-origin isolation headers (GDD 128.3). Frame pacing on low-end machines is
  therefore bounded by one core.
- **Focus and visibility.** When the tab is hidden, browsers throttle or suspend
  timers. The game pauses on focus loss and does not simulate while away (GDD 90,
  113). This is intentional, but it means no progress while the tab is in the
  background.
- **WebGL 2 is required** (Compatibility renderer). Browsers or GPUs without WebGL 2
  cannot run the game.

## Android

- **Minimum Android version** is limited by Godot 4.7's export templates and the
  `min_sdk` in the release preset (24). Older devices are not supported.
- **Process death.** Android may kill the app in the background. The game saves at
  stable checkpoints and on focus loss, so at most the progress since the last
  checkpoint is lost.
- **Release signing** needs a publisher keystore supplied outside the repository. A
  release AAB cannot be produced from the repository alone, by design (GDD 128.4).

## All platforms

- **No cloud sync.** v1.0 is fully offline (GDD 112). Saves stay on the device and
  browser where they were made. Profiles do not move between Web and Android.
- **Built-in font coverage.** Text uses Godot's built-in default font (GDD 111.2).
  Only English UI is supported, so glyph coverage beyond Latin is not needed.

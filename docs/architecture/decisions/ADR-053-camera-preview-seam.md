# ADR-053 — The Preview Seam Carries Primitives, Not a Camera Controller

- **Status:** Accepted
- **Date:** 2026-08-24
- **Supersedes:** none. Closes the gap A-064 §5 records, and takes the design decision that amendment explicitly declined to take from the UI side.

## Context

FR-REC-03 requires *"a full-screen live camera preview during recording."* There is none. `recording_screen.dart` renders `Positioned.fill(child: ColoredBox(color: Colors.black))`, and `CameraPreview` appears **zero times** anywhere in `lib/`.

### Why it was left open, and by whom

A-064 §5 records the reason precisely: `CameraRecordingPipeline` owns the `CameraController` and does not expose it, *"deliberately, since handing a controller to a widget would let the UI start and stop capture behind the state machine's back."* Mission 3.3 drew that boundary.

The amendment then declined to close it from the wrong side:

> Closing it needs a deliberate seam: the pipeline exposing a preview widget, or a `Listenable` the screen can build a `CameraPreview` from, without exposing capture control. **That is a design decision about the boundary Mission 3.3 drew, and it is recorded here rather than taken by breaking the boundary from the UI side.**

This ADR is that decision.

### The gap is user-visible and self-reporting

A-064 §5 gained first hardware evidence at Mission 8.2. The project owner reported it unprompted, without knowing the gap existed: *"recording is going on and even getting stored in s3 but while recording i cannot see what i'm recording."* Capture, storage and upload all work; only the pixels are missing. It also cost that mission a step — scenario 1's field-of-view check was scoped around looking at a live preview and had to be re-scoped to judge the recorded file.

### What the port exposes today

`RecordingPipeline` declares exactly `openSession`, `startChunk`, `stopChunk`, `closeSession` and `outputDirectory`. Nothing renderable: no controller, no texture, no stream, no listenable.

### The finding that makes a narrow seam possible

`CameraPreview` looks like it needs a controller. It does not. It reduces to three things:

- `controller.buildPreview()`, which is `CameraPlatform.instance.buildPreview(_cameraId)` — **it takes an `int` and nothing else**
- `controller.value`, a `CameraValue` — **immutable data**, carrying `aspectRatio` and the orientation fields
- the controller as a `ValueListenable`, to rebuild when that value changes

So the screen needs a texture id, a shape, and a change signal. **None of those is a capability.** An `int` cannot start a recording.

## Decision

**`CameraRecordingPipeline` exposes preview *data* as pure Dart. It continues to refuse the controller.**

The seam carries three values behind a small domain entity, published as a stream so the port stays free of Flutter types:

- **texture id** — the platform id `buildPreview` needs, null when no session is open
- **aspect ratio** — from `CameraValue.aspectRatio`
- **quarter-turns** — the rotation `CameraPreview` derives from `recordingOrientation`, `lockedCaptureOrientation`, `previewPauseOrientation` and `deviceOrientation`, resolved inside the data layer where those plugin types already live

### The port is a broadcast stream *and* a synchronous getter, deliberately

The seam exposes both:

```dart
Stream<PreviewFrame> get previewChanges;   // broadcast
PreviewFrame? get currentPreview;          // synchronous, may be null
```

**A stream alone would be wrong here, and the reason is a real defect rather than a style preference.** A widget that subscribes after the last emission has nothing to render until something changes — and the preview changes rarely, since orientation and aspect ratio are fixed for most of a session. The screen would show black for an unbounded period, which is the exact symptom this ADR exists to remove. Any rebuild, hot reload, or navigation back onto the screen would reproduce it.

So the getter carries the current value and the stream carries subsequent ones. Presentation seeds its `StreamBuilder` with `initialData: currentPreview`, and the blank-until-next-emission window does not exist.

**Broadcast rather than single-subscription**, because more than one widget may legitimately observe it and a second `listen` on a single-subscription stream throws. `null` from the getter means no session is open, which is a state the screen must render anyway.

`Listenable` and `ValueListenable` were the more idiomatic Flutter shapes and were rejected: both live in `package:flutter/foundation.dart`, and importing them into the port would reintroduce Flutter into `domain/` — the very cost this design pays sixty lines to avoid.

The presentation layer subscribes, builds the preview from the id, and applies the aspect ratio and rotation. `recording_screen.dart` renders it in place of the black `ColoredBox` while a session is open.

### Amendment, 2026-08-24 — rendering was assumed trivial and is not

The decision above says presentation "builds the preview from the id" as though that were a detail. **It is the part that isn't.** Recorded here rather than discovered by whoever maintains this next.

**`CameraPlatform` is not reachable.** `package:camera/camera.dart` exports only `CameraDescription`, `CameraException`, `CameraLensDirection`, `ExposureMode`, `FlashMode`, `FocusMode`, `ImageFormatGroup`, `ResolutionPreset`, `VideoStabilizationMode` and `XFile`. `CameraPlatform` lives in `camera_platform_interface`, which is **transitive** and absent from `pubspec.yaml`. ADR-030 has a section headed *"Transitive dependencies are resolved and audited, never constrained"*, so reaching it means promoting a platform-interface package to a direct application dependency through the admission process.

**And a raw `Texture` is not obviously equivalent.** On Android CameraX, `buildPreview` returns `Texture(textureId: cameraId)` wrapped in a `RotatedPreviewDelegate`, which owns crop and rotation and behaves differently depending on `handlesCropAndRotation`. Skipping that wrapper moves that responsibility onto this project's `quarterTurns`.

**Option B is chosen: Flutter's built-in `Texture`, wrapped in our own `AspectRatio` and `RotatedBox`.** No new dependency, and presentation stays free of the camera plugin entirely — a property worth having on its own. **The device test is the correctness gate, not a formality**: if rotation or crop is visibly wrong on a CPH2707 against what an ordinary camera app shows for the same framing, B has failed and `PreviewFrame.quarterTurns` is the knob that either corrects it or proves it cannot.

**Option A is the named fallback** — promote `camera_platform_interface` and call `CameraPlatform.instance.buildPreview(id)`, which renders identically to `CameraPreview` by construction. It is **not** an automatic fallback: it changes the dependency graph and is a decision to be taken explicitly, not executed silently because a preview looked crooked.

### Amendment, 2026-08-24 (second) — Option B failed the device gate, and it was impossible rather than imperfect

The amendment above named the device test as the correctness gate and Option A as the fallback. **The gate failed.** On a CPH2707 the preview rendered sideways — the project owner confirmed by photo — and no adjustment to `quarterTurns` could have fixed it.

**The reason is structural.** `RotatedPreviewDelegate` does not pass the texture through; it always wraps it, in `SurfaceTextureRotatedPreview` or `ImageReaderRotatedPreview`, and the latter computes:

```dart
(sensorOrientationDegrees - currentDefaultDisplayRotationDegrees * sign + 360) % 360
```

`sensorOrientationDegrees` is reachable — `CameraDescription` carries it. **`currentDefaultDisplayRotationDegrees` is not.** It comes from the platform's `deviceOrientationManager` over a native call, and Flutter exposes portrait-versus-landscape but never the raw 0/90/180/270 display rotation. `SurfaceTextureRotatedPreview` likewise takes a `rotationCorrection` the platform supplies.

So a `PreviewFrame` cannot carry the value the formula needs. **Any constant would be correct in one device orientation and wrong in another** — which is precisely the symptom observed. Option B was not a worse approximation; it was unachievable with the inputs available.

**Option A is adopted.** `camera_platform_interface` is promoted from transitive to a direct dependency and `CameraPlatform.instance.buildPreview(id)` renders the preview — the same code path `CameraPreview` uses, so the output matches an ordinary camera app by construction rather than by tuning.

**The admission checklist was run before adding it**, per Volume 3 §3.8 §4:

1. **No approved package solves it** — `camera` is admitted but exports ten types and `CameraPlatform` is not among them.
2. **Windows build** — `flutter analyze` and the full suite verified locally, which is the only place this can be checked since CI runs Linux.
3. **Maintained, and supports the pinned SDK** — first-party `flutter/packages`, 2.13.1, requiring Dart `^3.10.0` and Flutter `>=3.38.0` against this project's 3.44.9.
4. **Licence** — BSD-3-Clause, pre-approved.
5. **Its own ADR?** No — it is the platform interface of an already-admitted package, reached for one call. Recorded here instead, which is this section.
6. **Explicit constraint** — `^2.13.1`, never bare.

**And the confinement obligation is met rather than assumed.** The existing `camera` check greps `'package:camera[/']`, which does not match `camera_platform_interface`, so the new package would have been unconfined and nothing would have said so. The `Architecture boundaries` job now confines it to **one named file**, `camera_preview_surface.dart`, rather than to a directory — the ADR-039 convention where the filename carries the permission and a neighbour cannot acquire it by being added nearby.

**What this costs, stated plainly.** The presentation layer now imports a camera package, which the first amendment counted as a benefit of Option B. That benefit is gone. What is kept is the one that mattered: the pipeline still refuses the controller, and this widget still holds an `int` it cannot start or stop anything with.

### What the pipeline still refuses, unchanged

- **the `CameraController` itself**
- **`startVideoRecording` / `stopVideoRecording`** — capture is entered and left only through `startChunk` and `stopChunk`, which `RecordingNotifier`'s state machine drives
- **`dispose`** — the session's lifetime remains `openSession`/`closeSession`

### Why Mission 3.3's boundary survives

The boundary exists so the UI cannot start or stop capture behind the state machine. **The UI now holds an `int`, a `double` and an `int` of quarter-turns.** There is no method on any of them to call, so the property is preserved by the *type*, not by discipline — the widget layer cannot misuse a capability it was never given.

This is stronger than the alternative considered below, where a widget holds an object that *has* the methods and is merely trusted not to call them.

### Why the port carries primitives rather than a Widget

The obvious cheaper design is for the pipeline to return a built preview `Widget`. It preserves the control invariant just as well, and needs far less code.

It was rejected because it spends a different invariant. `domain/` is currently pure Dart — verified, not assumed: the only `flutter` string under `features/*/domain/` is inside a comment in `paged_result.dart`, not an import. ADR-026 lists `domain/` purity among the invariants enforced by review rather than by CI, which makes it exactly the kind of rule that erodes quietly. A `Widget` behind a domain port is a presentation type in the layer ADR-001 keeps free of them.

Primitives cost roughly sixty more lines and give up nothing.

### Why not a frame stream

Exposing `Stream<CameraImage>` via `startImageStream` was considered and rejected on runtime grounds rather than architectural ones. It conflicts with video recording on Android, and it ships **every frame into Dart** — for the 25-minute sessions Chapter 9.8 scenario 3 exercises, that is a severe CPU, thermal and battery cost. It would trade a clean architectural question for a bad runtime answer.

## Consequences

**FR-REC-03 becomes satisfiable, and A-064 §5's gap closes.** That amendment gets a dated line pointing here; its record of the gap and the field evidence stays as written.

**This adds compositing, not a new capture path — reasoned, not yet measured.** `CameraController.initialize()` sets up the preview texture whether or not anything displays it, so the camera is already producing preview frames today and the screen is already on and rendering during recording. The incremental cost should therefore be displaying a texture that already exists. **This is read off the plugin's API and has not been confirmed by measurement**; it is the reason to expect a small cost, not evidence of one.

**Chapter 9.4 target 5 is re-verified after implementation.** Scenario 3's 25-minute run is repeated and compared against its original PASS of **−6% battery and +4.3 °C over 24 min 7 s**. Context for reading the result: target 5's limit is 15% per 10-minute chunk against roughly 2.5% observed, so the margin is wide and a flip is unlikely — but that original figure carried partial-window caveats (the device charged for the first two minutes and started warm at 37.9 °C), so it is a rough baseline rather than a precise one.

**This makes Chapter 9.4 target 4 more important, not less.** Target 4 — 60 fps sustained, zero jank — is deferred to Mission 8.3 because it needs a profile build, which ADR-031 records has never been produced here. A live preview compositing every frame is precisely the workload that target exists to measure, so 8.3's profile-build work should follow this change rather than precede it.

**One rendering behaviour moves into this project's code.** `CameraPreview`'s orientation logic — about twenty-five lines mapping four orientation fields to quarter-turns — is reimplemented behind the seam instead of being inherited from the plugin's widget. That is a maintenance cost and a place a future plugin change could silently diverge, and it is the price of not putting a `Widget` in `domain/`.

### Amendment, 2026-08-25 (third) — capture orientation and display orientation were one field, and ADR-054 separates them

**ADR-054 locks capture orientation to landscape. `PreviewFrame`'s three numbers were display values that only happened to equal capture values, and under that lock they stop being equal.**

ADR-053 derives `quarterTurns` and `aspectRatio` from a chain preferring `recordingOrientation` and `lockedCaptureOrientation` over `deviceOrientation`. That was correct while nothing locked capture orientation: the two were always the same value, so which one the chain returned never mattered.

ADR-054 locks capture orientation to landscape. **Both preferred branches then become constants, and the preview freezes** — the seam would stop reporting how to draw and start reporting what was captured, which is not what a preview is for.

The correction is that `PreviewFrame` describes **display only**, and both fields derive from `value.deviceOrientation`. Capture orientation is not exposed through the seam, because nothing that draws needs it.

**What this does not change.** The seam still carries three primitives and no capability: no `Widget`, no `Listenable`, no `CameraValue`, no `CameraController`. Mission 3.3's boundary holds by type exactly as before. `CameraPreviewSurface` still cannot start or stop capture.

**What it costs to have got this wrong the first time: nothing yet, and that is luck rather than judgement.** The conflation was invisible because no feature had ever asked the two values to differ. It is recorded here rather than quietly fixed so the next person to widen this seam knows the two concepts were once one field.

### Amendment, 2026-08-25 (fourth) — `aspectRatio` describes the camera, not the layout

**`PreviewFrame.aspectRatio` stops being orientation-corrected.** It now carries the camera's native ratio — 1.7778 on a 1920x1080 preview — and `CameraPreviewSurface` flips it for portrait using `MediaQuery.orientationOf(context)`.

#### What this record originally said, and why it was wrong

> *"`CameraPreview` flips the controller's raw ratio for portrait. That flip needs `DeviceOrientation`, a plugin type, so it happens in `data/` where that type already lives and this carries the finished number."*

The reasoning was about **where the plugin type lives**, and it should have been about **what the number means**. `aspectRatio` answers *"what shape should this box be"* — a fact about the **window**. The pipeline has no `BuildContext` and therefore no way to know one, so any value it produces is a guess about layout.

#### The guess it made, and what it cost

It flipped on `deviceOrientation`. That value is fed by `onDeviceOrientationChanged`, and `DeviceOrientationManager.start()` in `camera_android_camerax` registers **an `OrientationEventListener` and nothing else** — the `orientationIntentFilter` for `ACTION_CONFIGURATION_CHANGED` is declared at line 28 and `registerReceiver` appears nowhere in the file.

**So `deviceOrientation` updates only when the accelerometer fires.** ADR-054 made the recording screen force landscape through `SystemChrome`; a handset that had not physically moved since the screen opened kept reporting `portraitUp`, and the seam handed a 9:16 ratio to a 16:9 window. Measured on a CPH2707:

```
win=793x360                    <- window IS landscape
deviceOrientation=portraitUp   <- but this says portrait
previewSize=1920x1080  value.aspectRatio=1.7778
FRAME aspectRatio=0.5625  quarterTurns=0
```

`AspectRatio` fitted a 0.5625 box inside 793x360 — roughly a 202x360 column — and squeezed a 16:9 texture into it. **The preview stretched.** A phone on a desk, on a mount, or body-worn is the ordinary case for this product, not an edge case.

#### `quarterTurns` is untouched, and the asymmetry is the point

It still comes from `deviceOrientation`, because the plugin subtracts exactly `getPreAppliedQuarterTurnsRotationFromDeviceOrientation(deviceOrientation)` from its own rotation and expects the widget to add it back. **It is the one number that must not follow the window.**

So the seam's three primitives no longer share a source, and that is correct rather than untidy: two describe the camera, one describes the handset, and the consumer supplies the window. **Nothing about the boundary changes** — no `Widget`, no `Listenable`, no `CameraValue`, no `CameraController`, and `CameraPreviewSurface` still cannot start or stop capture.

#### What it took to find, which is the part worth remembering

**No test asserted `aspectRatio` anywhere.** The regression travelled from a code change, through a full green suite, through a device build, to a person looking at a stretched picture. `camera_preview_surface_test.dart` now pins the window-driven ratio, including the exact stale-`quarterTurns` case, so the next version of this mistake fails in CI rather than on a handset.

### Amendment, 2026-08-26 (fifth) — the preview is contained, not full-bleed, and the chapter is wrong

**Chapter 5.1 §1 requires the preview *"shown full-bleed on the Recording Screen"*. It is not, by decision.** Open item 158 records the departure; this note exists so a reader of the seam is not left believing the chapter is satisfied.

`BoxFit.cover` was implemented and rejected on sight. Filling every edge of a 2.2:1 screen with a 16:9 camera crops the top and bottom away, and **the field of view pushed off the screen is field of view the Collector is about to record**. For a product whose output is the footage, a preview that hides part of the frame is worse than one with bars. The handset's own camera app contains for the same reason.

**What this changes about the seam: nothing.** The three primitives are unchanged, `quarterTurns` still comes from `deviceOrientation` per item 157, and `aspectRatio` is still the camera's native ratio per the fourth amendment. Only the widget's *fit* moved — from `Center` + `AspectRatio` to `FittedBox(fit: BoxFit.contain)` over a `SizedBox` of the same display ratio, which is the same geometry expressed so the fit is a named, testable property rather than an emergent one.

**The separate half worth recording.** `SafeArea` had been wrapping the preview, giving it a **753×320 box inside a 793×360 window** — 40 logical points on each axis for the status bar, navigation bar and cutout. That produced bars on all four sides, and **no fit setting could have fixed it**, because the slot was never the screen. `SafeArea` now wraps only the controls. The height is genuinely full for the first time, and the remaining bars are the aspect ratio's alone.

**Capture is untouched, verified rather than argued.** A clip pulled byte-exact from the handset after this change: coded `avc1` 1920×1080, `tkhd` matrix `(1, 0, 0, 1)`, rotation 0°. `buildPreview` is a display widget over a texture id and this widget holds no `CameraController`, so the seam makes influencing capture structurally impossible rather than merely unlikely — which is the property that let this be changed with confidence at all.


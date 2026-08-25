# ADR-054 — Capture Orientation Is Fixed and Display Orientation Is Free

- **Status:** Accepted
- **Date:** 2026-08-25
- **Supersedes:** none. Amends ADR-053 — see that record's `### Amendment, 2026-08-25` for the seam change this forces.

## Context

Recordings come out portrait. The project owner wants landscape, because egocentric footage is conventionally landscape, and wants the recording screen to rotate with the handset the way a video player does.

### Nothing in this project has ever decided orientation

The text of Volumes 1, 2, 3, 4 and 5 was extracted and searched for *orientation*, *portrait* and *landscape*. **Zero hits in all five.** The amendment register's only occurrence is inside ADR-053's own row. No ADR rules on it.

There is no lock in the code either: no `android:screenOrientation` in any manifest, and `SystemChrome` appears nowhere in `lib/` or `test/`.

**So this is a gap rather than a disagreement.** Neither half of this record contradicts an accepted decision, which is precisely why one is needed — CLAUDE.md's governance rule is that architecture is never left undocumented.

### The defect this exposes is worse than "we picked portrait"

Traced to source. `CameraValue.deviceOrientation` is fed by `onDeviceOrientationChanged`, and on Android that resolves in `DeviceOrientationManager.getUiOrientation()`:

```java
final int orientation = getContext().getResources().getConfiguration().orientation;
```

That is the **window's** `Configuration`, not the raw sensor tilt — it moves only if the window is allowed to follow. Then at `camera_controller.dart:598`, `startVideoRecording` stamps:

```dart
recordingOrientation: Optional<DeviceOrientation>.of(
  value.lockedCaptureOrientation ?? value.deviceOrientation,
),
```

Nothing calls `lockCaptureOrientation`, so the second branch always wins.

**The chain is: the handset's auto-rotate setting → `Configuration.orientation` → `deviceOrientation` → `recordingOrientation`. Every link is outside this project's code.**

The consequence is that **output orientation is a property of the device's settings, not of the build.** A Collector with auto-rotate enabled who holds the phone sideways already gets landscape today, from the same APK. Footage is not comparable across the fleet — which is BR-02's own stated rationale for fixing the field of view, applied to a parameter nobody fixed.

### What the recorded files actually contain

`ffprobe` is not installed, so two real chunks were parsed directly per ISO/IEC 14496-12 — a genuine uploaded chunk (`0000_c032196c-….mp4`, 13.1 MB, named in Chapter 5.14's pattern) and the Mission 8.2 scenario 1 FOV file.

| | both files |
|---|---|
| coded (`avc1`) | **1920 × 1080** |
| `tkhd` display size | 1920 × 1080 |
| `tkhd` matrix `(a,b,c,d)` | **`(0, 1, −1, 0)`** |
| rotation | **90°** |

`(0, 1, −1, 0)` is the canonical 90° rotation matrix, determinant 1.

**The encoder has never produced a portrait frame.** Every chunk this project has ever recorded is landscape 1920×1080 pixels carrying a 90° display tag. "Portrait" is one number in a container header — which is what makes the capture half of this record cheap, and it was measured rather than assumed.

`CameraSpecification.widthPixels = 1920 / heightPixels = 1080` was never wrong, and `capture.resolution`'s `"1920x1080"` was always literally true. Only the tag disagreed.

## Decision

### 1. Capture orientation is locked, once, at session open

`CameraRecordingPipeline.openSession` calls `lockCaptureOrientation` with a landscape constant immediately after the controller opens and before the first frame is published. It is never unlocked and never changed for the life of the session.

This mirrors how Chapter 5.2 §1 already treats the zoom factor — *"fixed for the whole session, never changed mid-recording"* — and extends the same reasoning to the one capture parameter that was left to the handset.

✅ **The constant is `DeviceOrientation.landscapeLeft`, device-verified on a CPH2707 (Android 16) on 2026-08-25.** See the amendment at the foot of this record for the measurements and for the inference that was wrong.

⚠️ **This is not a repeat of ADR-053's Option B failure, and the difference matters.** There, no constant could have been right, because the rotation depended on a native display-rotation value that changes as the handset turns. Here the capture orientation is *being pinned* rather than tracked, so exactly one of two constants is correct in every orientation, permanently. If the first is upside-down the fix is the other one — a one-token change, not a redesign.

### 2. Display orientation stops being the same number as capture orientation

This is the part that touches ADR-053's seam, and the reason these two items could not ship separately.

`_frameOf` currently derives everything from one orientation:

```dart
final DeviceOrientation orientation = value.isRecordingVideo
    ? (value.recordingOrientation ?? value.deviceOrientation)
    : (value.previewPauseOrientation ??
          value.lockedCaptureOrientation ??
          value.deviceOrientation);
```

**Once decision 1 lands, `lockedCaptureOrientation` is non-null and `recordingOrientation` is pinned, so both branches freeze.** The preview would stop rotating at the exact moment the feature asks it to start. That is not a bug introduced by carelessness; it is a design conflation that only becomes visible under this change.

`PreviewFrame` gains a documented split: **`quarterTurns` and `aspectRatio` describe how to draw, and derive from `value.deviceOrientation` alone.** Capture orientation is no longer readable through the seam at all, because nothing that draws needs it.

The seam's shape is unchanged — three numbers, no capability, no `CameraController`. Only the source of two of them moves.

### 3. There is no double-rotation, and `quarterTurns` must **not** be zero

This section originally proposed settling the question on hardware, on the belief that `buildPreview`'s internal rotation and `CameraPreviewSurface`'s outer `RotatedBox` would compose into a double rotation. **The plugin source settles it instead, and the belief was wrong.**

`camera_android_camerax`'s preview delegate ends with an explicit compensation. From `surface_texture_rotated_preview.dart:102`:

> *"Rotated preview according to current default display rotation, **but subtract out rotation applied by the CameraPreview widget** (see camera/camera/lib/src/camera_preview.dart) that is not correct for this plugin."*

```dart
final int rotationCorrection =
    currentDefaultDisplayRotation - preappliedRotationQuarterTurns;
return RotatedBox(quarterTurns: rotationCorrection, child: widget.child);
```

`getPreAppliedQuarterTurnsRotationFromDeviceOrientation` uses the **same table** `CameraPreview._getQuarterTurns()` uses — `portraitUp: 0, landscapeRight: 1, portraitDown: 2, landscapeLeft: 3`.

**The delegate and the outer `RotatedBox` are a matched pair.** The plugin pre-subtracts exactly what the widget is about to add, so the net rotation is `currentDefaultDisplayRotation` and the preview is upright. Removing the outer turn would leave the subtraction uncompensated and rotate the preview *wrongly* — the opposite of the feared failure.

This holds on both code paths: `image_reader_rotated_preview.dart:117` carries the identical comment and the identical subtraction in degrees, so the conclusion does not depend on `surfaceProducerHandlesCropAndRotation`.

**What actually breaks under decision 1, and why decision 2 is the fix.** The two terms agree only while they read the same orientation. The delegate always subtracts the turns for **`deviceOrientation`**, taken from its own stream. `CameraPreview` — and `CameraPreviewSurface`, which reproduces it — adds the turns for `recordingOrientation ?? lockedCaptureOrientation ?? deviceOrientation`.

Lock capture orientation and those diverge: the widget adds turns for the locked landscape value while the plugin subtracts turns for the handset's actual orientation, and the preview sits **one quarter turn out**. Not doubled — desynchronised.

So `quarterTurns` **must** derive from `value.deviceOrientation` alone, because that is precisely the quantity the plugin subtracts. Decision 2 was reached from the seam's design; it turns out to be forced by the plugin's arithmetic as well, which is the stronger reason.

*(This is a latent defect in upstream's own `CameraPreview` on Android: any app that calls `lockCaptureOrientation` desynchronises the same pair. It is noted here because it explains why this project cannot simply defer to the upstream widget's behaviour.)*

### 4. Only the recording route rotates; every other route is locked to portrait

Inverted from the obvious reading. **Nothing is locked today, so the whole app already rotates.** Delivering "only the recording screen rotates" means locking the other routes and releasing one.

- The composition root sets portrait-only at startup.
- `/recording/:sessionId` — top-level, chrome-free, outside the `StatefulShellRoute` — permits all four on entry and restores portrait-only on exit.

Restoring on exit is the load-bearing half: a lock left released would leak landscape into the tab shell, whose layouts have never been seen in it.

**This makes `RecordingScreen` stateful**, against CLAUDE.md's *"stateless widgets by default"*. The exception is deliberate and recorded here: the lock is acquired and released against the widget's lifetime, and there is no correct place to release it other than `dispose`.

### 5. The recording screen's layout stops assuming a tall window

`recording_screen.dart` is a `Stack` with `Alignment.topCenter` for the indicator and `Alignment.bottomCenter` for Stop. In landscape those become the short edges and Stop lands away from the thumb. The controls move to orientation-aware alignments.

Chapter 5.1 §1 requires the preview *"full-bleed on the Recording Screen"*. `CameraPreviewSurface` uses `AspectRatio` inside a `Center`, which **letterboxes** — a pre-existing gap this record does not close, but which landscape makes conspicuous. It is called out here so it is not mistaken for a regression introduced by this work.

### 6. The capture orientation is recorded in metadata

Chunks recorded before and after this change are otherwise indistinguishable, because the pixels and the resolution string are identical and only the tag differs. Mission 8.2A's metadata scope carries a capture-orientation field for exactly this reason. **A dataset that changes a capture parameter without recording it loses the ability to tell its own footage apart.**

## Alternatives Considered

- **Rotate the video mid-session to follow the handset** — rejected, and it is not merely undesirable but unavailable. `recordingOrientation` is stamped once at `startVideoRecording` and never re-read, so orientation cannot change within a chunk. Achieving it would mean forcing a chunk boundary on every rotation, violating BR-05 (*"a chunk boundary is always an internal or Collector-initiated Stop, never a slice"*) and BR-06's 10-minute rule. **This is what makes the Netflix comparison exact: playback UI adapts, the recording does not.**
- **Re-encode to portrait, or capture a genuinely portrait sensor frame** — rejected. The probe shows there is no portrait encode to change, and cropping a landscape sensor to portrait would discard field of view that BR-02 exists to protect.
- **Lock the whole app to landscape** — rejected. Twelve other screens are designed portrait, and the tab shell has never been seen in landscape.
- **Leave orientation to the handset, and document it** — rejected. That is the current state, and it makes output a function of a user setting. Ch 5.2 §2's fleet-comparability argument applies directly.
- **Set `android:screenOrientation` in the manifest** — rejected in favour of `SystemChrome`. A manifest value is per-activity and Flutter has one activity, so it cannot express "portrait everywhere except one route".
- **Ship item 1 alone and item 2 later** — rejected. Decision 1 freezes the preview rotation decision 2 needs, so shipping them apart means writing a record the next mission immediately amends.

## Consequences

- **No backfill, no migration, no re-upload.** Existing S3 objects carry their own rotation tag and still play correctly. Chapter 5.14's key is untouched and BR-11 is unaffected.
- **`capture.resolution` keeps its value.** `"1920x1080"` was accurate before and remains accurate.
- **Output orientation becomes a property of the build.** Two Collectors on different handsets with different auto-rotate settings produce comparable footage for the first time.
- Footage recorded before this change is landscape-tagged-portrait; after, landscape. The metadata field is what makes the two separable.
- `RecordingScreen` becomes stateful, and the reason is recorded rather than left as an unexplained deviation.
- ADR-053's seam survives with two of its three numbers re-sourced. That it absorbs a feature it was not designed for is weak evidence the boundary was cut in the right place — weak, because this is one data point.
- **Both device gates are closed.** The rotation question was answered from the plugin's source (§3); the landscape constant was measured on hardware and is `landscapeLeft` (amendment below).

## Related Missions

- Mission 8.2A — Recording Format & Storage Improvements, items 1 and 2.
- Mission 8.2 — the manual test pass whose scenario 1 file supplied half the probe evidence.

## Implementation Status

**Not implemented. Design accepted and fully verified; no code written.**

Accepting this record approves the design. It is **not** a go-ahead to write the implementation — that needs its own approval. Nothing further is owed to verification: the constant is measured and the rotation question is settled.

---

### Amendment, 2026-08-25 — the constant was measured, the inference was wrong, and the screen rotates landscape-only

**Ran on the CPH2707 (Android 16) with a throwaway probe entrypoint that drove the real `CameraRecordingPipeline` and the real `CameraPreviewSurface`.** The probe and the temporary lock were reverted after measuring; neither is in the tree.

#### `landscapeRight` was wrong

Decision 1 named `landscapeRight` as the value to try first, reasoning from `DeviceOrientationManager.getUiOrientation()`'s mapping. **The reasoning did not survive contact with the device.** Each row is a 2-second clip recorded with capture orientation locked, read back from the `tkhd` matrix:

| lock constant | display rotation 0 | 1 | 3 | verdict |
|---|---|---|---|---|
| `landscapeRight` | 180° | 180° | 180° | **upside-down** |
| `landscapeLeft` | **0°** | **0°** | **0°** | **upright** |

All six clips coded `avc1` **1920×1080**. **`DeviceOrientation.landscapeLeft` is the constant.**

**Both rows also prove the lock itself works**, which is the result decision 1 actually rests on: the tag is *constant across display rotations* where an unlocked build's varies with the handset. Before the lock, the same code produced 90°.

**The inference was reasonable and still wrong, which is the point of the gate.** Decision 1 predicted that if the first constant were upside-down the fix would be one token and not a redesign. That prediction held exactly — but it was the prediction that was worth having, not the constant.

#### The Context section's central claim, confirmed on hardware

The handset reported `accelerometer_rotation = 0` — **auto-rotate off**. That is precisely why this project's recordings are portrait: `Configuration.orientation` never leaves portrait, so `deviceOrientation` never does either. **The chain this record traced through source was observed end to end on the device it was traced for.**

#### Decision 4 is revised: the recording screen rotates between the two landscapes only

Ruled 2026-08-25. The original text permitted all four orientations on `/recording/:sessionId`. **It now permits `landscapeLeft` and `landscapeRight` only** — the screen turns the way a video player turns, never into portrait.

The reasoning is the product's own: the footage is landscape, so a portrait recording UI would frame a landscape capture inside a tall window and show the Collector something the recording is not.

⚠️ **The revision also repairs a defect the original would have shipped.** Flutter's `PlatformChannel.decodeOrientations` maps all four orientations to `0x0f`, which is `ActivityInfo.SCREEN_ORIENTATION_FULL_USER` — and `FULL_USER` **respects the handset's auto-rotate setting**. On this CPH2707, with auto-rotate off, the original decision 4 would have locked every other route to portrait and then **failed to rotate the one route that was supposed to rotate.** The feature would have been invisible on the device it was built for.

The two landscape orientations map to `0x0a`, `SCREEN_ORIENTATION_USER_LANDSCAPE`, which **forces landscape regardless of the auto-rotate setting**. So the narrower request is also the one that works.

**Decision 5 shrinks accordingly.** The recording screen needs one landscape layout, not four orientations' worth. `Alignment.topCenter` and `Alignment.bottomCenter` still move, but only once.

#### One anomaly, recorded rather than tidied away

The `landscapeRight` sweep also covered display rotation 2 (reverse portrait), and that run produced a **0-byte file**. It did not recur in the `landscapeLeft` sweep, which did not cover rotation 2. **It is one observation with no second data point, and it is not diagnosed.** Reverse portrait is now out of scope for the recording screen, so it blocks nothing — but a `stopChunk` that returns a path to an empty file would matter anywhere else, and it is written down here rather than forgotten because the scope changed.

### Amendment, 2026-08-25 (second) — decision 2 over-applied `deviceOrientation`

**Decision 2 moved both `quarterTurns` and `aspectRatio` onto `deviceOrientation`. Only `quarterTurns` belonged there.**

The decision's reasoning was correct and correctly bounded: once decision 1 locks capture orientation, a display value derived from `lockedCaptureOrientation` freezes, so the preview must follow something that moves. §3 then proved `deviceOrientation` specifically, because the plugin subtracts exactly that quantity.

**That argument is about rotation. It was applied to shape as well, and shape is not a sensor fact.** `aspectRatio` answers *"what shape should this box be"*, which the window decides — and the pipeline has no `BuildContext` with which to ask.

The failure was concrete: `deviceOrientation` updates only when the accelerometer fires, so a handset held still while `SystemChrome` rotated the window kept a portrait ratio in a landscape window and the preview stretched. ADR-053's fourth amendment carries the measurements and the plugin source that explains why.

**What the previous code was accidentally doing right.** The chain decision 2 replaced preferred `lockedCaptureOrientation`, which — once decision 1 landed — would have given the correct *landscape* ratio no matter what the sensor reported. Decision 2 removed the thing that was protecting the ratio while fixing the thing that was breaking the rotation. **A change that is right about one field and wrong about another in the same expression is exactly the shape of defect a seam with three primitives from one source invites**, and the seam now sources them separately.

`aspectRatio` is now the camera's native ratio and `CameraPreviewSurface` flips it from `MediaQuery`. Decisions 1, 3, 4 and 5 are unaffected.

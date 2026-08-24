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

⚠️ **Which landscape constant is UNVERIFIED, and this record is Accepted anyway.**

`landscapeRight` is the value to try first, on the reasoning that Android's `ORIENTATION_LANDSCAPE` with `Surface.ROTATION_90` maps to `LANDSCAPE_LEFT` in `DeviceOrientationManager.getUiOrientation()`, so the opposite constant corresponds to the more common clockwise turn. **That is an inference from source, not an observation, and it is recorded as unverified rather than presented as decided.**

It is Accepted with the value open because the *design* does not depend on which of two constants is right — the seam, the lock's placement and the display split are all identical either way. What remains is a value to confirm on a CPH2707, and if it is upside-down the correction is the other constant: one token, no redesign. **Implementation of decisions 1 and 2 should not be considered fully safe to build against until that check clears.**

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
- **One device gate stands between this record and Accepted: which landscape constant is upright.** The rotation question that was the second gate was answered from the plugin's source (§3) and needed no handset.

## Related Missions

- Mission 8.2A — Recording Format & Storage Improvements, items 1 and 2.
- Mission 8.2 — the manual test pass whose scenario 1 file supplied half the probe evidence.

## Implementation Status

**Not implemented. Design accepted; no code written.**

Accepting this record approves the design. It is **not** a go-ahead to write the implementation — that needs its own approval once the landscape constant is confirmed on hardware.

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/recording/application/recording_notifier.dart';
import 'package:mobile/features/recording/domain/entities/preview_frame.dart';
import 'package:mobile/features/recording/domain/repositories/recording_pipeline.dart';

/// FR-REC-03's live preview, drawn from three numbers.
///
/// ADR-053. The pipeline hands out a texture id, a display aspect ratio and a
/// rotation — never the `CameraController` — so this widget can show what the
/// camera sees and cannot start or stop it. That is Mission 3.3's boundary
/// held by type rather than by discipline: there is no method here to misuse.
///
/// ## Why this reproduces `CameraPreview` rather than being it
///
/// `CameraPreview` takes the controller, which is the whole thing being
/// withheld. So its body is reproduced here from the id instead: the same
/// `AspectRatio`, the same `RotatedBox`, the same
/// `CameraPlatform.instance.buildPreview(id)` underneath. Same pixels, no
/// capability.
///
/// **A raw `Texture` was tried first and failed on hardware.** On Android
/// CameraX `buildPreview` wraps the texture in a `RotatedPreviewDelegate`
/// which computes rotation as
/// `(sensorOrientationDegrees - displayRotationDegrees * sign + 360) % 360`.
/// The display rotation is a native value Flutter does not expose, so no
/// [PreviewFrame.quarterTurns] can stand in for it — the preview came out
/// sideways, and no constant would be right in every orientation. ADR-053's
/// amendment records why that made the approach impossible rather than merely
/// imperfect.
///
/// `camera_platform_interface` is therefore a direct dependency, admitted
/// under ADR-030's checklist, and the `Architecture boundaries` job confines
/// it to **this one file** — the filename announces the permission, per the
/// ADR-039 convention.
///
/// ## Cropping the PREVIEW does not crop the RECORDING
///
/// `BoxFit.cover` clips pixels on the way to the screen and nothing else.
/// `buildPreview` is a display widget over a texture id; the file is written by
/// CameraX's `Recorder` from a separate stream, and this widget holds no
/// `CameraController` with which to influence it — ADR-053's whole point.
///
/// So the recorded chunk keeps its full native field of view and its own
/// dimensions. **What the Collector sees is now a crop of what is being
/// recorded**, which is how every camera app behaves, and the metadata
/// `capture.resolution` continues to describe the file rather than the screen.
///
/// ## Black is a real state, not a fallback
///
/// A null frame means no session is open, which is exactly what the screen
/// should show before `openSession` and after `closeSession`. The pipeline
/// emits null on close deliberately, so nothing draws a texture that is about
/// to be disposed.
/// Nominal height the preview box is measured at before `FittedBox` scales
/// it. Only the ratio it forms with the width is meaningful.
const double _ratioUnit = 1000;

class CameraPreviewSurface extends ConsumerWidget {
  /// Creates the preview surface.
  const CameraPreviewSurface({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecordingPipeline pipeline = ref.watch(recordingPipelineProvider);

    return StreamBuilder<PreviewFrame?>(
      stream: pipeline.previewChanges,
      // ADR-053: seeded, not empty. A builder that waited for the next
      // emission would render black until something changed, and a preview
      // changes rarely — so that would be black for the rest of the session,
      // returning on every rebuild. This is the whole reason the port carries
      // a synchronous getter beside the stream.
      initialData: pipeline.currentPreview,
      builder: (BuildContext context, AsyncSnapshot<PreviewFrame?> snapshot) {
        final PreviewFrame? frame = snapshot.data;
        if (frame == null) {
          return const ColoredBox(color: Colors.black);
        }
        // The flip lives here, not in the pipeline. `aspectRatio` answers
        // "what shape should this box be", which is a fact about the window —
        // and `MediaQuery` is the authority on that, updating on every
        // configuration change with no sensor involved.
        //
        // The pipeline used to flip it from `deviceOrientation`, which the
        // platform updates ONLY when the accelerometer fires. A window rotated
        // by `SystemChrome` on a still handset left it portrait while the
        // window was landscape, and a 16:9 texture was squeezed into a 9:16
        // box. ADR-053's fourth amendment records the regression.
        //
        // `quarterTurns` deliberately still comes from `deviceOrientation`:
        // the plugin subtracts exactly that quantity, so it is the one number
        // that must NOT follow the window.
        final bool isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;

        // Chapter 5.1 §1: *"Render the live preview shown full-bleed on the
        // Recording Screen"*. Until now this letterboxed instead — the ratio
        // was correct and the picture sat in the middle with black bars, which
        // is `contain`, not full-bleed. A camera app covers.
        //
        // **Only the FIT changes.** The subtree below `SizedBox` is byte-for-
        // byte what it was: the same `quarterTurns`, the same
        // `buildPreview`, and a box of the same display ratio. That
        // composition is the one confirmed correct on a CPH2707, so the crop
        // is layered on top of known-good geometry rather than replacing it.
        final double displayRatio = isLandscape
            ? frame.aspectRatio
            : 1 / frame.aspectRatio;

        return ClipRect(
          child: ColoredBox(
            color: Colors.black,
            child: FittedBox(
              // `contain`, matching how the handset's own camera app frames
              // its preview: the picture keeps its true ratio and fills the
              // full HEIGHT, with black bars on the left and right where a
              // camera app puts its controls.
              //
              // `cover` was tried and rejected — it fills every edge by
              // cropping the top and bottom away, which throws out field of
              // view the Collector is about to record.
              fit: BoxFit.contain,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                // Arbitrary units: `FittedBox` scales this to the slot, so only
                // the RATIO matters. A thousand rather than a one keeps the
                // texture off sub-pixel logical sizes while it is measured.
                width: displayRatio * _ratioUnit,
                height: _ratioUnit,
                child: RotatedBox(
                  quarterTurns: frame.quarterTurns,
                  child: CameraPlatform.instance.buildPreview(frame.textureId),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
/// ## Black is a real state, not a fallback
///
/// A null frame means no session is open, which is exactly what the screen
/// should show before `openSession` and after `closeSession`. The pipeline
/// emits null on close deliberately, so nothing draws a texture that is about
/// to be disposed.
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
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: frame.aspectRatio,
              child: RotatedBox(
                quarterTurns: frame.quarterTurns,
                child: CameraPlatform.instance.buildPreview(frame.textureId),
              ),
            ),
          ),
        );
      },
    );
  }
}

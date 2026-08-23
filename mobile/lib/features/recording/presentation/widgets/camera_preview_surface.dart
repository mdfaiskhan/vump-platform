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
/// ## Why `Texture` and not `CameraPreview`
///
/// `CameraPreview` needs the controller, which is the whole thing being
/// withheld. Its internals are `CameraPlatform.instance.buildPreview(id)`
/// under an `AspectRatio` and a `RotatedBox`, and `CameraPlatform` is not
/// exported by `package:camera` — it lives in `camera_platform_interface`,
/// which is transitive and which ADR-030 does not permit depending on without
/// an admission process.
///
/// So this reproduces the shape with Flutter's own `Texture`, and the
/// presentation layer stays free of the camera plugin entirely.
///
/// **What that trades away is recorded in ADR-053's amendment**: on Android
/// CameraX, `buildPreview` wraps the texture in a `RotatedPreviewDelegate`
/// that owns crop and rotation. Skipping it puts that job on
/// [PreviewFrame.quarterTurns], and the device test — not this comment — is
/// what establishes whether that is right.
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
                child: Texture(textureId: frame.textureId),
              ),
            ),
          ),
        );
      },
    );
  }
}

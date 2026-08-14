import 'package:flutter/services.dart';

import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/storage_exception.dart';
import 'package:mobile/features/recording/domain/repositories/free_space_reader.dart';

/// Reads free space over the project's only platform channel.
///
/// ## This is the first `MethodChannel` in the repository
///
/// It is confined the way ADR-030 confines a package, even though no package
/// is involved: one file owns the channel, nothing platform-specific leaves
/// it, and the only type crossing the boundary in either direction is a
/// `String` in and an `int` out. `PlatformException` is converted here, so
/// `domain/` and `application/` never see one — the same contract
/// `CameraErrorMapper` provides for the camera plugin.
///
/// Volume 3 Chapter 3.1 already sanctions this pattern by name, listing a
/// "platform-channel extension" for ultra-wide lens selection and a
/// "platform-channel bridge" for iOS background upload.
///
/// ## Why not a package
///
/// `dart:io` has no free-space API, so something native is required. The two
/// maintained candidates — `disk_space_2` and `storage_space` — both return
/// megabytes computed through a **32-bit float** division, and one measures a
/// fixed partition rather than the volume being written to. Amendment A-057's
/// correction records what trusting a float across this boundary already cost
/// this project once.
///
/// ## Platform status, stated rather than implied
///
/// The Android half is verified on hardware. **The iOS half has never
/// executed** — no Mac, no device, no iOS configuration in this project — and
/// is recorded as open against the Volume 9 device matrix in A-058.
class FreeSpaceChannel implements FreeSpaceReader {
  /// Creates a reader over the platform channel, or over a fake one in tests.
  const FreeSpaceChannel({this._channel = _defaultChannel});

  static const MethodChannel _defaultChannel = MethodChannel(
    'vump/free_space',
  );

  final MethodChannel _channel;

  @override
  Future<int> availableBytes(String path) async {
    try {
      final int? bytes = await _channel.invokeMethod<int>('availableBytes', <
        String,
        Object?
      >{'path': path});

      if (bytes == null) {
        throw const StorageException(
          errorCode: ErrorCode.storageUnavailable,
          message: 'The platform reported no free-space value.',
        );
      }
      return bytes;
    } on PlatformException catch (error, stackTrace) {
      throw StorageException(
        errorCode: ErrorCode.storageUnavailable,
        message:
            'Free space could not be read for the recording directory '
            '(platform code: ${error.code}).',
        cause: error,
        stackTrace: stackTrace,
      );
    } on MissingPluginException catch (error, stackTrace) {
      // The channel is registered in MainActivity/AppDelegate, so this means
      // the native half is absent — a packaging fault, not a device
      // limitation. Converted rather than allowed to escape as a Flutter type.
      throw StorageException(
        errorCode: ErrorCode.storageUnavailable,
        message: 'The free-space channel is not registered on this platform.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}

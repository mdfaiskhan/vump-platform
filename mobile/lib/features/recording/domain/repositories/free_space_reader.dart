/// Reports how many bytes remain on the volume chunks are written to.
///
/// Volume 5 Chapter 5.4 §2 gives the pipeline two storage duties, and only the
/// second is this port's concern:
///
/// - **Pre-flight** is *not* here. FR-CHK-02 confirms sufficient free storage
///   before `Recording` is entered, and §2 says the pipeline "does not
///   re-derive that decision".
/// - **Mid-recording** is: watch the number, and force an early chunk boundary
///   before an out-of-space write can corrupt the active file.
///
/// ## Bytes, as an int, deliberately
///
/// Not megabytes and not a `double`. The two maintained pub packages both
/// return MB through a 32-bit float division, and this project has already
/// shipped one defect caused by trusting a float that crossed a platform
/// boundary — the zoom-factor false block corrected in A-057. Keeping the
/// whole path integral removes that class of error rather than bounding it.
abstract interface class FreeSpaceReader {
  /// Bytes available to this application on the volume containing [path].
  ///
  /// [path] is the directory chunks are actually written to, not a guessed
  /// partition — free space is a property of a volume, and the only volume
  /// that matters is the one being written to.
  ///
  /// Throws a `DeviceException` if the platform cannot answer.
  Future<int> availableBytes(String path);
}

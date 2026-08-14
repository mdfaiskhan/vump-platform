/// The exact capture parameters every chunk is recorded at.
///
/// Volume 5 Chapter 5.2 §1 is the authoritative source and calls itself that:
/// these are *"the values every chunk's `metadata.capture` block (Volume 4,
/// Chapter 4.5) records, and the exact numbers used as the worked example
/// there"*. Every constant below is transcribed from that table. **None is
/// derived, rounded or chosen here.**
///
/// ## Why constants rather than configuration
///
/// A capture parameter that varies per build produces footage that is not
/// comparable across the Collector fleet, which is BR-02's own stated
/// rationale for fixing the field of view. The one value that legitimately
/// varies is the zoom factor, and Chapter 5.1's ladder decides it per device
/// rather than per build — see [zoomFactorOptical] and [zoomFactorFallback].
///
/// ## What this class deliberately does not do
///
/// It does not feed the OS encoder. Chapter 5.2 §3 defers that to Chapter 5.4
/// (Recording Pipeline), and this mission does not build it. These values are
/// the contract the pipeline will read, not the mechanism that applies them.
abstract final class CameraSpecification {
  /// Capture width in pixels — 1920, the horizontal half of Full HD.
  static const int widthPixels = 1920;

  /// Capture height in pixels — 1080, the vertical half of Full HD.
  ///
  /// Chapter 5.2 §1: *"Balances footage usability against chunk file size /
  /// upload time on constrained field connectivity."*
  static const int heightPixels = 1080;

  /// Frames per second — 30.
  ///
  /// *"Standard for smooth egocentric walkthrough footage without inflating
  /// file size."*
  static const int frameRate = 30;

  /// Video codec — H.264 (AVC).
  ///
  /// *"Universal hardware-encoder support across the Android device range
  /// this app targets, keeping battery/thermal impact low during a 10-minute
  /// continuous encode."*
  static const String videoCodec = 'H.264';

  /// Target video bitrate in kilobits per second — 8,000.
  ///
  /// Chapter 5.2 §1 writes this as *"~8,000 kbps"*. The tilde is the reason
  /// [minimumVideoBitrateKbps] exists: §2 permits stepping down from this
  /// target, so it is a target and not a floor.
  static const int targetVideoBitrateKbps = 8000;

  /// Audio codec — AAC.
  static const String audioCodec = 'AAC';

  /// Audio channel count — 1 (mono).
  ///
  /// *"mono keeps size down since stereo separation isn't meaningful for a
  /// body-worn/handheld capture."*
  static const int audioChannels = 1;

  /// Audio bitrate in kilobits per second — 128.
  static const int audioBitrateKbps = 128;

  /// The preferred wide-angle zoom factor — 0.5x.
  ///
  /// BR-02 permits *"exactly 0.5x or 0.6x"* and nothing between or beyond.
  /// Which of the two a device uses is decided once by Chapter 5.1's ladder
  /// and then fixed for the life of the install (§2).
  static const double zoomFactorOptical = 0.5;

  /// The permitted alternative wide-angle zoom factor — 0.6x.
  static const double zoomFactorFallback = 0.6;

  /// The widest zoom factor BR-02 accepts, used as the ladder's threshold.
  ///
  /// A device that cannot reach at least this far out is not wide-angle
  /// capable for this application's purposes. Derived from
  /// [zoomFactorFallback] rather than written as a second literal, so the two
  /// cannot drift apart.
  static const double maximumAcceptableZoomFactor = zoomFactorFallback;

  // ---------------------------------------------------------------------------
  // Device-tier adjustments — Chapter 5.2 §2
  // ---------------------------------------------------------------------------

  /// The step size for bitrate reduction on constrained encoders, in kbps.
  ///
  /// §2 permits stepping down *"in fixed increments"* without naming the
  /// increment. 1,000 kbps is this implementation's choice of a value the
  /// chapter left open, and is flagged as such rather than presented as
  /// transcribed: it gives six steps between the target and the floor
  /// (8,000 → 7,000 → 6,000 → 5,000 → 4,000 → 3,000 → 2,000).
  static const int bitrateStepKbps = 1000;

  /// The bitrate below which capture is not worth attempting, in kbps.
  ///
  /// Also this implementation's choice, for the same reason. §2 says to step
  /// down but does not say when to stop.
  static const int minimumVideoBitrateKbps = 2000;

  /// **Resolution and frame rate are never reduced.**
  ///
  /// Chapter 5.2 §2 is explicit that the pipeline *"steps down bitrate (never
  /// resolution or frame rate)"* — *"keeping the field of view and smoothness
  /// consistent across the Collector fleet ... matters more for usable
  /// training data than a slightly larger file."*
  ///
  /// Stated as a named constant so the rule is greppable from the pipeline
  /// that must honour it (Chapter 5.4), rather than living only in prose.
  static const bool resolutionIsFixed = true;
}

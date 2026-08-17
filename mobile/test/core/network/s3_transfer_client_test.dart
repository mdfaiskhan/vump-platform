import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/s3_transfer_client.dart';
import 'package:mobile/core/network/transfer_handle.dart';

/// The redaction that keeps a presigned URL out of the logs.
///
/// A presigned S3 URL is a bearer credential: `X-Amz-Signature` and
/// `X-Amz-Credential` sit in the query string, and anyone holding the URL can
/// write to the bucket until it expires. `LoggingInterceptor` writes
/// `options.uri` in full, and `NetworkConstants.redactedHeaders` redacts
/// headers only — nothing in this project strips a query string. This function
/// is the mitigation, so it is tested directly rather than through a client.
void main() {
  group('redactUrl', () {
    test('strips the AWS signature and credential', () {
      final String safe = S3TransferClient.redactUrl(
        Uri.parse(
          'https://human-archive-dev.s3.amazonaws.com/org/proj/0003_c.mp4'
          '?partNumber=1&uploadId=up_1'
          '&X-Amz-Credential=AKIAEXAMPLE%2F20260815%2Fus-east-1%2Fs3'
          '&X-Amz-Signature=deadbeefcafe',
        ),
      );

      expect(safe, isNot(contains('X-Amz-Signature')));
      expect(safe, isNot(contains('deadbeefcafe')));
      expect(safe, isNot(contains('X-Amz-Credential')));
      expect(safe, isNot(contains('AKIAEXAMPLE')));
      expect(safe, isNot(contains('?')));
    });

    test('keeps the host and path, which is what a reader needs', () {
      expect(
        S3TransferClient.redactUrl(
          Uri.parse(
            'https://human-archive-dev.s3.amazonaws.com/org/proj/0003_c.mp4'
            '?X-Amz-Signature=abc',
          ),
        ),
        'https://human-archive-dev.s3.amazonaws.com/org/proj/0003_c.mp4',
      );
    });

    test('drops a fragment as well as a query', () {
      expect(
        S3TransferClient.redactUrl(Uri.parse('https://s3.example/o#frag')),
        'https://s3.example/o',
      );
    });

    test('keeps a non-default port', () {
      expect(
        S3TransferClient.redactUrl(Uri.parse('https://s3.example:9000/o?s=1')),
        'https://s3.example:9000/o',
      );
    });

    test('a URL with no query survives unchanged', () {
      expect(
        S3TransferClient.redactUrl(Uri.parse('https://s3.example/o')),
        'https://s3.example/o',
      );
    });
  });

  group('TransferHandle', () {
    test('starts uncancelled', () {
      expect(TransferHandle().isCancelled, isFalse);
    });

    test('cancel is observable', () {
      final TransferHandle handle = TransferHandle()..cancel('paused');
      expect(handle.isCancelled, isTrue);
    });

    test('cancelling twice is a no-op, not a throw', () {
      // The caller that cancels often races the one that completes, and
      // neither can know which won.
      final TransferHandle handle = TransferHandle()..cancel();
      expect(handle.cancel, returnsNormally);
      expect(handle.isCancelled, isTrue);
    });

    test('each handle is independent', () {
      // A cancelled token cannot be reset, so resuming means a new handle.
      final TransferHandle first = TransferHandle()..cancel();
      final TransferHandle second = TransferHandle();

      expect(first.isCancelled, isTrue);
      expect(second.isCancelled, isFalse);
    });
  });

  test('the part media type describes a byte range, not a video', () {
    // A part is a slice of an .mp4, so `video/mp4` would be wrong for every
    // part but the first.
    expect(S3TransferClient.binaryContentType, 'application/octet-stream');
  });
}

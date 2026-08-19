import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/error_codes.dart';
import 'package:mobile/core/errors/exceptions/network_exception.dart';
import 'package:mobile/features/projects_tasks/application/read_failure.dart';

/// The one branch F28 added, and the reason it reads the code and not the
/// status.
void main() {
  test('RESOURCE_NOT_FOUND is "not visible to you"', () {
    // A-186: a Project outside the caller's reach is reported absent rather
    // than forbidden, so this arrives as a 404 rather than a 403.
    expect(
      classifyReadFailure(
        const NetworkException(
          errorCode: ErrorCode.networkNotFound,
          message: 'refused',
          statusCode: 404,
          backendCode: 'RESOURCE_NOT_FOUND',
        ),
      ),
      ProjectTaskReadFailure.notVisible,
    );
  });

  test('a 404 with no envelope code is NOT reported as invisible', () {
    // The reason this reads `backendCode` rather than `statusCode`. A 404 from
    // a misrouted request, a proxy, or a gateway is not the backend saying the
    // resource is out of scope, and telling a Collector it "isn't available to
    // you" would state an authorization fact that was never established.
    expect(
      classifyReadFailure(
        const NetworkException(
          errorCode: ErrorCode.networkNotFound,
          message: 'bare 404',
          statusCode: 404,
        ),
      ),
      ProjectTaskReadFailure.unavailable,
    );
  });

  test('a transport failure is unavailable', () {
    expect(
      classifyReadFailure(
        const NetworkException(
          errorCode: ErrorCode.networkTimeout,
          message: 'the network went away',
        ),
      ),
      ProjectTaskReadFailure.unavailable,
    );
  });

  test('another backend code is unavailable, not invisible', () {
    expect(
      classifyReadFailure(
        const NetworkException(
          errorCode: ErrorCode.networkBadRequest,
          message: 'refused',
          statusCode: 400,
          backendCode: 'REQUEST_INVALID_CURSOR',
        ),
      ),
      ProjectTaskReadFailure.unavailable,
    );
  });

  test('a non-exception is unavailable rather than a crash', () {
    // `AsyncValue.error` carries whatever was thrown, and a defect can throw
    // anything. A screen has nothing better to say about a bug than that the
    // data is not there.
    expect(
      classifyReadFailure(StateError('a bug')),
      ProjectTaskReadFailure.unavailable,
    );
    expect(classifyReadFailure(null), ProjectTaskReadFailure.unavailable);
  });
}

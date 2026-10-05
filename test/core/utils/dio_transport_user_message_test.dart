import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:communal_mobile/core/utils/dio_transport_user_message.dart';

DioException _unknown(Object? cause) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.unknown,
      error: cause,
    );

void main() {
  group('what a member is shown when the network fails', () {
    /// The report this was written for. A member on a dropping signal entered
    /// their PIN and read, under the field:
    ///
    ///   DioException [unknown]: null Error: HttpConnection closed before full
    ///   header was received, uri = https://api.communalhq.com/...
    ///
    /// A connection cut mid-reply is an HttpException, not a SocketException,
    /// so it was classed as a real answer from the server — and a real answer
    /// is printed as-is.
    test('a connection cut mid-reply is a transport failure, not an answer', () {
      final e = _unknown(
        const HttpException('HttpConnection closed before full header was received'),
      );

      expect(isDioTransportFailure(e), isTrue);
      expect(dioTransportUserMessage(e), DioTransportUserMessages.noConnection);
      expect(userFacingError(e), isNot(contains('HttpException')));
      expect(userFacingError(e), isNot(contains('DioException')));
    });

    test('no route to the host is still a transport failure', () {
      final e = _unknown(const SocketException('No route to host'));
      expect(isDioTransportFailure(e), isTrue);
      expect(dioTransportUserMessage(e), DioTransportUserMessages.noConnection);
    });

    /// The pinned certificates are compiled in and do not refresh themselves,
    /// so a rotation that outruns a release fails the handshake. Calling that
    /// "no internet connection" would bury it under the one explanation nobody
    /// investigates — it must stay distinguishable.
    test('a failed TLS handshake is NOT reported as no connection', () {
      final e = _unknown(const HandshakeException('certificate verify failed'));

      expect(isDioTransportFailure(e), isFalse);
      expect(
        dioTransportUserMessage(e),
        isNot(DioTransportUserMessages.noConnection),
      );
    });

    /// The data-plans report: Dio's own timeout text tells the reader to raise
    /// RequestOptions.connectTimeout, which is advice for a developer.
    test('a timeout says so in words a member can act on', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      );

      expect(userFacingError(e), DioTransportUserMessages.timeout);
      expect(userFacingError(e), isNot(contains('connectTimeout')));
      expect(userFacingError(e), isNot(contains('0:00:30')));
    });
  });

  group('userFacingError', () {
    /// The app throws Exception("Too many PIN attempts. Try again in 5
    /// minutes.") on purpose. That text is the message and must survive.
    test('keeps a sentence the app threw deliberately', () {
      expect(
        userFacingError(Exception('Too many PIN attempts. Try again in 5 minutes.')),
        'Too many PIN attempts. Try again in 5 minutes.',
      );
    });

    test('never returns an empty string', () {
      expect(userFacingError(Exception('')), DioTransportUserMessages.generic);
      expect(userFacingError(null), DioTransportUserMessages.generic);
    });
  });
}

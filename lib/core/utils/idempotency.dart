import 'package:uuid/uuid.dart';

/// Generates an `Idempotency-Key` value for non-idempotent HTTP requests
/// (transfers, loan applications, KYC submissions, obligation payments).
///
/// **Why this exists (audit M23):** before this helper, retrying a transfer
/// after a flaky-4G timeout could double-process the operation server-side.
/// Pair this with the `idempotencyKey` parameter on `DioClient.{post,put}`
/// — the backend honors the header to dedupe.
///
/// **Caller contract:** generate the key **once per logical operation** and
/// reuse it across automatic and user-initiated retries. The convention is
/// to call `newIdempotencyKey()` in screen state when the user first taps
/// "Confirm" / "Submit", not inside the repository (which would mint a fresh
/// key on every retry and defeat the purpose).
String newIdempotencyKey() => const Uuid().v4();

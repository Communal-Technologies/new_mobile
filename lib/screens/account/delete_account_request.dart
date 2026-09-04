import 'package:communal_mobile/data/repositories/account_actions_repository.dart';

/// What the delete-account flow carries from screen to screen.
///
/// The [preview] is fetched once, on the first screen, and passed down rather
/// than re-fetched: every screen after it has to describe the same account state
/// the member agreed to. It is not the gate, though — the server evaluates the
/// checkpoints again when the delete is sent, so a stale preview can only ever
/// produce a refusal, never a deletion that should not have happened.
///
/// [confirmation] is the word the member typed, carried to the PIN screen because
/// that is where the delete is actually sent: verifying and submitting in one
/// handler is what keeps a verified PIN from sitting around unspent.
class DeleteAccountRequest {
  const DeleteAccountRequest({
    required this.preview,
    this.reason,
    this.confirmation = '',
  });

  final AccountDeletionPreview preview;
  final String? reason;
  final String confirmation;

  DeleteAccountRequest copyWith({String? reason, String? confirmation}) =>
      DeleteAccountRequest(
        preview: preview,
        reason: reason ?? this.reason,
        confirmation: confirmation ?? this.confirmation,
      );
}

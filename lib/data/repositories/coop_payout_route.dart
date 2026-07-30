import 'member_obligations_repository.dart';
import 'transfer_repository.dart';

/// How a payment to a cooperative cash repository must reach Anchor.
///
/// Anchor-provisioned repositories are internal accounts: they are reachable by
/// BookTransfer and have no NIP bank code at all. Repositories a cooperative
/// added itself are external and need a verified counterparty. Sending an
/// Anchor account down the NIP path is what produced "Invalid Bank Id" — its
/// `bank` column holds a display name ("PROVIDUS BANK"), not a code.
class CoopPayoutRoute {
  const CoopPayoutRoute({
    required this.type,
    required this.bankLabel,
    required this.accountName,
    this.counterPartyId,
    this.destinationAccountId,
    this.nipCode = '',
  });

  /// 'BookTransfer' or 'NIPTransfer' — pass straight to
  /// [TransferRepository.initiateTransfer].
  final String type;

  final String bankLabel;
  final String accountName;
  final String? counterPartyId;
  final String? destinationAccountId;
  final String nipCode;

  bool get isBook => type == 'BookTransfer';
}

/// Resolves the transfer route for [cash], creating and verifying an Anchor
/// counterparty only when one is actually needed.
///
/// Throws with an actionable message when the repository is external but its
/// `bank` column holds a name rather than a NIP code — that row is unpayable
/// until an administrator re-selects the bank on the dashboard.
Future<CoopPayoutRoute> resolveCoopPayoutRoute(
  TransferRepository transferRepo,
  CooperativeCashBankAccount cash,
) async {
  if (cash.isAnchor) {
    return CoopPayoutRoute(
      type: 'BookTransfer',
      destinationAccountId: cash.anchorAccountId,
      bankLabel: cash.bankName.isEmpty ? 'Anchor' : cash.bankName,
      accountName: cash.accountName,
    );
  }

  if (cash.bankCode.isEmpty) {
    throw Exception(
      'The cooperative account "${cash.accountName}" has no valid bank code. '
      'Please ask your cooperative administrator to re-select the bank for '
      'this account, or choose a different account.',
    );
  }

  final verified = await transferRepo.verifyAccount(
    bankCode: cash.bankCode,
    accountNumber: cash.accountNumber,
  );
  final counterpartyId = await transferRepo.createCounterParty(
    bankCode: cash.bankCode,
    accountNumber: cash.accountNumber,
    accountName: verified.accountName,
  );

  return CoopPayoutRoute(
    type: 'NIPTransfer',
    counterPartyId: counterpartyId,
    bankLabel: verified.bankName ?? cash.bankName,
    accountName: verified.accountName,
    nipCode: cash.bankCode,
  );
}

// A member missing BVN (KYC step 2) must never be stranded on a "wallet pending"
// screen with no way back to the BVN step. The wallet is provisioned only once BVN
// is approved, so "pending wallet" must mean BVN was actually submitted; a tier
// promoted by an ID-only acceptance with no BVN (the pre-guard bypass) must fall
// through to the verify prompt, which routes to the bank step.
//
// Author:    Daniel Michael <engrdanywiss@gmail.com> / <master-daniel@communalhq.com>
// Company:   Communal Technologies Limited
// Copyright: © 2026 Communal Technologies Limited. All rights reserved.

import 'package:communal_mobile/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user({
  String? tier,
  bool step2 = false,
  String? workflow,
  String? walletAccountNumber,
  String? kycStatus,
}) {
  return UserModel(
    id: 'u-1',
    name: 'Test Member',
    login: 'member@example.com',
    communalTier: tier,
    kycStep2Submitted: step2,
    kycWorkflowStatus: workflow,
    kycStatus: kycStatus,
    walletAccountNumber: walletAccountNumber,
  );
}

void main() {
  group('shouldShowHomeKycPendingWalletProvisioning', () {
    test('tier_2 with an accepted ID but NO BVN does not read as pending', () {
      // The bypass: identity accepted, tier promoted, but BVN never submitted and
      // no wallet will ever come. Must fall through to the verify prompt, not sit
      // on a perpetual "pending wallet" card.
      final u = _user(tier: 'tier_2', step2: false, workflow: 'tier2_submitted');
      expect(u.shouldShowHomeKycPendingWalletProvisioning, isFalse);
    });

    test('BVN submitted, wallet not yet provisioned, reads as pending', () {
      final u = _user(tier: 'tier_1', step2: true);
      expect(u.shouldShowHomeKycPendingWalletProvisioning, isTrue);
    });

    test('BVN submitted but wallet already provisioned is not pending', () {
      final u = _user(tier: 'tier_1', step2: true, walletAccountNumber: '1234567890');
      expect(u.shouldShowHomeKycPendingWalletProvisioning, isFalse);
    });

    test('no BVN and no tier is not pending', () {
      final u = _user(tier: 'tier_0', step2: false);
      expect(u.shouldShowHomeKycPendingWalletProvisioning, isFalse);
    });

    test('rejected verification is never pending', () {
      final u = _user(tier: 'tier_0', step2: false, kycStatus: 'rejected');
      expect(u.shouldShowHomeKycPendingWalletProvisioning, isFalse);
    });
  });
}

// test/features/wallet/domain/usecases/get_wallet_balance_test.dart

// import 'package:flutter_test/flutter_test.dart';
// import 'package:mockito/mockito.dart';
// import 'package:your_app/features/wallet/domain/usecases/get_wallet_balance.dart';
// import 'package:your_app/features/wallet/domain/entities/wallet.dart';

// class MockWalletRepository extends Mock implements WalletRepository {}

// void main() {
//   late GetWalletBalance usecase;
//   late MockWalletRepository mockRepo;

//   setUp(() {
//     mockRepo = MockWalletRepository();
//     usecase = GetWalletBalance(mockRepo);
//   });

//   test('should return Wallet entity for given userId', () async {
//     const userId = '123';
//     final wallet = Wallet(userId: userId, balance: 5000.0);

//     when(mockRepo.getWallet(userId)).thenAnswer((_) async => wallet);

//     final result = await usecase(userId);

//     expect(result.balance, 5000.0);
//     verify(mockRepo.getWallet(userId));
//     verifyNoMoreInteractions(mockRepo);
//   });
// }

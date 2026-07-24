import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/wallet_funding_required_banner.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/bills/bill_provider.dart';
import 'package:communal_mobile/data/repositories/bills_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_brand_chip.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_inputs.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_screen_hero.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Form for buying airtime. Provider list is fetched once on mount
/// (cached server-side for an hour, so this is cheap). Amount is taken
/// in major units (NGN) and converted to kobo for the API.
///
/// On Continue we navigate to the shared bill-result screen with the
/// purchase parameters as `extra`. The result screen owns the POST and
/// the idempotency key.
class AirtimePurchaseScreen extends StatefulWidget {
  const AirtimePurchaseScreen({super.key});

  @override
  State<AirtimePurchaseScreen> createState() => _AirtimePurchaseScreenState();
}

class _AirtimePurchaseScreenState extends State<AirtimePurchaseScreen> {
  late final BillsRepository _repo = BillsRepository(getIt<DioClient>());

  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

  List<BillProvider> _providers = const [];
  bool _loadingProviders = true;
  String? _providersError;
  BillProvider? _selectedProvider;

  static const _quickAmounts = [100, 200, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loadingProviders = true;
      _providersError = null;
    });
    try {
      final list = await _repo.fetchAirtimeProviders();
      if (!mounted) return;
      setState(() {
        _providers = list;
        _selectedProvider = list.isNotEmpty ? list.first : null;
        _loadingProviders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProviders = false;
        _providersError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onContinue() {
    final provider = _selectedProvider;
    if (provider == null) {
      AppToast.error('Pick a network first.');
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      AppToast.error('Enter a valid phone number.');
      return;
    }
    final money = Money.tryParseMajor(_amountController.text.trim(), 'NGN');
    if (money == null || money.amountMinor < 5000 || money.amountMinor > 5000000) {
      AppToast.error('Amount must be between ₦50 and ₦50,000.');
      return;
    }

    context.pushNamed(
      'bill-confirm',
      extra: {
        'kind': 'airtime',
        'provider': provider.slug,
        'provider_name': provider.name,
        'biller_code': provider.billerCode ?? provider.slug,
        'phone_number': phone,
        'amount_minor': money.amountMinor,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final hasWalletBalance = authState is AuthAuthenticated
        ? authState.user.hasWalletBalance
        : false;
    return Scaffold(
      appBar: AppBar(title: const Text('Buy airtime'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BillScreenHero(
                icon: Iconsax.call_calling,
                title: 'Top up airtime',
                subtitle: 'Pick a network and an amount.',
                accent: Color(0xFFFF7B3D),
              ),
              vSpace(20),
              if (!hasWalletBalance) ...[
                const WalletFundingRequiredBanner(
                  message:
                      'You need a funded Communal wallet to buy airtime. '
                      'Fund your wallet to continue.',
                ),
              ],
              _buildProviderPicker(),
              vSpace(20),
              _label('Phone number'),
              vSpace(8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: billInputDecoration(context, 'e.g. 08012345678'),
              ),
              vSpace(20),
              _label('Amount (₦)'),
              vSpace(8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: billInputDecoration(context, 'e.g. 500'),
              ),
              vSpace(12),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  for (final n in _quickAmounts)
                    ActionChip(
                      label: Text('₦$n'),
                      onPressed: () =>
                          _amountController.text = n.toString(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          child: ElevatedButton(
            onPressed: (_selectedProvider == null || !hasWalletBalance)
                ? null
                : _onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7434FF),
              minimumSize: Size(double.infinity, 52.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
              ),
            ),
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w600,
                // Background is the brand purple in both themes, so the
                // label needs a fixed white. Reading from `cardColor`
                // worked in light mode (cardColor = Colors.white) but
                // resolved to near-black in dark mode (cardColor =
                // 0xFF1E1E1E), painting the text dark on purple.
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderPicker() {
    if (_loadingProviders) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_providersError != null) {
      return Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _providersError!,
                style: TextStyle(fontSize: 16.sp, color: Colors.red.shade700),
              ),
            ),
            TextButton(onPressed: _loadProviders, child: const Text('Retry')),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Network'),
        vSpace(8),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            for (final p in _providers)
              BillBrandChip(
                label: p.name,
                selected: _selectedProvider?.id == p.id,
                accent: const Color(0xFFFF7B3D),
                onTap: () => setState(() => _selectedProvider = p),
              ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );

}

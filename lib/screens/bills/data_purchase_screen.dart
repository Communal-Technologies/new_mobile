import 'dart:async';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/ng_mobile_network.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/wallet_funding_required_banner.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/bills/bill_product.dart';
import 'package:communal_mobile/data/models/bills/bill_provider.dart';
import 'package:communal_mobile/data/repositories/bills_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_brand_chip.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_phone_field.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_plan_picker.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_screen_hero.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Form for buying data. The phone number comes first and picks the network
/// from its prefix; the network's fixed-price plans load into a bottom sheet.
/// Amount comes from the chosen plan.
class DataPurchaseScreen extends StatefulWidget {
  const DataPurchaseScreen({super.key});

  @override
  State<DataPurchaseScreen> createState() => _DataPurchaseScreenState();
}

class _DataPurchaseScreenState extends State<DataPurchaseScreen> {
  late final BillsRepository _repo = BillsRepository(getIt<DioClient>());

  final _phoneController = TextEditingController();

  List<BillProvider> _providers = const [];
  bool _loadingProviders = true;
  String? _providersError;
  BillProvider? _selectedProvider;

  List<BillProduct> _products = const [];
  bool _loadingProducts = false;
  String? _productsError;
  BillProduct? _selectedProduct;

  NgMobileNetwork? _detectedNetwork;
  bool _networkPickedByHand = false;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loadingProviders = true;
      _providersError = null;
    });
    try {
      final list = await _repo.fetchDataProviders();
      if (!mounted) return;
      setState(() {
        _providers = list;
        _selectedProvider =
            (_networkPickedByHand ? null : _providerFor(_detectedNetwork, list)) ??
            (list.isNotEmpty ? list.first : null);
        _loadingProviders = false;
      });
      if (_selectedProvider != null) {
        unawaited(_loadProducts(_selectedProvider!));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProviders = false;
        _providersError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadProducts(BillProvider provider) async {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
      _selectedProduct = null;
      _products = const [];
    });
    try {
      final list = await _repo.fetchProductsForBiller(provider.id);
      if (!mounted || _selectedProvider?.id != provider.id) return;
      setState(() {
        _products = list;
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _productsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  static BillProvider? _providerFor(
    NgMobileNetwork? network,
    List<BillProvider> providers,
  ) {
    if (network == null) return null;
    for (final p in providers) {
      if (network.matchesProvider(p.name)) return p;
    }
    return null;
  }

  void _onNetworkChanged(NgMobileNetwork? network) {
    _detectedNetwork = network;
    _networkPickedByHand = false;
    final match = _providerFor(network, _providers);
    if (match != null && match.id != _selectedProvider?.id) {
      _onProviderChanged(match);
    }
  }

  void _onProviderChanged(BillProvider p) {
    setState(() => _selectedProvider = p);
    _loadProducts(p);
  }


  void _onContinue() {
    FocusManager.instance.primaryFocus?.unfocus();
    final provider = _selectedProvider;
    final product = _selectedProduct;
    if (provider == null) {
      AppToast.error('Pick a network first.');
      return;
    }
    if (product == null) {
      AppToast.error('Pick a data plan.');
      return;
    }
    final phone = ngLocalPhone(_phoneController.text);
    if (phone.length != 11) {
      AppToast.error('Enter a valid 11-digit phone number.');
      return;
    }

    BillPhoneField.remember(context, phone);
    context.pushNamed(
      'bill-confirm',
      extra: {
        'kind': 'data',
        'provider': provider.slug,
        'provider_name': provider.name,
        'biller_code': provider.billerCode ?? provider.slug,
        'phone_number': phone,
        'amount_minor': product.priceMinor,
        'product_slug': product.slug,
        'product_name': product.name,
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
      appBar: AppBar(title: const Text('Buy data'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BillScreenHero(
                icon: Iconsax.global,
                title: 'Buy data',
                subtitle: 'Enter a number and pick a plan.',
                accent: Color(0xFF2BA6FF),
              ),
              vSpace(20),
              if (!hasWalletBalance) ...[
                const WalletFundingRequiredBanner(
                  message:
                      'You need a funded Communal wallet to buy data. '
                      'Fund your wallet to continue.',
                ),
              ],
              _label('Phone number'),
              vSpace(8),
              BillPhoneField(
                controller: _phoneController,
                accent: const Color(0xFF2BA6FF),
                onNetworkChanged: _onNetworkChanged,
              ),
              vSpace(20),
              _buildProviderPicker(),
              vSpace(20),
              _label('Data plan'),
              vSpace(8),
              _buildPlans(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          child: ElevatedButton(
            onPressed:
                (_selectedProvider == null ||
                    _selectedProduct == null ||
                    !hasWalletBalance)
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
                logoUrl: p.logoUrl,
                selected: _selectedProvider?.id == p.id,
                accent: const Color(0xFF2BA6FF),
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _networkPickedByHand = true;
                  if (_selectedProvider?.id != p.id) _onProviderChanged(p);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlans() {
    final theme = Theme.of(context);
    if (_loadingProducts) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_productsError != null) {
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
                _productsError!,
                style: TextStyle(fontSize: 16.sp, color: Colors.red.shade700),
              ),
            ),
            TextButton(
              onPressed: () {
                final provider = _selectedProvider;
                if (provider != null) unawaited(_loadProducts(provider));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return Text(
        'No data plans available for this network.',
        style: TextStyle(
          fontSize: 16.sp,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      );
    }
    return BillPlanPicker(
      products: _products,
      selected: _selectedProduct,
      accent: const Color(0xFF2BA6FF),
      onSelected: (plan) {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _selectedProduct = plan);
      },
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


import 'dart:async';

import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/bills/bill_product.dart';
import 'package:communal_mobile/data/models/bills/bill_provider.dart';
import 'package:communal_mobile/data/repositories/bills_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_brand_chip.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_inputs.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_screen_hero.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Form for buying data. Picks a provider, then loads the provider's
/// fixed-price products into a bottom sheet for selection. Phone number
/// is the recipient MSISDN. Amount comes from the chosen product.
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
        _selectedProvider = list.isNotEmpty ? list.first : null;
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
      if (!mounted) return;
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

  void _onProviderChanged(BillProvider p) {
    setState(() => _selectedProvider = p);
    _loadProducts(p);
  }

  Future<void> _openProductSheet() async {
    if (_loadingProducts) return;
    if (_productsError != null) {
      // Retry inline if the previous load failed.
      if (_selectedProvider != null) {
        unawaited(_loadProducts(_selectedProvider!));
      }
      return;
    }
    if (_products.isEmpty) {
      AppToast.error('No data plans available for this provider.');
      return;
    }
    final picked = await showModalBottomSheet<BillProduct>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _ProductPickerSheet(products: _products),
    );
    if (picked != null && mounted) {
      setState(() => _selectedProduct = picked);
    }
  }

  void _onContinue() {
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
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      AppToast.error('Enter a valid phone number.');
      return;
    }

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
                subtitle: 'Pick a network and a plan.',
                accent: Color(0xFF2BA6FF),
              ),
              vSpace(20),
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
              _label('Data plan'),
              vSpace(8),
              _buildProductTile(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          child: ElevatedButton(
            onPressed: (_selectedProvider == null || _selectedProduct == null)
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
                accent: const Color(0xFF2BA6FF),
                onTap: () => _onProviderChanged(p),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductTile() {
    final selected = _selectedProduct;
    final theme = Theme.of(context);
    return InkWell(
      onTap: _openProductSheet,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          // theme.cardColor + theme.dividerColor instead of grey.shade50
          // / grey.shade300 so the tile follows the active theme. The
          // hardcoded shades stayed white in dark mode and made the
          // input read as a stuck-on-light artifact next to the
          // theme-aware phone-number field above.
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _loadingProducts
                    ? 'Loading plans…'
                    : _productsError != null
                    ? 'Could not load plans — tap to retry'
                    : selected == null
                    ? 'Tap to pick a data plan'
                    : '${selected.name} • ${Money(selected.priceMinor, 'NGN').format()}',
                style: TextStyle(
                  fontSize: 17.sp,
                  color: selected == null
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
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

class _ProductPickerSheet extends StatelessWidget {
  const _ProductPickerSheet({required this.products});

  final List<BillProduct> products;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          itemCount: products.length,
          separatorBuilder: (_, __) =>
              Divider(color: Theme.of(context).dividerColor),
          itemBuilder: (ctx, i) {
            final p = products[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                p.name,
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
              ),
              trailing: Text(
                Money(p.priceMinor, 'NGN').format(),
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7434FF),
                ),
              ),
              onTap: () => Navigator.of(ctx).pop(p),
            );
          },
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/bills/bill_customer.dart';
import 'package:communal_mobile/data/models/bills/bill_product.dart';
import 'package:communal_mobile/data/models/bills/bill_provider.dart';
import 'package:communal_mobile/data/repositories/bills_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_brand_chip.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Form for buying cable TV (DSTV / GoTV / StarTimes) via Anchor.
/// Plans are fixed-price; amount comes from the chosen product.
class TelevisionPurchaseScreen extends StatefulWidget {
  const TelevisionPurchaseScreen({super.key});

  @override
  State<TelevisionPurchaseScreen> createState() => _TelevisionPurchaseScreenState();
}

class _TelevisionPurchaseScreenState extends State<TelevisionPurchaseScreen> {
  late final BillsRepository _repo = BillsRepository(getIt<DioClient>());

  final _smartCardController = TextEditingController();
  final _phoneController = TextEditingController();

  List<BillProvider> _providers = const [];
  bool _loadingProviders = true;
  String? _providersError;
  BillProvider? _selectedProvider;

  List<BillProduct> _products = const [];
  bool _loadingProducts = false;
  String? _productsError;
  BillProduct? _selectedProduct;

  bool _validating = false;
  String? _validationError;
  BillCustomer? _validatedCustomer;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _smartCardController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loadingProviders = true;
      _providersError = null;
    });
    try {
      final list = await _repo.fetchTelevisionProviders();
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
    setState(() {
      _selectedProvider = p;
      _selectedProduct = null;
      _validatedCustomer = null;
      _validationError = null;
    });
    unawaited(_loadProducts(p));
  }

  Future<void> _openProductSheet() async {
    if (_loadingProducts) return;
    if (_productsError != null) {
      if (_selectedProvider != null) {
        unawaited(_loadProducts(_selectedProvider!));
      }
      return;
    }
    if (_products.isEmpty) {
      AppToast.error('No plans available for this provider.');
      return;
    }
    final picked = await showModalBottomSheet<BillProduct>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _TvPlanSheet(products: _products),
    );
    if (picked != null && mounted) {
      setState(() => _selectedProduct = picked);
    }
  }

  Future<void> _onValidate() async {
    final provider = _selectedProvider;
    final card = _smartCardController.text.trim();
    if (provider == null) {
      AppToast.error('Pick a TV provider first.');
      return;
    }
    if (card.length < 6) {
      AppToast.error('Enter the smartcard / decoder number.');
      return;
    }
    setState(() {
      _validating = true;
      _validationError = null;
      _validatedCustomer = null;
    });
    try {
      final customer = await _repo.validateCustomer(
        billerSlug: provider.slug,
        accountNumber: card,
      );
      if (!mounted) return;
      setState(() => _validatedCustomer = customer);
    } catch (e) {
      if (!mounted) return;
      setState(() => _validationError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  void _onContinue() {
    final provider = _selectedProvider;
    final product = _selectedProduct;
    final customer = _validatedCustomer;
    final phone = _phoneController.text.trim();
    if (provider == null) {
      AppToast.error('Pick a TV provider.');
      return;
    }
    if (product == null) {
      AppToast.error('Pick a plan.');
      return;
    }
    if (customer == null) {
      AppToast.error('Validate the smartcard first.');
      return;
    }
    if (phone.length < 10) {
      AppToast.error('Enter a valid phone number.');
      return;
    }

    context.pushNamed(
      'bill-confirm',
      extra: {
        'kind': 'television',
        'provider': provider.slug,
        'provider_name': provider.name,
        'product_slug': product.slug,
        'product_name': product.name,
        'smart_card_number': _smartCardController.text.trim(),
        'phone_number': phone,
        'amount_minor': product.priceMinor,
        'customer_name': customer.customerName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _selectedProvider != null &&
        _selectedProduct != null &&
        _validatedCustomer != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Cable TV'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProviderPicker(),
              vSpace(20),
              _label('Smartcard / decoder number'),
              vSpace(8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _smartCardController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      onChanged: (_) {
                        if (_validatedCustomer != null) {
                          setState(() => _validatedCustomer = null);
                        }
                      },
                      decoration: billInputDecoration(context, 'e.g. 7030495169'),
                    ),
                  ),
                  hSpace(10),
                  SizedBox(
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: _validating ? null : _onValidate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7434FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: _validating
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Validate',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
              if (_validationError != null) ...[
                vSpace(8),
                Text(
                  _validationError!,
                  style: TextStyle(fontSize: 14.sp, color: Colors.red.shade700),
                ),
              ],
              if (_validatedCustomer != null) ...[
                vSpace(10),
                _buildCustomerCard(_validatedCustomer!),
              ],
              vSpace(20),
              _label('Plan'),
              vSpace(8),
              _buildPlanTile(),
              vSpace(20),
              _label('Phone number (for receipt SMS)'),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          child: ElevatedButton(
            onPressed: canContinue ? _onContinue : null,
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
        _label('Provider'),
        vSpace(8),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            for (final p in _providers)
              BillBrandChip(
                label: p.name,
                selected: _selectedProvider?.id == p.id,
                accent: const Color(0xFF22C55E),
                onTap: () => _onProviderChanged(p),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanTile() {
    final selected = _selectedProduct;
    return InkWell(
      onTap: _openProductSheet,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.grey.shade300),
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
                            ? 'Tap to pick a plan'
                            : '${selected.name} • ${Money(selected.priceMinor, 'NGN').format()}',
                style: TextStyle(
                  fontSize: 17.sp,
                  color: selected == null
                      ? Colors.grey.shade600
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(BillCustomer c) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade700),
          hSpace(10),
          Expanded(
            child: Text(
              c.customerName,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
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

class _TvPlanSheet extends StatelessWidget {
  const _TvPlanSheet({required this.products});

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
          separatorBuilder: (_, __) => Divider(color: Colors.grey.shade200),
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

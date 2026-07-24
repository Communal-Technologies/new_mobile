import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/wallet_funding_required_banner.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Form for buying electricity via Anchor. Flow: pick disco → pick
/// product (prepaid / postpaid) → enter meter → validate meter → enter
/// phone + amount → Continue. Validation locks the meter+disco pair so
/// the user can't change them after we've shown the registered name.
class ElectricityPurchaseScreen extends StatefulWidget {
  const ElectricityPurchaseScreen({super.key});

  @override
  State<ElectricityPurchaseScreen> createState() => _ElectricityPurchaseScreenState();
}

class _ElectricityPurchaseScreenState extends State<ElectricityPurchaseScreen> {
  late final BillsRepository _repo = BillsRepository(getIt<DioClient>());

  final _meterController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

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
    _meterController.dispose();
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
      final list = await _repo.fetchElectricityProviders();
      if (!mounted) return;
      setState(() {
        _providers = list;
        _selectedProvider = list.isNotEmpty ? list.first : null;
        _loadingProviders = false;
      });
      if (_selectedProvider != null) {
        await _loadProducts(_selectedProvider!);
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
        _selectedProduct = list.isNotEmpty ? list.first : null;
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
      _validatedCustomer = null;
      _validationError = null;
    });
    _loadProducts(p);
  }

  Future<void> _onValidate() async {
    final provider = _selectedProvider;
    final meter = _meterController.text.trim();
    if (provider == null) {
      AppToast.error('Pick an electricity provider first.');
      return;
    }
    if (meter.length < 6) {
      AppToast.error('Enter the meter / account number.');
      return;
    }
    if (_products.isEmpty) {
      AppToast.error('Still loading meter types — try again in a moment.');
      return;
    }
    setState(() {
      _validating = true;
      _validationError = null;
      _validatedCustomer = null;
    });
    try {
      // Anchor's customer-validation endpoint is product-scoped, not
      // biller-scoped — any product belonging to this provider works for
      // validating the meter; the actual plan is picked separately below.
      final customer = await _repo.validateCustomer(
        productSlug: _products.first.slug,
        accountNumber: meter,
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
    if (provider == null || product == null) {
      AppToast.error('Pick a provider and product.');
      return;
    }
    if (customer == null) {
      AppToast.error('Validate the meter number first.');
      return;
    }
    if (phone.length < 10) {
      AppToast.error('Enter a valid phone number.');
      return;
    }
    final money = Money.tryParseMajor(_amountController.text.trim(), 'NGN');
    if (money == null || money.amountMinor < 10000) {
      AppToast.error('Minimum amount is ₦100.');
      return;
    }

    context.pushNamed(
      'bill-confirm',
      extra: {
        'kind': 'electricity',
        'provider': provider.slug,
        'provider_name': provider.name,
        'biller_code': provider.billerCode ?? provider.slug,
        'product_slug': product.slug,
        'product_name': product.name,
        'meter_account_number': _meterController.text.trim(),
        'phone_number': phone,
        'amount_minor': money.amountMinor,
        'customer_name': customer.customerName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final hasWalletBalance = authState is AuthAuthenticated
        ? authState.user.hasWalletBalance
        : false;
    final canContinue = _selectedProvider != null &&
        _selectedProduct != null &&
        _validatedCustomer != null &&
        hasWalletBalance;

    return Scaffold(
      appBar: AppBar(title: const Text('Electricity'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasWalletBalance) ...[
                const WalletFundingRequiredBanner(
                  message:
                      'You need a funded Communal wallet to pay for '
                      'electricity. Fund your wallet to continue.',
                ),
              ],
              _buildProviderPicker(),
              vSpace(20),
              _label('Meter type'),
              vSpace(8),
              _buildProductChips(),
              vSpace(20),
              _label('Meter / account number'),
              vSpace(8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _meterController,
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
                      decoration: billInputDecoration(context, 'e.g. 04042404048'),
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
              vSpace(20),
              _label('Amount (₦)'),
              vSpace(8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: billInputDecoration(context, 'e.g. 5000'),
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
        _label('Disco'),
        vSpace(8),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            for (final p in _providers)
              BillBrandChip(
                label: p.name,
                selected: _selectedProvider?.id == p.id,
                accent: const Color(0xFFFFB627),
                onTap: () => _onProviderChanged(p),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductChips() {
    if (_loadingProducts) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: SizedBox(
          width: 18.w,
          height: 18.w,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_productsError != null) {
      return Text(_productsError!, style: TextStyle(color: Colors.red.shade700));
    }
    if (_products.isEmpty) {
      return Text(
        'No meter types available for this disco.',
        style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
      );
    }
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: [
        for (final p in _products)
          BillBrandChip(
            label: p.name,
            selected: _selectedProduct?.id == p.id,
            accent: const Color(0xFFFFB627),
            onTap: () => setState(() => _selectedProduct = p),
          ),
      ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.customerName,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (c.address != null && c.address!.isNotEmpty)
                  Text(
                    c.address!,
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
                  ),
              ],
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

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/utils/tier_limit_check.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class TransferInternalAmountScreen extends StatefulWidget {
  const TransferInternalAmountScreen({super.key, required this.recipient});

  final TransferFavorite recipient;

  @override
  State<TransferInternalAmountScreen> createState() =>
      _TransferInternalAmountScreenState();
}

class _TransferInternalAmountScreenState
    extends State<TransferInternalAmountScreen> {
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  bool _saveAsFavorite = false;
  // Audit M26: pulled from `AppConstants.defaultQuickAmounts` so a
  // future server-driven swap is a single-line change.
  static const List<int> _quickAmounts = AppConstants.defaultQuickAmounts;

  String _formatThousand(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      b.write(s[i]);
      if (pos > 1 && pos % 3 == 1) b.write(',');
    }
    return b.toString();
  }

  void _applyQuickAmount(int amount) {
    _amountCtrl.text = _formatThousand(amount);
    setState(() {});
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  /// Parse the typed major-unit amount into integer minor units of [currency].
  /// Returns null when input is empty / non-numeric / non-positive.
  int? _amountToMinor(String value, String currency) {
    final money = Money.tryParseMajor(value, currency);
    if (money == null || money.amountMinor <= 0) return null;
    return money.amountMinor;
  }

  Future<void> _submit() async {
    final auth = context.read<AuthBloc>().state;
    final currency = auth is AuthAuthenticated
        ? resolveCurrencyCode(auth.user)
        : 'NGN';
    final amountMinor = _amountToMinor(_amountCtrl.text, currency);
    if (amountMinor == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter valid amount.')));
      return;
    }

    // Audit M21: bail before navigating if the amount can't possibly
    // succeed given the user's tier (KYC not done, or amount > daily
    // cap). Saves a wasted round-trip and gives the user a clearer
    // message than the backend's generic 4xx.
    if (auth is AuthAuthenticated) {
      final tierError = checkTransferAgainstTierLimits(
        user: auth.user,
        amountMinor: amountMinor,
        currency: currency,
      );
      if (tierError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tierError)));
        return;
      }
    }

    if (!mounted) return;
    // ignore: unawaited_futures
    context.pushNamed(
      'transfer-internal-review',
      extra: {
        'favorite': widget.recipient.toJson(),
        'amountMinor': amountMinor,
        'currency': currency,
        'narration': _narrationCtrl.text.trim(),
        'saveAsBeneficiary': _saveAsFavorite,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final isOnline = context.watch<ConnectivityCubit>().isConnected;
    final currencySymbol = auth is AuthAuthenticated
        ? currencySymbolForUser(auth.user)
        : currencySymbolForCode('NGN');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Transfer to Communal Account'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF8C66F5), Color(0xFF6A39F3)],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: const Color(0xFF8F6BFF),
                    child: Text(
                      (() {
                        final parts = widget.recipient.accountName
                            .trim()
                            .split(RegExp(r'\s+'))
                            .where((e) => e.isNotEmpty)
                            .toList();
                        if (parts.isEmpty) return 'U';
                        if (parts.length == 1) {
                          final s = parts.first;
                          return (s.length >= 2 ? s.substring(0, 2) : s)
                              .toUpperCase();
                        }
                        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
                      })(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  hSpace(10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.recipient.accountName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 19.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.recipient.accountNumber,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            vSpace(14),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  vSpace(6),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                      _ThousandsSeparatorInputFormatter(),
                    ],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  vSpace(10),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      // Quick amounts panel surface — sits inside the
                      // amount card, so use the slightly raised
                      // surfaceContainerHighest token for visible
                      // separation in both themes.
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: _quickAmounts
                          .map(
                            (v) => InkWell(
                              onTap: () => _applyQuickAmount(v),
                              borderRadius: BorderRadius.circular(16.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                child: Text(
                                  '$currencySymbol${v >= 1000 ? '${(v ~/ 1000)}k' : v}',
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  vSpace(12),
                  Text(
                    'Naration',
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  vSpace(6),
                  TextField(
                    controller: _narrationCtrl,
                    decoration: InputDecoration(
                      hintText: 'Enter transfer narration',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            vSpace(8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Save as favourite'),
              trailing: Transform.scale(
                scale: 0.82,
                child: Switch(
                  value: _saveAsFavorite,
                  onChanged: (v) => setState(() => _saveAsFavorite = v),
                ),
              ),
            ),
            vSpace(12),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
        child: SizedBox(
          width: double.infinity,
          height: 50.h,
          child: Opacity(
            opacity: isOnline ? 1.0 : 0.5,
            child: InkWell(
            onTap: isOnline ? _submit : null,
            borderRadius: BorderRadius.circular(12.r),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF8C66F5), Color(0xFF6A39F3)],
                ),
              ),
              child: Center(
                child: Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final chars = digits.split('').reversed.toList();
    final out = <String>[];
    for (int i = 0; i < chars.length; i++) {
      out.add(chars[i]);
      if ((i + 1) % 3 == 0 && i != chars.length - 1) out.add(',');
    }
    final formatted = out.reversed.join();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

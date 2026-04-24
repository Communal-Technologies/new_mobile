import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class TransferExternalScreen extends StatefulWidget {
  const TransferExternalScreen({super.key, this.initialRecipient});

  final TransferFavorite? initialRecipient;

  @override
  State<TransferExternalScreen> createState() => _TransferExternalScreenState();
}

class _TransferExternalScreenState extends State<TransferExternalScreen> {
  final _repo = getIt<TransferRepository>();
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  final _favorites = getIt<TransferFavoritesPrefs>();
  List<TransferSuggestion> _external = const [];
  TransferSuggestion? _selected;
  bool _loading = false;
  bool _submitting = false;
  bool _saveAsFavorite = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecipient;
    if (initial != null) {
      _selected = TransferSuggestion(
        source: initial.source,
        accountId: initial.accountId,
        bank: initial.bank,
        cooperativeName: '',
        accountNumber: initial.accountNumber,
        accountName: initial.accountName,
        nipCode: initial.nipCode,
      );
    }
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? q}) async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.fetchBankSuggestions(query: q);
      if (!mounted) return;
      setState(() => _external = rows.where((e) => e.isExternal).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _kobo() {
    final n = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (n == null || n <= 0) return null;
    return (n * 100).round();
  }

  Future<String?> _pin() async {
    final c = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm transfer'),
        content: TextField(
          controller: c,
          maxLength: 6,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Security PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    c.dispose();
    return pin;
  }

  Future<void> _submit() async {
    final s = _selected;
    final amountKobo = _kobo();
    if (s == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select recipient first.')));
      return;
    }
    if (amountKobo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter valid amount.')));
      return;
    }
    final bankCode = (s.nipCode ?? '').trim();
    if (bankCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipient bank code missing.')),
      );
      return;
    }
    final pin = await _pin();
    if (pin == null || pin.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await _repo.verifySecurityPin(pin);
      await _repo.verifyAccount(
        bankCode: bankCode,
        accountNumber: s.accountNumber,
      );
      final cpId = await _repo.createCounterParty(
        bankCode: bankCode,
        accountNumber: s.accountNumber,
        accountName: s.accountName,
      );
      final result = await _repo.initiateTransfer(
        type: 'NIPTransfer',
        amountKobo: amountKobo,
        narration: _narrationCtrl.text.trim().isEmpty
            ? 'Transfer'
            : _narrationCtrl.text.trim(),
        counterPartyId: cpId,
      );
      if (_saveAsFavorite) {
        await _favorites.upsert(
          TransferFavorite(
            source: 'external',
            accountId: cpId,
            bank: s.bank,
            accountNumber: s.accountNumber,
            accountName: s.accountName,
            nipCode: bankCode,
          ),
        );
      }
      if (!mounted) return;
      context.pushNamed(
        'transaction-receipt',
        extra: {
          'details': TransactionDetailsData(
            id: result.transferId,
            counterpartyName: s.accountName,
            counterpartyBank: s.bank,
            counterpartyAccount: s.accountNumber,
            amount: amountKobo / 100,
            currencySymbol: '₦',
            transactionType: 'NIP Transfer',
            dateTime: DateTime.now(),
            sessionId: result.transferId,
            reference: result.reference,
            description: _narrationCtrl.text.trim(),
            paymentMethod: 'Wallet',
            fees: 0,
            isIncoming: false,
            status: TransactionStatus.pending,
          ),
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(titleSpacing: 0, title: const Text('To Other Banks')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: _searchCtrl,
              hintText: 'Search beneficiary',
              onChanged: (v) => _load(q: v),
            ),
            vSpace(10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: _external.take(8).map((s) {
                    final selected = _selected?.accountId == s.accountId;
                    return ListTile(
                      onTap: () => setState(() => _selected = s),
                      title: Text(s.accountName),
                      subtitle: Text('${s.bank} • ${s.accountNumber}'),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
            vSpace(12),
            CustomTextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              hintText: 'Amount (NGN)',
            ),
            vSpace(12),
            CustomTextField(
              controller: _narrationCtrl,
              hintText: 'Narration (optional)',
            ),
            vSpace(8),
            SwitchListTile(
              value: _saveAsFavorite,
              onChanged: (v) => setState(() => _saveAsFavorite = v),
              title: const Text('Save as favourite'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            vSpace(20),
            AppElevatedButton(
              title: 'Continue',
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

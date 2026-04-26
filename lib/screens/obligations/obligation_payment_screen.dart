import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/core/utils/money_formatter.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/obligations/data/sample_obligations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class ObligationPaymentScreen extends StatefulWidget {
  const ObligationPaymentScreen({super.key, required this.obligation});

  final Obligation obligation;

  @override
  State<ObligationPaymentScreen> createState() =>
      _ObligationPaymentScreenState();
}

class _ObligationPaymentScreenState extends State<ObligationPaymentScreen> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();

  final MemberObligationsRepository _obligationsRepo =
      MemberObligationsRepository(getIt());
  List<CooperativeCashBankAccount> _cashRepos = const [];
  bool _loadingCashRepos = true;
  CooperativeCashBankAccount? _selectedCashRepo;
  String? _cashRepoError;

  static const int _noteLimit = 100;

  Widget _buildNipTransferInfo(AuthState auth) {
    final walletLine = auth is AuthAuthenticated
        ? '${currencySymbolForUser(auth.user)}${formatMoney(auth.user.walletBalanceKobo / 100)}'
        : '—';
    final hasRepo = _cashRepos.isNotEmpty;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: hasRepo ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: hasRepo ? const Color(0xFF7434FF) : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: const Color(0xFF5B8DFF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Iconsax.building,
              color: const Color(0xFF5B8DFF),
              size: 22.sp,
            ),
          ),
          hSpace(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer (NIP)',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                vSpace(4),
                Text(
                  hasRepo
                      ? 'Payment is sent from your Communal account to your cooperative’s bank account. Anchor settles this as an outbound NIP transfer.'
                      : 'Your cooperative has not published an active bank account to receive this payment yet.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                vSpace(6),
                Text(
                  'Available in Communal: $walletLine',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.obligation.perInstallment.round().toString(),
    );
    _noteController.addListener(() => setState(() {}));
    _loadCashRepos();
  }

  Future<void> _loadCashRepos() async {
    setState(() {
      _loadingCashRepos = true;
      _cashRepoError = null;
    });
    try {
      final rows = await _obligationsRepo.fetchCooperativeCashBankAccounts();
      if (!mounted) return;
      setState(() {
        _cashRepos = rows;
        _selectedCashRepo = rows.length == 1 ? rows.first : null;
        _loadingCashRepos = false;
      });
    } catch (e) {
      if (!mounted) return;
      var msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      if (msg.isEmpty) {
        msg =
            'Unable to load cooperative bank accounts. Please try again or contact your cooperative administrator.';
      }
      setState(() {
        _cashRepos = const [];
        _selectedCashRepo = null;
        _loadingCashRepos = false;
        _cashRepoError = msg;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = formatMoney(widget.obligation.balance);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        final bankSubtitleExtra = _loadingCashRepos
            ? 'Loading cooperative accounts…'
            : (_cashRepoError ?? '');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Make Payment',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewCard(outstanding),
              vSpace(24),
              _buildAmountInput(),
              vSpace(4),
              Text(
                'Suggested: ₦${formatMoney(widget.obligation.perInstallment)}',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
              ),
              vSpace(24),
              Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              if (bankSubtitleExtra.isNotEmpty) ...[
                vSpace(6),
                Text(
                  bankSubtitleExtra,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                ),
              ],
              vSpace(12),
              _buildNipTransferInfo(auth),
              if (_cashRepos.length > 1) ...[
                vSpace(12),
                Text(
                  'Cooperative account',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                vSpace(8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CooperativeCashBankAccount>(
                      isExpanded: true,
                      value: _selectedCashRepo,
                      hint: const Text('Select account'),
                      items: _cashRepos
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                '${e.accountName} • ${e.accountNumber}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCashRepo = v),
                    ),
                  ),
                ),
              ] else if (_cashRepos.length == 1) ...[
                vSpace(10),
                Text(
                  'Paying into: ${_cashRepos.first.accountName} • ${_cashRepos.first.accountNumber}',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
                ),
              ],
              vSpace(24),
              Text(
                'Narration (Optional)',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              vSpace(10),
              _buildNarrationField(),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
            child: ElevatedButton(
              onPressed: _onContinue,
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
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildOverviewCard(String outstanding) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paying for',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
          ),
          vSpace(6),
          Text(
            widget.obligation.title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          Text(
            'Total Lenders Forum',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
          ),
          vSpace(16),
          Divider(color: Colors.grey.shade200),
          vSpace(12),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'Installment Amount',
                  value:
                      '₦${formatMoney(widget.obligation.perInstallment)}',
                ),
              ),
              Expanded(
                child: _MetricBlock(
                  label: 'Outstanding Balance',
                  value: '₦$outstanding',
                  alignRight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount to Pay',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        vSpace(10),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            prefixText: '₦ ',
            hintText: '50000',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: Color(0xFF7434FF), width: 2),
            ),
          ),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrationField() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: _noteLimit,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Add a note for this payment...',
              counterText: '',
            ),
            style: TextStyle(fontSize: 14.sp),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_noteController.text.length}/$_noteLimit',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  void _onContinue() {
    final amount =
        double.tryParse(_amountController.text) ??
        widget.obligation.perInstallment;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount to continue.')),
      );
      return;
    }

    if (_cashRepos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cooperative bank account is available for this payment.'),
        ),
      );
      return;
    }

    final CooperativeCashBankAccount? cash =
        _cashRepos.length == 1 ? _cashRepos.first : _selectedCashRepo;
    if (cash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the cooperative account to pay into.')),
      );
      return;
    }

    context.pushNamed(
      'obligation-confirm-payment',
      extra: {
        'obligation': widget.obligation,
        'amount': amount,
        'method': 'NIP transfer',
        'cash_account': cash.toJson(),
        'cash_repository_id': cash.id,
      },
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  final String label;
  final String value;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final alignment = alignRight
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
        ),
        vSpace(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

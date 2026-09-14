import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/ng_mobile_network.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/local/bill_recipient_prefs.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_inputs.dart';

/// The phone number a bill is bought for, or its receipt is sent to.
///
/// Starts on the member's own number, offers the last three other numbers this
/// member paid for underneath it, and names the network as soon as the prefix is
/// in — four digits, well before the number is complete.
class BillPhoneField extends StatefulWidget {
  const BillPhoneField({
    super.key,
    required this.controller,
    this.onNetworkChanged,
    this.accent = const Color(0xFF7434FF),
  });

  final TextEditingController controller;
  final ValueChanged<NgMobileNetwork?>? onNetworkChanged;
  final Color accent;

  /// Adds [phone] to this member's recent numbers, unless it is their own.
  static Future<void> remember(BuildContext context, String phone) async {
    final member = _member(context);
    if (member == null) return;
    final prefs = await BillRecipientPrefs.load(member.id);
    await prefs.remember(phone, ownPhone: member.phone);
  }

  static ({String id, String? phone})? _member(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return null;
    final phone = ngLocalPhone(state.user.phone ?? '');
    return (id: state.user.id, phone: phone.length == 11 ? phone : null);
  }

  @override
  State<BillPhoneField> createState() => _BillPhoneFieldState();
}

class _BillPhoneFieldState extends State<BillPhoneField> {
  String _userId = '';
  String? _own;
  List<String> _recent = const [];
  NgMobileNetwork? _network;

  @override
  void initState() {
    super.initState();
    final member = BillPhoneField._member(context);
    _userId = member?.id ?? '';
    _own = member?.phone;
    if (widget.controller.text.trim().isEmpty && _own != null) {
      widget.controller.text = _own!;
    }
    widget.controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChanged());
    _loadRecent();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _loadRecent() async {
    if (_userId.isEmpty) return;
    final prefs = await BillRecipientPrefs.load(_userId);
    if (!mounted) return;
    setState(() => _recent = prefs.recentPhones(ownPhone: _own));
  }

  void _onChanged() {
    if (!mounted) return;
    final network = detectNgMobileNetwork(widget.controller.text);
    final changed = network != _network;
    setState(() => _network = network);
    if (changed) widget.onNetworkChanged?.call(network);
  }

  void _pick(String phone) {
    widget.controller.value = TextEditingValue(
      text: phone,
      selection: TextSelection.collapsed(offset: phone.length),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ngLocalPhone(widget.controller.text);
    final options = [if (_own != null) _own!, ..._recent];
    final network = _network;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            LengthLimitingTextInputFormatter(14),
          ],
          decoration: billInputDecoration(context, 'e.g. 08012345678').copyWith(
            suffixIconConstraints: const BoxConstraints(),
            suffixIcon: network == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(right: 12.w),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        network.label,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: widget.accent,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (options.isNotEmpty) ...[
          vSpace(10),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final phone in options)
                ChoiceChip(
                  showCheckmark: false,
                  selected: current == phone,
                  selectedColor: widget.accent.withValues(alpha: 0.16),
                  side: BorderSide(
                    color: current == phone
                        ? widget.accent
                        : theme.dividerColor,
                  ),
                  label: Text(
                    phone == _own ? 'My number · $phone' : phone,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  onSelected: (_) => _pick(phone),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

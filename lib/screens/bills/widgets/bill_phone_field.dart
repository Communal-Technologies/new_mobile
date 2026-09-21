import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/ng_mobile_network.dart';
import 'package:communal_mobile/data/local/bill_recipient_prefs.dart';
import 'package:communal_mobile/screens/bills/widgets/bill_inputs.dart';

/// The phone number a bill is bought for, or its receipt is sent to.
///
/// Starts on the member's own number, opens the last three other numbers this
/// member paid for as a dropdown on the field itself, and names the network as
/// soon as the prefix is in — four digits, well before the number is complete.
class BillPhoneField extends StatefulWidget {
  const BillPhoneField({
    super.key,
    required this.controller,
    this.onNetworkChanged,
    this.accent = const Color(0xFF7434FF),
    this.showRecents = true,
  });

  final TextEditingController controller;
  final ValueChanged<NgMobileNetwork?>? onNetworkChanged;
  final Color accent;

  /// Airtime and data are bought for a number, so the numbers this member has
  /// bought for before are worth offering. A meter or a smartcard is the
  /// recipient on the other screens — the number there is only where the token
  /// or receipt goes, so they start on the member's own number and offer none.
  final bool showRecents;

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
  final GlobalKey _fieldKey = GlobalKey();

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
    if (_userId.isEmpty || !widget.showRecents) return;
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

  Future<void> _openOptions(List<String> options) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final current = ngLocalPhone(widget.controller.text);
    final theme = Theme.of(context);

    final picked = await showMenu<String>(
      context: context,
      constraints: BoxConstraints.tightFor(width: box.size.width),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy + box.size.height + 4.h,
        overlay.size.width - topLeft.dx - box.size.width,
        0,
      ),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
        side: BorderSide(color: theme.dividerColor),
      ),
      items: [
        for (final phone in options)
          PopupMenuItem<String>(
            value: phone,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: current == phone
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (phone == _own)
                        Text(
                          'My number',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (detectNgMobileNetwork(phone) case final network?)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      network.label,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: widget.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    if (picked != null) _pick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.showRecents
        ? [if (_own != null) _own!, ..._recent]
        : const <String>[];
    final network = _network;

    return TextField(
      key: _fieldKey,
      controller: widget.controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
        LengthLimitingTextInputFormatter(14),
      ],
      decoration: billInputDecoration(context, 'e.g. 08012345678').copyWith(
        suffixIconConstraints: const BoxConstraints(),
        suffixIcon: (network == null && options.isEmpty)
            ? null
            : Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (network != null)
                      Container(
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
                    if (options.isNotEmpty)
                      IconButton(
                        tooltip: 'Recent numbers',
                        onPressed: () => _openOptions(options),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          size: 24.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

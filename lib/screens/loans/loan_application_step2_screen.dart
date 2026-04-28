import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/member_search_result.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/loans/data/loan_application_draft.dart';

/// Step 2 of the apply flow: pick `scheme.numberOfGuarantors` members
/// via typeahead. The dropdown is hidden when the input is empty — it
/// only appears once the user starts typing.
class LoanApplicationStep2Screen extends StatefulWidget {
  const LoanApplicationStep2Screen({super.key, required this.draft});

  final LoanApplicationDraft draft;

  @override
  State<LoanApplicationStep2Screen> createState() =>
      _LoanApplicationStep2ScreenState();
}

class _LoanApplicationStep2ScreenState
    extends State<LoanApplicationStep2Screen> {
  final LoanRepository _repo = LoanRepository(getIt());
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final LayerLink _searchLink = LayerLink();
  OverlayEntry? _overlay;

  Timer? _debounce;
  bool _searching = false;
  String? _searchError;
  List<MemberSearchResult> _results = const [];

  /// Selected guarantors. Length is clamped to scheme.numberOfGuarantors.
  final List<MemberSearchResult> _selected = [];

  int get _required => widget.draft.scheme.numberOfGuarantors;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.draft.guarantors);
    _searchController.addListener(_onQueryChanged);
    _searchFocus.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _hideOverlay();
    _debounce?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchFocus.removeListener(_handleFocus);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _handleFocus() {
    // No dropdown on focus alone — only after the user types something.
    if (!_searchFocus.hasFocus) {
      _hideOverlay();
    } else if (_searchController.text.trim().isNotEmpty &&
        (_results.isNotEmpty || _searching || _searchError != null)) {
      _showOverlay();
    }
  }

  void _onQueryChanged() {
    final raw = _searchController.text.trim();
    _debounce?.cancel();
    if (raw.isEmpty) {
      setState(() {
        _results = const [];
        _searchError = null;
        _searching = false;
      });
      _hideOverlay();
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _runSearch(raw);
    });
  }

  Future<void> _runSearch(String q) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    final coopId = auth.user.cooperativeId?.trim();
    if (coopId == null || coopId.isEmpty) {
      setState(() {
        _searching = false;
        _searchError = 'Cooperative not linked to your profile';
      });
      _showOverlay();
      return;
    }
    try {
      final list = await _repo.searchGuarantors(
        cooperativeId: coopId,
        query: q,
      );
      if (!mounted) return;
      // Don't display stale results if the user has since typed more.
      if (_searchController.text.trim() != q) return;
      setState(() {
        _results = list
            .where((m) => !_selected.any((s) => s.ledgerNumber == m.ledgerNumber))
            .toList(growable: false);
        _searching = false;
        _searchError = null;
      });
      if (_searchFocus.hasFocus) _showOverlay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.toString().replaceFirst('Exception: ', '');
        _results = const [];
      });
      if (_searchFocus.hasFocus) _showOverlay();
    }
  }

  void _addGuarantor(MemberSearchResult m) {
    if (_selected.length >= _required) return;
    if (_selected.any((s) => s.ledgerNumber == m.ledgerNumber)) return;
    setState(() {
      _selected.add(m);
      _results = _results
          .where((r) => r.ledgerNumber != m.ledgerNumber)
          .toList(growable: false);
      _searchController.clear();
    });
    _hideOverlay();
    _searchFocus.unfocus();
  }

  void _removeGuarantor(MemberSearchResult m) {
    setState(() {
      _selected.removeWhere((s) => s.ledgerNumber == m.ledgerNumber);
    });
  }

  void _showOverlay() {
    _hideOverlay();
    final overlayState = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          width: renderBox.size.width - 32.w,
          child: CompositedTransformFollower(
            link: _searchLink,
            showWhenUnlinked: false,
            offset: Offset(0, 56.h),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12.r),
              child: _buildSearchDropdown(),
            ),
          ),
        );
      },
    );
    _overlay = entry;
    overlayState.insert(entry);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildSearchDropdown() {
    Widget child;
    if (_searching) {
      child = Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (_searchError != null) {
      child = Padding(
        padding: EdgeInsets.all(12.w),
        child: Text(
          _searchError!,
          style: TextStyle(
            fontSize: 13.sp,
            color: const Color(0xFFE74C3C),
          ),
        ),
      );
    } else if (_results.isEmpty) {
      child = Padding(
        padding: EdgeInsets.all(12.w),
        child: Text(
          'No matching members in your cooperative',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
        ),
      );
    } else {
      child = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 280.h),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _results.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: (_, i) {
            final m = _results[i];
            return InkWell(
              onTap: () => _addGuarantor(m),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16.r,
                      backgroundColor: const Color(0xFFEEE5FF),
                      child: Text(
                        m.initials,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7434FF),
                        ),
                      ),
                    ),
                    hSpace(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F1D40),
                            ),
                          ),
                          vSpace(2),
                          Text(
                            m.ledgerNumber,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.add_circle_outline,
                        size: 18.sp, color: const Color(0xFF7434FF)),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _required == 0 || _selected.length == _required;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              _hideOverlay();
              context.pop();
            },
          ),
          title: Text(
            'Loan Application',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: Text(
                  'Step 2 of 3',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7434FF),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _searchFocus.unfocus();
                  _hideOverlay();
                },
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProgressIndicator(),
                      vSpace(24),
                      _buildInfoCard(),
                      vSpace(24),
                      if (_required == 0)
                        _buildNoGuarantorsCard()
                      else ...[
                        _buildSearchField(),
                        vSpace(16),
                        _buildSelectedList(),
                      ],
                      vSpace(24),
                      _buildNotificationCard(),
                      vSpace(24),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(child: _buildNavigationButtons(canContinue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Choose Guarantors',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7434FF),
            ),
          ),
        ),
        vSpace(8),
        Stack(
          children: [
            Container(
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 2 / 3,
              child: Container(
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF7434FF),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final n = _required;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: const BoxDecoration(
              color: Color(0xFF1976D2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline, color: Colors.white, size: 20.sp),
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n == 0
                      ? 'No guarantors required'
                      : 'Select $n guarantor${n == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
                vSpace(4),
                Text(
                  n == 0
                      ? 'This product is unsecured. You can continue.'
                      : 'Search by name or ledger number — only members of your cooperative show up.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoGuarantorsCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        'This loan product does not require any guarantors. Tap Continue to review.',
        style: TextStyle(fontSize: 14.sp, color: const Color(0xFF0F1D40)),
      ),
    );
  }

  Widget _buildSearchField() {
    final remaining = _required - _selected.length;
    final disabled = remaining <= 0;
    return CompositedTransformTarget(
      link: _searchLink,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        enabled: !disabled,
        style: TextStyle(fontSize: 14.sp, color: const Color(0xFF0F1D40)),
        decoration: InputDecoration(
          hintText: disabled
              ? 'All guarantors picked'
              : 'Search by name or ledger number',
          hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF7434FF)),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _hideOverlay();
                  },
                ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: Color(0xFF7434FF), width: 2),
          ),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        ),
      ),
    );
  }

  Widget _buildSelectedList() {
    if (_selected.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Text(
          'No guarantors selected yet — pick ${_required - _selected.length} to continue.',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected (${_selected.length}/$_required)',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(8),
        ..._selected.map(
          (m) => Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding:
                EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E9),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: const Color(0xFFFFD2B0).withOpacity(0.6),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: const Color(0xFFE67E22),
                  child: Text(
                    m.initials,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                hSpace(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F1D40),
                        ),
                      ),
                      vSpace(2),
                      Text(
                        m.ledgerNumber,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => _removeGuarantor(m),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard() {
    if (_required == 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              color: const Color(0xFF4CAF50), size: 20.sp),
          hSpace(12),
          Expanded(
            child: Text(
              'Your guarantor${_required == 1 ? '' : 's'} will be notified to approve your loan request.',
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool canContinue) {
    return Row(
      children: [
        SizedBox(
          width: 100.w,
          child: OutlinedButton(
            onPressed: () {
              _hideOverlay();
              context.pop();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(vertical: 16.h),
            ),
            child: Text(
              'Back',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F1D40),
              ),
            ),
          ),
        ),
        hSpace(12),
        Expanded(
          child: ElevatedButton(
            onPressed: canContinue
                ? () {
                    _hideOverlay();
                    final next = widget.draft.copyWith(guarantors: _selected);
                    context.pushNamed(
                      'loan-application-step3',
                      extra: {'draft': next},
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7434FF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(vertical: 16.h),
            ),
            child: Text(
              'Continue',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

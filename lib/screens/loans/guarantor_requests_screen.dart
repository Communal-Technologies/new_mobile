import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/guarantor_request.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/injection.dart';

/// Inbox of incoming "stand as guarantor" requests for the logged-in
/// member. Each row pairs an applicant + amount with accept/decline
/// actions. Backed by the existing
/// `members/loan/fetch-approval-requests/{ledger}` endpoint.
class GuarantorRequestsScreen extends StatefulWidget {
  const GuarantorRequestsScreen({super.key});

  @override
  State<GuarantorRequestsScreen> createState() =>
      _GuarantorRequestsScreenState();
}

class _GuarantorRequestsScreenState extends State<GuarantorRequestsScreen> {
  final LoanRepository _repo = LoanRepository(getIt());
  bool _loading = false;
  String? _error;
  List<GuarantorRequest> _requests = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.fetchGuarantorRequests(auth.user);
      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Guarantor Requests',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          vSpace(40),
          Icon(
            Icons.error_outline,
            size: 32.sp,
            color: const Color(0xFFE74C3C),
          ),
          vSpace(8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17.sp, color: const Color(0xFFE74C3C)),
          ),
          vSpace(12),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Try again')),
          ),
        ],
      );
    }
    if (_requests.isEmpty) {
      return ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          vSpace(80),
          Icon(
            Icons.handshake_outlined,
            size: 48.sp,
            color: Colors.grey.shade400,
          ),
          vSpace(16),
          Text(
            'No guarantor requests',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(8),
          Text(
            'When a fellow member asks you to stand as guarantor for their loan, the request will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17.sp, color: Colors.grey.shade600),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => vSpace(12),
      itemBuilder: (_, i) => _requestCard(_requests[i]),
    );
  }

  Widget _requestCard(GuarantorRequest req) {
    // The card is now a navigation entry into the detail screen
    // (which carries the loan details, risk disclosure, and the
    // acknowledgement gate before the Accept button enables). Inline
    // accept/decline removed so a member can't approve without
    // reading what they're signing up for.
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () async {
        final result = await context.pushNamed<bool>(
          'guarantor-request-detail',
          extra: req,
        );
        if (result == true) {
          // Detail screen reports back when the request was actioned;
          // refresh the inbox so the row picks up the new status.
          await _load();
        }
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: const Color(0xFFEEE5FF),
                  child: Icon(
                    Icons.person,
                    size: 20.sp,
                    color: const Color(0xFF7434FF),
                  ),
                ),
                hSpace(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.applicantName.isNotEmpty
                            ? req.applicantName
                            : 'Member',
                        style: TextStyle(
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      vSpace(2),
                      Text(
                        'Asked you to guarantor • ${req.createdAtLabel}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(req),
              ],
            ),
            vSpace(12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16.sp,
                    color: const Color(0xFF7434FF),
                  ),
                  hSpace(6),
                  Text(
                    'Loan amount',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    req.amountLabel,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (req.isPending) ...[
              vSpace(12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap to review',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7434FF),
                    ),
                  ),
                  hSpace(4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16.sp,
                    color: const Color(0xFF7434FF),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(GuarantorRequest req) {
    Color bg;
    Color fg;
    if (req.isPending) {
      bg = const Color(0xFFFFF4E9);
      fg = const Color(0xFFE67E22);
    } else if (req.isAccepted) {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    } else {
      bg = const Color(0xFFFDECEA);
      fg = const Color(0xFFE74C3C);
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        req.statusLabel,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

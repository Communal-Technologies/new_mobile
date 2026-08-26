import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/support_models.dart';
import 'package:communal_mobile/data/repositories/support_repository.dart';
import 'package:communal_mobile/injection.dart';

const Color _brand = Color(0xFF7434FF);

/// Everything this member has asked us, newest first.
///
/// The unread badge is the count of messages written since they last opened the
/// thread, which is the only way an operator's reply is visible without opening
/// each conversation in turn.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  late Future<SupportTicketsResult> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<SupportRepository>().tickets();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = getIt<SupportRepository>().tickets();
    });
    await _future;
  }

  Future<void> _open(SupportTicket ticket) async {
    await context.pushNamed(
      'support-chat',
      extra: <String, dynamic>{
        'ticketId': ticket.id,
        'categoryTitle': ticket.subject.isEmpty
            ? supportCategoryLabel(ticket.category)
            : ticket.subject,
      },
    );
    // Coming back from a thread clears its unread count server-side, so the
    // list has to be re-read or the badge lies.
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(theme),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor,
          elevation: 0,
          systemOverlayStyle: systemOverlayForTheme(theme),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'My Requests',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: FutureBuilder<SupportTicketsResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _errorState(theme, snapshot.error!);
            }
            final tickets = snapshot.data?.tickets ?? const <SupportTicket>[];
            if (tickets.isEmpty) return _emptyState(theme);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                itemCount: tickets.length,
                itemBuilder: (context, index) => _row(theme, tickets[index]),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          onPressed: () async {
            await context.pushNamed(
              'support-chat',
              extra: const <String, dynamic>{
                'category': SupportCategory.other,
                'categoryTitle': 'New request',
              },
            );
            if (mounted) await _refresh();
          },
          icon: const Icon(Icons.add_comment_outlined),
          label: Text(
            'New request',
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, SupportTicket ticket) {
    final tone = _statusTone(ticket.status);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () => _open(ticket),
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: theme.dividerColor,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject.isEmpty
                          ? supportCategoryLabel(ticket.category)
                          : ticket.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (ticket.unread > 0) ...[
                    hSpace(8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: _brand,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        '${ticket.unread} new',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              vSpace(6),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      _statusLabel(ticket),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: tone,
                      ),
                    ),
                  ),
                  hSpace(8),
                  Expanded(
                    child: Text(
                      ticket.reference,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Text(
                    _when(ticket.lastMessageAt ?? ticket.createdAt),
                    style: TextStyle(
                      fontSize: 15.sp,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 64.h),
        children: [
          Icon(
            Icons.forum_outlined,
            size: 48.sp,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          vSpace(16),
          Text(
            'You have not asked us anything yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          vSpace(8),
          Text(
            'Anything you raise from Help & Support appears here, with our '
            'replies.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(ThemeData theme, Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 40.sp, color: Colors.red),
            vSpace(12),
            Text(
              error.toString().replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            vSpace(16),
            ElevatedButton(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The member's wording, not the service's. `bot` and `pending_requester` mean
/// nothing to someone waiting for an answer.
String _statusLabel(SupportTicket ticket) {
  switch (ticket.status) {
    case SupportTicketStatus.bot:
      return 'Assistant';
    case SupportTicketStatus.open:
      return ticket.assignedOperator == null ? 'With our team' : 'Being handled';
    case SupportTicketStatus.pendingRequester:
      return 'Waiting on you';
    case SupportTicketStatus.resolved:
      return 'Resolved';
    case SupportTicketStatus.closed:
      return 'Closed';
    default:
      return 'Open';
  }
}

Color _statusTone(String status) {
  switch (status) {
    case SupportTicketStatus.resolved:
      return const Color(0xFF2E7D32);
    case SupportTicketStatus.closed:
      return Colors.grey;
    case SupportTicketStatus.pendingRequester:
      return const Color(0xFFEF6C00);
    default:
      return _brand;
  }
}

String _when(DateTime? at) {
  if (at == null) return '';
  final now = DateTime.now();
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(at);
}

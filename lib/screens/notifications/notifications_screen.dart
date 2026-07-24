import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/core/services/push_notification_service.dart';
import 'package:communal_mobile/core/services/unread_notifications_service.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/notification_model.dart';
import 'package:communal_mobile/data/repositories/notifications_repository.dart';
import 'package:communal_mobile/injection.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<NotificationsResult> _future;
  bool _markingAll = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _future.whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<NotificationsResult> _load() {
    return getIt<NotificationsRepository>().fetch();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
      _loading = true;
    });
    try {
      await _future;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(NotificationModel n) async {
    if (!n.isUnread) return;
    try {
      await getIt<NotificationsRepository>().markAsRead(n.id);
      // Local-decrement first so the home bell drops the dot
      // immediately; refresh() reconciles to the authoritative count.
      getIt<UnreadNotificationsService>().decrement();
      unawaited(getIt<UnreadNotificationsService>().refresh());
      if (mounted) await _refresh();
    } catch (_) {
      // Silent: tap-to-read is a soft action; refresh on next pull.
    }
  }

  /// Marks the notification read, then — for actionable notifications
  /// carrying a deep-link payload — navigates to the relevant detail
  /// screen using the same resolver the push handler uses. Marking
  /// always runs first, even if navigation resolves to nothing.
  Future<void> _onTapNotification(NotificationModel n) async {
    await _markAsRead(n);
    final data = n.data;
    if (data == null || data.isEmpty) return;
    try {
      final intent = await PushNotificationService.resolveIntent(data);
      // 'notifications' is the resolver's fallback for non-actionable
      // payloads — no point navigating to the screen we're on.
      if (intent == null || intent.routeName == 'notifications') return;
      if (!mounted) return;
      context.goNamed(intent.routeName, extra: intent.extra);
    } catch (_) {
      // Navigation is best-effort; the row is already marked read.
    }
  }

  Future<void> _markAllAsRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await getIt<NotificationsRepository>().markAllAsRead();
      getIt<UnreadNotificationsService>().clear();
      unawaited(getIt<UnreadNotificationsService>().refresh());
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            actions: [
              FutureBuilder<NotificationsResult>(
                future: _future,
                builder: (context, snapshot) {
                  final unread = snapshot.data?.unreadCount ?? 0;
                  if (unread == 0) return const SizedBox.shrink();
                  return TextButton(
                    onPressed: _markingAll ? null : _markAllAsRead,
                    child: Text(
                      _markingAll ? 'Marking…' : 'Mark all read',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: const Color(0xFF7434FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<NotificationsResult>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Body stays empty — full-screen LoaderOverlay sits at
                  // the Stack level so it covers the AppBar too, matching
                  // the transactions-history pattern.
                  return const SizedBox.shrink();
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: snapshot.error.toString().replaceFirst(
                      'Exception: ',
                      '',
                    ),
                    onRetry: _refresh,
                  );
                }
                final items = snapshot.data?.notifications ?? const [];
                if (items.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: 120.h),
                      const _EmptyState(),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final n = items[index];
                    return _NotificationTile(
                      notification: n,
                      onTap: () => _onTapNotification(n),
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (_loading) const Positioned.fill(child: LoaderOverlay()),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    return Material(
      color: unread ? const Color(0xFFEFE9FF) : Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF7434FF).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF7434FF),
                ),
              ),
              hSpace(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 17.sp,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (notification.createdAt != null) ...[
                      vSpace(4),
                      Text(
                        DateFormat(
                          'MMM d, h:mm a',
                        ).format(notification.createdAt!),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 8.w,
                  height: 8.w,
                  margin: EdgeInsets.only(top: 6.h, left: 6.w),
                  decoration: const BoxDecoration(
                    color: Color(0xFF7434FF),
                    shape: BoxShape.circle,
                  ),
                ),
              if (notification.isActionable)
                Padding(
                  padding: EdgeInsets.only(left: 4.w, top: 2.h),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20.w,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            color: Color(0xFFB0B0C3),
            size: 48,
          ),
          vSpace(12),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 17.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB42318), size: 36),
            vSpace(12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            vSpace(12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

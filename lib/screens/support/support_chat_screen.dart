import 'dart:async';

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

/// One support conversation.
///
/// Opens in one of two ways. With a [ticketId] it loads an existing thread —
/// from the requests list, or a push tap. Without one it is a fresh conversation
/// seeded with a [category]: no ticket exists until the member actually says
/// something, so a tapped help card that is then backed out of leaves nothing
/// behind for an operator to triage.
///
/// The bot answers first and its reply arrives on the same round trip as the
/// send. From then on the thread is polled every four seconds while it is on
/// screen and not while the app is in the background — a support thread is not
/// worth a socket, and a timer that keeps firing behind a locked phone is just
/// battery.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({
    super.key,
    this.ticketId,
    this.category = SupportCategory.other,
    this.categoryTitle,
    this.openingMessage,
  });

  final String? ticketId;
  final String category;

  /// The help-grid card's own wording, used as the screen title and in the
  /// opening prompt so the conversation reads as a continuation of the tap.
  final String? categoryTitle;

  /// Pre-filled first message, e.g. a transaction reference the member came
  /// from. Not sent automatically — the member still presses send.
  final String? openingMessage;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen>
    with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 4);

  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<SupportMessage> _messages = [];

  SupportTicket? _ticket;
  String? _ticketId;
  Timer? _poll;
  int _seq = 0;
  bool _loading = false;
  bool _sending = false;
  bool _escalating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticketId = widget.ticketId;
    if (widget.openingMessage != null) {
      _composer.text = widget.openingMessage!;
    }
    if (_ticketId != null) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      // A reply may have landed while the app was away; catch up immediately
      // rather than after the first interval.
      unawaited(_pollOnce());
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  SupportRepository get _repo => getIt<SupportRepository>();

  void _startPolling() {
    _poll?.cancel();
    final ticket = _ticket;
    // Nothing to poll for on a thread nobody will write to again.
    if (_ticketId == null || (ticket != null && ticket.isFinished)) return;
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(_pollOnce()));
  }

  Future<void> _load() async {
    final id = _ticketId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final thread = await _repo.thread(id);
      if (!mounted) return;
      setState(() {
        _ticket = thread.ticket;
        _messages
          ..clear()
          ..addAll(thread.messages);
        _seq = _messages.isEmpty
            ? thread.ticket.messageSeq
            : _messages.last.seq;
        _loading = false;
      });
      _startPolling();
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(e);
      });
    }
  }

  Future<void> _pollOnce() async {
    final id = _ticketId;
    if (id == null || _sending) return;
    try {
      final result = await _repo.poll(id, _seq);
      if (!mounted) return;
      final fresh = result.messages
          .where((m) => !_messages.any((existing) => existing.id == m.id))
          .toList();
      final ticket = _ticket;
      setState(() {
        _messages.addAll(fresh);
        if (result.seq > _seq) _seq = result.seq;
        if (ticket != null) {
          _ticket = _withStatus(ticket, result.status, result.assignee);
        }
      });
      if (fresh.isNotEmpty) _scrollToEnd();
      if (_ticket?.isFinished ?? false) {
        _poll?.cancel();
        _poll = null;
      }
    } catch (_) {
      // A dropped poll is not worth telling the member about: the next tick
      // asks again from the same watermark, so nothing is lost.
    }
  }

  /// Rebuilds the local ticket with a status the poll reported. The list row and
  /// the header both read from it, and an escalation that happened server-side
  /// (the bot handing over mid-answer) only ever arrives this way.
  SupportTicket _withStatus(SupportTicket t, String status, String? assignee) =>
      SupportTicket(
        id: t.id,
        reference: t.reference,
        subject: t.subject,
        category: t.category,
        status: status.isEmpty ? t.status : status,
        priority: t.priority,
        channel: t.channel,
        unread: 0,
        messageSeq: _seq,
        assignedOperator: assignee ?? t.assignedOperator,
        escalatedAt: t.escalatedAt,
        resolvedAt: t.resolvedAt,
        closedAt: t.closedAt,
        csatScore: t.csatScore,
        lastMessageAt: t.lastMessageAt,
        createdAt: t.createdAt,
      );

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    _composer.clear();
    _scrollToEnd();

    try {
      if (_ticketId == null) {
        final thread = await _repo.createTicket(
          message: text,
          category: widget.category,
          subject: widget.categoryTitle ?? '',
        );
        if (!mounted) return;
        setState(() {
          _ticket = thread.ticket;
          _ticketId = thread.ticket.id;
          _messages
            ..clear()
            ..addAll(thread.messages);
          _seq = _messages.isEmpty
              ? thread.ticket.messageSeq
              : _messages.last.seq;
          _sending = false;
        });
        _startPolling();
      } else {
        final result = await _repo.sendMessage(_ticketId!, text);
        if (!mounted) return;
        final ticket = _ticket;
        setState(() {
          _messages.addAll(result.all);
          if (result.all.isNotEmpty) _seq = result.all.last.seq;
          if (ticket != null) {
            _ticket = _withStatus(ticket, result.status, ticket.assignedOperator);
          }
          _sending = false;
        });
      }
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        // Hand the text back rather than losing what they typed.
        _composer.text = text;
        _error = _clean(e);
      });
    }
  }

  Future<void> _escalate() async {
    final id = _ticketId;
    if (id == null || _escalating) return;
    setState(() => _escalating = true);
    try {
      await _repo.escalate(id);
      if (!mounted) return;
      setState(() => _escalating = false);
      // The handover notice is written into the thread server-side, so pull it
      // rather than composing a second copy of it here.
      await _pollOnce();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _escalating = false;
        _error = _clean(e);
      });
    }
  }

  Future<void> _close() async {
    final id = _ticketId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this request?'),
        content: const Text(
          'We will stop working on it. You can always start a new one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it open'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.close(id);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _clean(e));
    }
  }

  Future<void> _rate(int score) async {
    final id = _ticketId;
    if (id == null) return;
    try {
      await _repo.submitCsat(id, score);
      if (!mounted) return;
      final ticket = _ticket;
      if (ticket != null) {
        setState(() {
          _ticket = SupportTicket(
            id: ticket.id,
            reference: ticket.reference,
            subject: ticket.subject,
            category: ticket.category,
            status: ticket.status,
            priority: ticket.priority,
            channel: ticket.channel,
            unread: ticket.unread,
            messageSeq: ticket.messageSeq,
            assignedOperator: ticket.assignedOperator,
            escalatedAt: ticket.escalatedAt,
            resolvedAt: ticket.resolvedAt,
            closedAt: ticket.closedAt,
            csatScore: score,
            lastMessageAt: ticket.lastMessageAt,
            createdAt: ticket.createdAt,
          );
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for the feedback.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _clean(e));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '').trim();

  String get _title => widget.categoryTitle ?? 'Help';

  String get _subtitle {
    final ticket = _ticket;
    if (ticket == null) return 'We usually reply straight away';
    switch (ticket.status) {
      case SupportTicketStatus.bot:
        return 'Communal Assistant · ${ticket.reference}';
      case SupportTicketStatus.open:
        return ticket.assignedOperator == null
            ? 'With our team · ${ticket.reference}'
            : '${ticket.assignedOperator} · ${ticket.reference}';
      case SupportTicketStatus.pendingRequester:
        return 'Waiting on you · ${ticket.reference}';
      case SupportTicketStatus.resolved:
        return 'Resolved · ${ticket.reference}';
      case SupportTicketStatus.closed:
        return 'Closed · ${ticket.reference}';
      default:
        return ticket.reference;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticket = _ticket;
    final finished = ticket?.isFinished ?? false;

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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                _subtitle,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          actions: [
            if (_ticketId != null)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'person') unawaited(_escalate());
                  if (value == 'close') unawaited(_close());
                  if (value == 'refresh') unawaited(_load());
                },
                itemBuilder: (context) => [
                  if (ticket != null && ticket.isWithBot && !finished)
                    const PopupMenuItem(
                      value: 'person',
                      child: Text('Talk to a person'),
                    ),
                  const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                  if (!finished)
                    const PopupMenuItem(
                      value: 'close',
                      child: Text('Close this request'),
                    ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            if (_error != null) _errorBanner(theme),
            Expanded(child: _body(theme)),
            if (ticket != null && ticket.awaitsCsat) _csatBar(theme),
            if (finished) _finishedNotice(theme) else _composerBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return _intro(theme);
    }
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _typing(theme);
        return _bubble(theme, _messages[index]);
      },
    );
  }

  /// What a brand-new conversation shows before anything is sent. Deliberately
  /// says what the assistant can and cannot do: a first line that promises more
  /// than it delivers is how a help desk loses trust on the first message.
  Widget _intro(ThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent, color: _brand, size: 32.sp),
          ),
          vSpace(16),
          Text(
            'Tell us what is going on',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          vSpace(8),
          Text(
            'Our assistant answers the common questions straight away — your '
            'balance, a transfer, a repayment date. Anything it cannot answer '
            'goes to a person, with everything you have already told us.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ThemeData theme, SupportMessage message) {
    if (message.isSystem) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 24.w),
        child: Text(
          message.body,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16.sp,
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    final mine = message.isMine;
    final bot = message.authorType == SupportAuthor.bot;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
              child: Row(
                children: [
                  Icon(
                    bot ? Icons.smart_toy_outlined : Icons.person_outline,
                    size: 14.sp,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  hSpace(4),
                  Text(
                    bot
                        ? 'Communal Assistant'
                        : (message.authorName ?? 'Communal Support'),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            constraints: BoxConstraints(maxWidth: 0.78.sw),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: mine ? _brand : theme.cardColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.r),
                topRight: Radius.circular(14.r),
                bottomLeft: Radius.circular(mine ? 14.r : 4.r),
                bottomRight: Radius.circular(mine ? 4.r : 14.r),
              ),
              boxShadow: mine
                  ? null
                  : [
                      BoxShadow(
                        color: theme.dividerColor,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Text(
              message.body,
              style: TextStyle(
                fontSize: 17.sp,
                height: 1.4,
                color: mine ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (message.createdAt != null)
            Padding(
              padding: EdgeInsets.only(top: 4.h, left: 4.w, right: 4.w),
              child: Text(
                DateFormat('h:mm a').format(message.createdAt!),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _typing(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Row(
        children: [
          SizedBox(
            width: 14.sp,
            height: 14.sp,
            child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
          ),
          hSpace(8),
          Text(
            'Sending…',
            style: TextStyle(
              fontSize: 16.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      color: Colors.red.withValues(alpha: 0.08),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 18.sp),
          hSpace(8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(fontSize: 16.sp, color: Colors.red.shade700),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: Icon(Icons.close, size: 16.sp, color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }

  Widget _csatBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: theme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Did we sort this out?',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          vSpace(8),
          Row(
            children: [
              for (final score in [1, 2, 3, 4, 5])
                Padding(
                  padding: EdgeInsets.only(right: 6.w),
                  child: IconButton(
                    onPressed: () => unawaited(_rate(score)),
                    icon: Icon(Icons.star_border, size: 24.sp, color: _brand),
                    tooltip: '$score out of 5',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finishedNotice(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      color: theme.cardColor,
      child: SafeArea(
        top: false,
        child: Text(
          'This request is closed. Start a new one from Help & Support if you '
          'still need a hand.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16.sp,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _composerBar(ThemeData theme) {
    final ticket = _ticket;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: theme.dividerColor,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (ticket != null && ticket.isWithBot)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _escalating ? null : () => unawaited(_escalate()),
                  icon: Icon(Icons.headset_mic_outlined, size: 16.sp),
                  label: Text(
                    _escalating ? 'Getting someone…' : 'Talk to a person',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(foregroundColor: _brand),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type your message…',
                      hintStyle: TextStyle(
                        fontSize: 17.sp,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => unawaited(_send()),
                  ),
                ),
                hSpace(8),
                GestureDetector(
                  onTap: _sending ? null : () => unawaited(_send()),
                  child: Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: _sending ? _brand.withValues(alpha: 0.5) : _brand,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.send, color: Colors.white, size: 20.sp),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

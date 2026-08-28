/// Support desk models — tickets, their messages, the knowledge base and the
/// admin-set contact settings.
///
/// support-svc answers with bare JSON (no `{status, data}` envelope), so these
/// parse the body directly. Every field is defensive about nulls: a ticket that
/// the bot is still holding has no assignee, no first response and no SLA clock,
/// and a visitor-era row may have no requester id at all.
library;

/// Ticket lifecycle. `bot` means the first-line responder still owns the thread;
/// from `open` onwards a person does.
class SupportTicketStatus {
  SupportTicketStatus._();

  static const String bot = 'bot';
  static const String open = 'open';
  static const String pendingRequester = 'pending_requester';
  static const String resolved = 'resolved';
  static const String closed = 'closed';
}

/// The categories support-svc recognises. Anything else it stores as `other`,
/// so the six help-grid cards map onto values from this list rather than
/// inventing their own.
class SupportCategory {
  SupportCategory._();

  static const String accountRegistration = 'account_registration';
  static const String loans = 'loans';
  static const String cooperative = 'cooperative';
  static const String security = 'security';
  static const String transactions = 'transactions';
  static const String billing = 'billing';
  static const String kyc = 'kyc';
  static const String general = 'general';
  static const String other = 'other';
}

/// The member-facing name of a category. The service's values are snake_case
/// identifiers; these are the words already on the help grid, so a ticket raised
/// from a card keeps that card's wording everywhere it is shown afterwards.
String supportCategoryLabel(String category) {
  switch (category) {
    case SupportCategory.accountRegistration:
      return 'Account Registration';
    case SupportCategory.loans:
      return 'Loan Issues';
    case SupportCategory.cooperative:
      return 'Cooperative Problems';
    case SupportCategory.security:
      return 'Security Concerns';
    case SupportCategory.transactions:
      return 'Transaction Issues';
    case SupportCategory.billing:
      return 'Bills & Airtime';
    case SupportCategory.kyc:
      return 'Verification';
    case SupportCategory.general:
      return 'General';
    case SupportCategory.other:
      return 'Other Issues';
    default:
      // An admin may add a category the app has never heard of; show it rather
      // than hiding the articles filed under it.
      return category
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
  }
}

DateTime? _date(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toLocal();
  return null;
}

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

bool _bool(dynamic v) {
  if (v is bool) return v;
  final s = '${v ?? ''}'.toLowerCase();
  return s == '1' || s == 'true';
}

String _str(dynamic v) => v == null ? '' : '$v';

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.reference,
    required this.subject,
    required this.category,
    required this.status,
    required this.priority,
    required this.channel,
    required this.unread,
    required this.messageSeq,
    this.assignedOperator,
    this.escalatedAt,
    this.resolvedAt,
    this.closedAt,
    this.csatScore,
    this.lastMessageAt,
    this.createdAt,
  });

  final String id;
  final String reference;
  final String subject;
  final String category;
  final String status;
  final String priority;
  final String channel;

  /// Messages written since the requester last opened the thread. Drives the
  /// badge on the ticket list.
  final int unread;

  /// The highest message sequence the server has issued for this ticket. The
  /// chat screen polls `?after=<seq>`, never on a timestamp: two messages
  /// written in the same second would be indistinguishable.
  final int messageSeq;

  final String? assignedOperator;
  final DateTime? escalatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final int? csatScore;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  /// True while the bot still owns the thread.
  bool get isWithBot => status == SupportTicketStatus.bot;

  /// True once nobody is expected to write again.
  bool get isFinished =>
      status == SupportTicketStatus.resolved || status == SupportTicketStatus.closed;

  /// A resolved ticket the member has not rated yet — the only case where the
  /// chat screen asks for a score.
  bool get awaitsCsat => status == SupportTicketStatus.resolved && csatScore == null;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: _str(json['id']),
        reference: _str(json['reference']),
        subject: _str(json['subject']),
        category: _str(json['category']),
        status: _str(json['status']).isEmpty
            ? SupportTicketStatus.bot
            : _str(json['status']),
        priority: _str(json['priority']),
        channel: _str(json['channel']),
        unread: _int(json['unread_for_requester']),
        messageSeq: _int(json['message_seq']),
        assignedOperator: json['assigned_operator'] == null
            ? null
            : _str(json['assigned_operator']),
        escalatedAt: _date(json['escalated_at']),
        resolvedAt: _date(json['resolved_at']),
        closedAt: _date(json['closed_at']),
        csatScore: json['csat_score'] == null ? null : _int(json['csat_score']),
        lastMessageAt: _date(json['last_message_at']),
        createdAt: _date(json['created_at']),
      );
}

/// Who wrote a message. `system` is the service itself — "we have passed this to
/// a person" — and is rendered as a centred notice rather than a bubble.
class SupportAuthor {
  SupportAuthor._();

  static const String requester = 'requester';
  static const String bot = 'bot';
  static const String operator = 'operator';
  static const String system = 'system';
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.seq,
    required this.authorType,
    required this.body,
    this.authorName,
    this.createdAt,
    this.pending = false,
    this.failed = false,
  });

  final String id;
  final int seq;
  final String authorType;
  final String body;
  final String? authorName;
  final DateTime? createdAt;

  /// Set on the optimistic bubble the composer shows before the POST returns.
  /// Never comes off the wire.
  final bool pending;
  final bool failed;

  bool get isMine => authorType == SupportAuthor.requester;
  bool get isSystem => authorType == SupportAuthor.system;

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: _str(json['id']),
        seq: _int(json['seq']),
        authorType: _str(json['author_type']),
        body: _str(json['body']),
        authorName:
            json['author_name'] == null ? null : _str(json['author_name']),
        createdAt: _date(json['created_at']),
      );

  SupportMessage copyWith({bool? pending, bool? failed}) => SupportMessage(
        id: id,
        seq: seq,
        authorType: authorType,
        body: body,
        authorName: authorName,
        createdAt: createdAt,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
      );
}

/// A ticket with its thread — what every open returns, so a screen never has to
/// create-then-fetch.
class SupportThread {
  const SupportThread({required this.ticket, required this.messages});

  final SupportTicket ticket;
  final List<SupportMessage> messages;

  factory SupportThread.fromJson(Map<String, dynamic> json) => SupportThread(
        ticket: SupportTicket.fromJson(
          Map<String, dynamic>.from((json['ticket'] as Map?) ?? const {}),
        ),
        messages: _messages(json['messages']),
      );
}

List<SupportMessage> _messages(dynamic raw) => raw is List
    ? raw
        .whereType<Map>()
        .map((e) => SupportMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList()
    : <SupportMessage>[];

/// What a send returns: the requester's own stored turn, whatever was written
/// after it — the bot's answer, when the bot still owns the ticket — and the
/// ticket's status, which the answer itself may have changed by escalating.
class SupportSendResult {
  const SupportSendResult({
    required this.message,
    required this.replies,
    required this.status,
  });

  final SupportMessage? message;
  final List<SupportMessage> replies;
  final String status;

  /// Everything the thread gained, in order.
  List<SupportMessage> get all => [
        if (message != null) message!,
        ...replies,
      ];

  factory SupportSendResult.fromJson(Map<String, dynamic> json) {
    final raw = json['message'];
    return SupportSendResult(
      message: raw is Map
          ? SupportMessage.fromJson(Map<String, dynamic>.from(raw))
          : null,
      replies: _messages(json['messages']),
      status: _str(json['status']),
    );
  }
}

/// One poll result. `seq` is the watermark to send on the next poll, and
/// `status` is here because a thread can be handed to a person, resolved or
/// closed while the member is looking at it.
class SupportPoll {
  const SupportPoll({
    required this.messages,
    required this.seq,
    required this.status,
    required this.botActive,
    this.assignee,
  });

  final List<SupportMessage> messages;
  final int seq;
  final String status;
  final bool botActive;
  final String? assignee;

  factory SupportPoll.fromJson(Map<String, dynamic> json) => SupportPoll(
        messages: _messages(json['messages']),
        seq: _int(json['seq']),
        status: _str(json['status']),
        botActive: _bool(json['bot_active']),
        assignee: json['assignee'] == null ? null : _str(json['assignee']),
      );
}

/// A published answer. This is the single knowledge base behind the mobile help
/// screen, the FAQ catalogue, member-web, the website and the bot itself — the
/// three hardcoded FAQ lists that used to exist are how they drifted apart.
class KbArticle {
  const KbArticle({
    required this.id,
    required this.slug,
    required this.category,
    required this.question,
    required this.answer,
  });

  final String id;
  final String slug;
  final String category;
  final String question;
  final String answer;

  factory KbArticle.fromJson(Map<String, dynamic> json) => KbArticle(
        id: _str(json['id']),
        slug: _str(json['slug']),
        category: _str(json['category']),
        question: _str(json['question']),
        answer: _str(json['answer']),
      );
}

/// The admin-set support settings: the contact details, whether the bot is on
/// and whether anyone is at the desk right now. The help screen used to hardcode
/// an address belonging to a different product; these values replace it.
class SupportConfig {
  const SupportConfig({
    required this.operatorsOnline,
    required this.botEnabled,
    required this.email,
    required this.phone,
    required this.firstResponseSlaMinutes,
    this.hoursText,
    this.hours = const [],
    this.timezone = '',
  });

  final bool operatorsOnline;
  final bool botEnabled;
  final String email;
  final String phone;
  final int firstResponseSlaMinutes;

  /// `support_hours` typed as free text by an operator rather than as JSON.
  final String? hoursText;

  /// `support_hours` stored as JSON: a list of `{day, hours}` rows.
  final List<SupportHours> hours;

  /// The zone those hours are quoted in, as the desk set it — `Africa/Lagos`,
  /// `Africa/Nairobi`, whatever. Empty when the setting does not name one, and the
  /// card then quotes no zone rather than assuming the reader shares ours.
  final String timezone;

  static const SupportConfig fallback = SupportConfig(
    operatorsOnline: false,
    botEnabled: true,
    email: '',
    phone: '',
    firstResponseSlaMinutes: 60,
  );

  factory SupportConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['support_hours'];
    return SupportConfig(
      operatorsOnline: _bool(json['operators_online']),
      botEnabled: _bool(json['bot_enabled']),
      email: _str(json['support_email']),
      phone: _str(json['support_phone']),
      firstResponseSlaMinutes: _int(json['first_response_sla_minutes']),
      hoursText: raw is String && raw.isNotEmpty ? raw : null,
      hours: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => SupportHours.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : raw is Map
              ? _spans(Map<String, dynamic>.from(raw))
              : const [],
      timezone: raw is Map ? _str(raw['timezone']) : '',
    );
  }

  /// The shape the admin console writes: `{timezone, weekday|saturday|sunday:
  /// {open, close} | null}`. Only the list shape was read before, so every desk that
  /// set its hours from the console got none of them on this screen — the card fell
  /// back to the hours that were hardcoded in it, which is what the setting exists to
  /// stop. A day set to null is a closed day and is shown as one.
  static List<SupportHours> _spans(Map<String, dynamic> raw) {
    const days = <String, String>{
      'weekday': 'Monday - Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
    };

    final out = <SupportHours>[];
    days.forEach((key, label) {
      if (!raw.containsKey(key)) return;
      final span = raw[key];
      if (span is Map) {
        final open = _str(span['open']);
        final close = _str(span['close']);
        if (open.isNotEmpty && close.isNotEmpty) {
          out.add(SupportHours(day: label, hours: '$open - $close'));
          return;
        }
      }
      out.add(SupportHours(day: label, hours: 'Closed'));
    });
    return out;
  }
}

class SupportHours {
  const SupportHours({required this.day, required this.hours});

  final String day;
  final String hours;

  factory SupportHours.fromJson(Map<String, dynamic> json) => SupportHours(
        day: _str(json['day']).isEmpty ? _str(json['label']) : _str(json['day']),
        hours:
            _str(json['hours']).isEmpty ? _str(json['time']) : _str(json['hours']),
      );
}

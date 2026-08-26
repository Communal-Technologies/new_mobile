import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/support_models.dart';
import 'package:dio/dio.dart';

class SupportTicketsResult {
  const SupportTicketsResult({required this.tickets, required this.unreadTotal});

  final List<SupportTicket> tickets;
  final int unreadTotal;
}

/// The member's side of the help desk.
///
/// support-svc returns bare JSON — no `{status, data}` envelope — so every read
/// here pulls its key straight off the body. Identity is never sent: the service
/// resolves the requester from the token, which is also why the bot's lookup
/// tools cannot be pointed at another member.
class SupportRepository {
  SupportRepository(this._dioClient);

  final DioClient _dioClient;

  /// Admin-set contact details and support hours. Public, so it works on the
  /// help screen before a session exists, and falls back rather than throwing:
  /// a help screen missing a phone number is better than one that fails to open.
  Future<SupportConfig> config() async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.supportConfig,
        requireAuth: false,
      );
      final body = response.data;
      if (body is Map) {
        return SupportConfig.fromJson(Map<String, dynamic>.from(body));
      }
      return SupportConfig.fallback;
    } catch (_) {
      return SupportConfig.fallback;
    }
  }

  /// Published articles for this reader. [query] searches question, answer and
  /// keywords; [category] filters. The audience comes from the token, so a
  /// member sees member and public answers and nothing else.
  Future<List<KbArticle>> knowledgeBase({
    String query = '',
    String category = '',
    int limit = 50,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.supportKb,
        queryParameters: {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          if (category.trim().isNotEmpty) 'category': category.trim(),
          'limit': limit,
        },
      );
      final body = response.data;
      if (body is Map && body['articles'] is List) {
        return (body['articles'] as List)
            .whereType<Map>()
            .map((e) => KbArticle.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'Unable to load help articles.'));
    }
  }

  /// Categories that actually have a published article for this reader, so a
  /// help screen never opens an empty section.
  Future<List<String>> knowledgeBaseCategories() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.supportKbCategories);
      final body = response.data;
      if (body is Map && body['categories'] is List) {
        return (body['categories'] as List).map((e) => '$e').toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Records whether an article answered the question. Fire-and-forget: the vote
  /// is an editing signal, not something worth interrupting the reader over.
  Future<void> voteArticle(String slug, {required bool helpful}) async {
    try {
      await _dioClient.post(
        ApiEndpoints.supportKbVote(slug),
        data: {'helpful': helpful},
      );
    } catch (_) {
      // Silent by design.
    }
  }

  Future<SupportTicketsResult> tickets({String status = '', int limit = 25}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.supportTickets,
        queryParameters: {
          if (status.trim().isNotEmpty) 'status': status.trim(),
          'limit': limit,
        },
      );
      final body = response.data;
      if (body is Map) {
        final raw = body['tickets'];
        return SupportTicketsResult(
          tickets: raw is List
              ? raw
                  .whereType<Map>()
                  .map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
          unreadTotal: int.tryParse('${body['unread_total'] ?? ''}') ?? 0,
        );
      }
      return const SupportTicketsResult(tickets: [], unreadTotal: 0);
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'Unable to load your requests.'));
    }
  }

  /// Opens a ticket. The response already carries the bot's first answer, so the
  /// chat screen has something on it the moment it appears.
  ///
  /// [category] should be one of [SupportCategory]; support-svc stores anything
  /// it does not recognise as `other` rather than refusing the ticket.
  Future<SupportThread> createTicket({
    required String message,
    String category = SupportCategory.other,
    String subject = '',
    String sourceRef = '',
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.supportTickets,
        data: {
          'message': message,
          'category': category,
          if (subject.trim().isNotEmpty) 'subject': subject.trim(),
          if (sourceRef.trim().isNotEmpty) 'source_ref': sourceRef.trim(),
          'channel': 'app',
        },
      );
      final body = response.data;
      if (body is Map) {
        return SupportThread.fromJson(Map<String, dynamic>.from(body));
      }
      throw Exception('Unexpected response from server.');
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'We could not start that conversation.'));
    }
  }

  Future<SupportThread> thread(String ticketId) async {
    try {
      final response = await _dioClient.get(ApiEndpoints.supportTicket(ticketId));
      final body = response.data;
      if (body is Map) {
        return SupportThread.fromJson(Map<String, dynamic>.from(body));
      }
      throw Exception('Unexpected response from server.');
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'Unable to open that conversation.'));
    }
  }

  /// The poll. [after] is the last sequence the screen has, not a timestamp:
  /// two messages written in the same second would be indistinguishable and the
  /// screen would either miss one or show it twice.
  Future<SupportPoll> poll(String ticketId, int after) async {
    final response = await _dioClient.get(
      ApiEndpoints.supportTicketMessages(ticketId),
      queryParameters: {'after': after},
    );
    final body = response.data;
    if (body is Map) {
      return SupportPoll.fromJson(Map<String, dynamic>.from(body));
    }
    return SupportPoll(
      messages: const [],
      seq: after,
      status: SupportTicketStatus.bot,
      botActive: true,
    );
  }

  /// Writes a message. When the bot still owns the ticket its answer comes back
  /// on the same round trip, so the reply lands with the send rather than on the
  /// next poll — hence [SupportSendResult] rather than a single row.
  Future<SupportSendResult> sendMessage(String ticketId, String message) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.supportTicketMessages(ticketId),
        data: {'message': message},
      );
      final body = response.data;
      if (body is Map) {
        return SupportSendResult.fromJson(Map<String, dynamic>.from(body));
      }
      throw Exception('Unexpected response from server.');
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'Your message was not sent.'));
    }
  }

  /// Asks for a person. Returns the handover line to show in the thread — it
  /// names the support window when nobody is at the desk, so the member is told
  /// when to expect a reply instead of being left waiting on silence.
  Future<String> escalate(String ticketId) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.supportTicketEscalate(ticketId),
      );
      final body = response.data;
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
      return 'We have passed this to a member of our team.';
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'We could not reach the team.'));
    }
  }

  Future<void> close(String ticketId) async {
    try {
      await _dioClient.post(ApiEndpoints.supportTicketClose(ticketId));
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'We could not close that request.'));
    }
  }

  Future<void> submitCsat(String ticketId, int score, {String comment = ''}) async {
    try {
      await _dioClient.post(
        ApiEndpoints.supportTicketCsat(ticketId),
        data: {
          'score': score,
          if (comment.trim().isNotEmpty) 'comment': comment.trim(),
        },
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e, 'We could not record that rating.'));
    }
  }

  String _messageFromDio(DioException e, String fallback) {
    final response = e.response;
    if (response == null) return 'Network error. Please check your connection.';
    final data = response.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return fallback;
  }
}

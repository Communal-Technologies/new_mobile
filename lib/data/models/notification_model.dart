enum NotificationStatus { unread, read }

enum NotificationType { guarantorLoanApproval, message, unknown }

NotificationStatus _parseStatus(String? raw) {
  if (raw == '1') return NotificationStatus.read;
  return NotificationStatus.unread;
}

NotificationType _parseType(String? raw) {
  switch (raw) {
    case '1':
      return NotificationType.guarantorLoanApproval;
    case '2':
      return NotificationType.message;
    default:
      return NotificationType.unknown;
  }
}

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.cooperativeId,
    required this.message,
    required this.status,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String cooperativeId;
  final String message;
  final NotificationStatus status;
  final NotificationType type;
  final DateTime? createdAt;

  bool get isUnread => status == NotificationStatus.unread;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      cooperativeId: json['cooperative_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      type: _parseType(json['type']?.toString()),
      createdAt: parse(json['created_at']),
    );
  }

  NotificationModel copyWith({NotificationStatus? status}) {
    return NotificationModel(
      id: id,
      userId: userId,
      cooperativeId: cooperativeId,
      message: message,
      status: status ?? this.status,
      type: type,
      createdAt: createdAt,
    );
  }
}

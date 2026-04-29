/// Per-user notification channel preferences. Mirrors the backend
/// `user_notification_preferences` row 1:1.
class NotificationPreferences {
  const NotificationPreferences({
    this.muteAll = false,
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.paymentReminders = true,
    this.largeTransactions = true,
    this.promotionalOffers = false,
    this.productUpdates = true,
    this.newsletters = false,
  });

  final bool muteAll;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool paymentReminders;
  final bool largeTransactions;
  final bool promotionalOffers;
  final bool productUpdates;
  final bool newsletters;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    bool b(String key, bool fallback) {
      final v = json[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return fallback;
    }

    return NotificationPreferences(
      muteAll: b('mute_all', false),
      pushNotifications: b('push_notifications', true),
      emailNotifications: b('email_notifications', true),
      smsNotifications: b('sms_notifications', false),
      paymentReminders: b('payment_reminders', true),
      largeTransactions: b('large_transactions', true),
      promotionalOffers: b('promotional_offers', false),
      productUpdates: b('product_updates', true),
      newsletters: b('newsletters', false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mute_all': muteAll,
      'push_notifications': pushNotifications,
      'email_notifications': emailNotifications,
      'sms_notifications': smsNotifications,
      'payment_reminders': paymentReminders,
      'large_transactions': largeTransactions,
      'promotional_offers': promotionalOffers,
      'product_updates': productUpdates,
      'newsletters': newsletters,
    };
  }

  NotificationPreferences copyWith({
    bool? muteAll,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? paymentReminders,
    bool? largeTransactions,
    bool? promotionalOffers,
    bool? productUpdates,
    bool? newsletters,
  }) {
    return NotificationPreferences(
      muteAll: muteAll ?? this.muteAll,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      paymentReminders: paymentReminders ?? this.paymentReminders,
      largeTransactions: largeTransactions ?? this.largeTransactions,
      promotionalOffers: promotionalOffers ?? this.promotionalOffers,
      productUpdates: productUpdates ?? this.productUpdates,
      newsletters: newsletters ?? this.newsletters,
    );
  }
}

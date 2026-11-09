/// A message the platform wants a member to see once: a new feature, a warning,
/// a promotion. The image is the message; the optional action either routes to
/// a section of the app or leaves it.
class Announcement {
  const Announcement({
    required this.id,
    required this.imageUrl,
    this.title,
    this.body,
    this.imageWidth,
    this.imageHeight,
    this.actionType,
    this.actionLabel,
    this.actionTarget,
    this.dismissible = true,
  });

  final String id;
  final String imageUrl;
  final String? title;
  final String? body;
  final int? imageWidth;
  final int? imageHeight;
  final String? actionType;
  final String? actionLabel;
  final String? actionTarget;
  final bool dismissible;

  bool get hasAction =>
      (actionLabel?.trim().isNotEmpty ?? false) &&
      (actionTarget?.trim().isNotEmpty ?? false);

  bool get opensOutsideApp => actionType == 'external';

  /// Aspect ratio for the image box, so artwork of any shape is shown whole
  /// rather than cropped to a fixed frame.
  double? get aspectRatio {
    final w = imageWidth, h = imageHeight;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id']?.toString() ?? '',
        imageUrl: json['image_url']?.toString() ?? '',
        title: json['title']?.toString(),
        body: json['body']?.toString(),
        imageWidth: _toInt(json['image_width']),
        imageHeight: _toInt(json['image_height']),
        actionType: json['action_type']?.toString(),
        actionLabel: json['action_label']?.toString(),
        actionTarget: json['action_target']?.toString(),
        dismissible: json['dismissible'] == null || json['dismissible'] == true,
      );
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

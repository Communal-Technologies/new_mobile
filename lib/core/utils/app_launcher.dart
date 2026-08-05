import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the platform's in-app browser (Chrome Custom Tabs on
/// Android, SFSafariViewController on iOS). Falls back to the external
/// browser if the in-app mode is unavailable, and shows a toast when the
/// URL cannot be launched at all.
Future<void> launchAppUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    AppToast.error('Invalid URL.');
    return;
  }

  final launched = await launchUrl(
    uri,
    mode: LaunchMode.inAppBrowserView,
  );

  if (!launched) {
    final external = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!external) {
      AppToast.error('Could not open the page. Please try again.');
    }
  }
}

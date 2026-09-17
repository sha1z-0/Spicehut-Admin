import 'package:url_launcher/url_launcher.dart';

class ExternalLinks {
  static final Uri privacyPolicy = Uri.parse(
    'https://sha1z-0.github.io/Spicehut-Privacy-Policy/',
  );

  static Future<void> openPrivacyPolicy() async {
    await _open(privacyPolicy);
  }

  static Future<void> _open(Uri uri) async {
    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) return;

    await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
  }
}

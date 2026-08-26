import 'package:url_launcher/url_launcher.dart';

class CallService {
  static Future<bool> call(String phoneNumber) async {
    final cleanedPhoneNumber = phoneNumber.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );

    if (cleanedPhoneNumber.isEmpty) {
      return false;
    }

    final phoneUri = Uri(
      scheme: 'tel',
      path: cleanedPhoneNumber,
    );

    return launchUrl(
      phoneUri,
      mode: LaunchMode.externalApplication,
    );
  }
}

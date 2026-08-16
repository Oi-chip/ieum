import 'package:url_launcher/url_launcher.dart';

class CallService {
  // 휴대폰 기본 전화 앱을 열어 전화번호를 입력합니다.
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
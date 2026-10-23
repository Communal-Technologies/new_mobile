import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

const _handset = MethodChannel('elite.codec.communal/handset');

/// Reads the handset id every Communal app on this phone sees: ANDROID_ID on
/// Android, identifierForVendor on iOS. Empty is a normal answer.
///
/// Not `device_info_plus`'s `id` on Android — that is `Build.ID`, the operating
/// system's build number, which every phone on one build shares.
Future<String> handsetId() async {
  try {
    if (Platform.isAndroid) {
      return (await _handset.invokeMethod<String>('androidId')) ?? '';
    }
    if (Platform.isIOS) {
      return (await DeviceInfoPlugin().iosInfo).identifierForVendor ?? '';
    }
  } catch (_) {
    return '';
  }
  return '';
}

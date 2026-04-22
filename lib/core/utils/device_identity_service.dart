import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceIdentityService {
  DeviceIdentityService._();

  static const MethodChannel _channel = MethodChannel('billing_app/feedback');
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static Future<String?> getDeviceId() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final deviceId = await _channel.invokeMethod<String>('getDeviceId');
        return _clean(deviceId);
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfoPlugin.iosInfo;
        return _clean(info.identifierForVendor);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}

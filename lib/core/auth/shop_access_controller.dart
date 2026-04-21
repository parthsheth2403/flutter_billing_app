import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/hive_database.dart';

enum ShopAccessStatus {
  authenticated,
  unauthenticated,
}

class ShopAccessProfile {
  final String shopId;
  final String shopName;
  final String shopKey;
  final String mobileNumber;
  final DateTime startDate;
  final DateTime expiryDate;

  const ShopAccessProfile({
    required this.shopId,
    required this.shopName,
    required this.shopKey,
    required this.mobileNumber,
    required this.startDate,
    required this.expiryDate,
  });

  factory ShopAccessProfile.fromMap(Map<String, dynamic> map) {
    return ShopAccessProfile(
      shopId: map['shopId']?.toString() ?? '',
      shopName: map['shopName']?.toString() ?? '',
      shopKey: map['shopKey']?.toString() ?? '',
      mobileNumber: map['mobileNumber']?.toString() ?? '',
      startDate: _parseDate(map['startDate']) ?? DateTime.now(),
      expiryDate: _parseDate(map['expiryDate']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'shopName': shopName,
      'shopKey': shopKey,
      'mobileNumber': mobileNumber,
      'startDate': startDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
    };
  }

  bool get isExpired {
    final now = DateTime.now();
    final expiryEndOfDay = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
      23,
      59,
      59,
      999,
    );
    return now.isAfter(expiryEndOfDay);
  }

  String get formattedExpiryDate =>
      DateFormat('dd MMM yyyy').format(expiryDate);

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class ShopAccessController extends ChangeNotifier {
  ShopAccessController._();

  static final ShopAccessController instance = ShopAccessController._();

  static const String _profileKey = 'shop_access_profile';
  static const String _sessionActiveKey = 'shop_access_session_active';
  static const String _lastVerifiedAtKey = 'shop_access_last_verified_at';

  ShopAccessProfile? _profile;
  ShopAccessStatus _status = ShopAccessStatus.unauthenticated;
  bool _sessionActive = false;

  ShopAccessProfile? get profile => _profile;
  ShopAccessStatus get status => _status;
  bool get isAuthenticated => _status == ShopAccessStatus.authenticated;
  bool get hasCachedProfile => _profile != null;
  bool get isExpired => _profile?.isExpired ?? false;
  String? get cachedShopId => _profile?.shopId;

  Future<void> init() async {
    final rawProfile = HiveDatabase.settingsBox.get(_profileKey);
    if (rawProfile is Map) {
      _profile = ShopAccessProfile.fromMap(
        Map<String, dynamic>.from(rawProfile),
      );
    }

    _sessionActive =
        HiveDatabase.settingsBox.get(_sessionActiveKey, defaultValue: false) ==
            true;

    _refreshLocalStatus(notify: false);
  }

  Future<String?> signIn({
    required String shopId,
    required String shopKey,
  }) async {
    final trimmedShopId = shopId.trim().toUpperCase();
    final trimmedShopKey = shopKey.trim();

    if (trimmedShopId.isEmpty || trimmedShopKey.isEmpty) {
      return 'Enter shop ID and shop key.';
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .where('shopId', isEqualTo: trimmedShopId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'Shop ID or shop key is invalid.';
      }

      final data = snapshot.docs.first.data();
      final savedShopKey = data['shopKey']?.toString().trim() ?? '';
      final isActive = data['isActive'] as bool? ?? true;

      if (savedShopKey != trimmedShopKey) {
        return 'Shop ID or shop key is invalid.';
      }

      if (!isActive) {
        return 'This shop is inactive. Please contact support.';
      }

      final profile = ShopAccessProfile.fromMap(data);

      await _persistProfile(profile, sessionActive: !profile.isExpired);

      if (profile.isExpired) {
        return 'This shop expired on ${profile.formattedExpiryDate}.';
      }

      return null;
    } on FirebaseException {
      return 'Unable to verify shop right now. Check internet and try again.';
    } catch (_) {
      return 'Something went wrong while verifying your shop.';
    }
  }

  Future<void> logout() async {
    _sessionActive = false;
    await HiveDatabase.settingsBox.put(_sessionActiveKey, false);
    _refreshLocalStatus();
  }

  Future<void> _persistProfile(
    ShopAccessProfile profile, {
    required bool sessionActive,
  }) async {
    _profile = profile;
    _sessionActive = sessionActive;

    await HiveDatabase.settingsBox.put(_profileKey, profile.toMap());
    await HiveDatabase.settingsBox.put(_sessionActiveKey, sessionActive);
    await HiveDatabase.settingsBox.put(
      _lastVerifiedAtKey,
      DateTime.now().toIso8601String(),
    );

    _refreshLocalStatus();
  }

  void _refreshLocalStatus({bool notify = true}) {
    if (_profile == null) {
      _status = ShopAccessStatus.unauthenticated;
    } else if (_profile!.isExpired) {
      _sessionActive = false;
      HiveDatabase.settingsBox.put(_sessionActiveKey, false);
      _status = ShopAccessStatus.unauthenticated;
    } else if (_sessionActive) {
      _status = ShopAccessStatus.authenticated;
    } else {
      _status = ShopAccessStatus.unauthenticated;
    }

    if (notify) {
      notifyListeners();
    }
  }
}

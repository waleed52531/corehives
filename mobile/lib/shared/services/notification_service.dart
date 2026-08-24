import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Foreground message received: ${message.notification?.title}');
        }
      });

      // Handle message click when app opens from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Notification clicked to open app: ${message.data}');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing NotificationService: $e');
      }
    }
  }

  /// Requests notification permission and retrieves/registers the FCM token.
  static Future<void> registerUserDevice(String uid) async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _fcm.getToken();
        if (token != null) {
          print('Generated FCM Token: $token');
          await _db.collection('users').doc(uid).update({
            'fcmTokens': FieldValue.arrayUnion([token]),
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error registering notification token: $e');
      }
    }
  }

  /// Gets the current token for display/copy.
  static Future<String?> getDeviceToken() async {
    try {
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Sends a pending withdrawal push notification directly to the resolved target owner.
  static Future<void> sendPendingWithdrawalNotification({
    required String upworkAccountId,
    required String upworkAccountName,
    required double amount,
    required String transactionId,
  }) async {
    try {
      // 1. Fetch FCM Server Key from app_settings/fcm
      final fcmSettingsDoc = await _db.collection('app_settings').doc('fcm').get();
      if (!fcmSettingsDoc.exists) {
        print('FCM: Server settings document app_settings/fcm not found.');
        return;
      }
      final serverKey = fcmSettingsDoc.data()?['serverKey'] as String?;
      if (serverKey == null || serverKey.isEmpty) {
        print('FCM: serverKey field is empty in app_settings/fcm document.');
        return;
      }

      // 2. Resolve target owner name based on mapping rules
      final accSnap = await _db.collection('upwork_accounts').doc(upworkAccountId).get();
      String ownerName = accSnap.exists ? (accSnap.data()?['ownerName'] ?? '') : '';

      if (ownerName.isEmpty) {
        final accName = upworkAccountName.toLowerCase();
        if (accName.contains('alina')) {
          ownerName = 'Ishtiaq';
        } else if (accName.contains('abiha') || accName.contains('zain')) {
          ownerName = 'Zain';
        } else if (accName.contains('hanzalah')) {
          ownerName = 'Hanzalah';
        }
      }

      if (ownerName.isEmpty) {
        print('FCM: Could not resolve owner name for account: $upworkAccountName');
        return;
      }

      // 3. Find target users matching the owner name
      final usersSnap = await _db.collection('users').get();
      final targetUsers = usersSnap.docs.where((doc) {
        final data = doc.data();
        final nameLower = (data['name'] as String? ?? '').toLowerCase();
        final ownerLower = ownerName.toLowerCase();
        return nameLower.contains(ownerLower) || ownerLower.contains(nameLower);
      }).toList();

      // 4. Gather FCM tokens
      final tokens = <String>[];
      for (final doc in targetUsers) {
        final data = doc.data();
        final userTokens = data['fcmTokens'];
        if (userTokens is List) {
          tokens.addAll(userTokens.map((t) => t.toString()));
        }
      }

      final uniqueTokens = tokens.toSet().toList();
      if (uniqueTokens.isEmpty) {
        print('FCM: No device tokens registered for owner: $ownerName');
        return;
      }

      // 5. Send FCM legacy HTTP post request
      final amountFormatted = amount.toStringAsFixed(2);
      final payload = {
        'registration_ids': uniqueTokens,
        'notification': {
          'title': 'Action Required: Pending Withdrawal',
          'body': 'A new pending cash-in of PKR $amountFormatted has been added to your platform account.',
          'sound': 'default',
        },
        'data': {
          'transactionId': transactionId,
          'type': 'pending_withdrawal',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('https://fcm.googleapis.com/fcm/send'));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'key=$serverKey');
      request.write(jsonEncode(payload));
      
      final response = await request.close();
      if (response.statusCode == 200) {
        print('FCM: Direct push notifications dispatched successfully to $ownerName (${uniqueTokens.length} devices).');
      } else {
        final responseBody = await response.transform(utf8.decoder).join();
        print('FCM: Direct push dispatch failed (Status: ${response.statusCode}), Body: $responseBody');
      }
    } catch (e) {
      print('FCM: Error dispatching direct client notification: $e');
    }
  }
}

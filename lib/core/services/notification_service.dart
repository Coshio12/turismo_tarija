import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import '../constants/app_constants.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _fcm        = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidChannel = AndroidNotificationChannel(
      'turismo_tarija_channel',
      'Turismo Tarija',
      description: 'Notificaciones de reservas y mensajes',
      importance: Importance.high,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings     = DarwinInitializationSettings();
    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    FirebaseMessaging.onMessage.listen(_showLocalNotification);
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotif.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'turismo_tarija_channel',
          'Turismo Tarija',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<String?> getToken() => _fcm.getToken();

  Future<void> sendPushNotification({
    required String toToken,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    try {
      final credentials = ServiceAccountCredentials.fromJson(
        jsonDecode(AppConstants.serviceAccountJson),
      );
      final client = await clientViaServiceAccount(
        credentials,
        [AppConstants.fcmScope],
      );
      final payload = {
        'message': {
          'token': toToken,
          'notification': {'title': title, 'body': body},
          'data': data,
          'android': {
            'notification': {
              'channel_id': 'turismo_tarija_channel',
              'priority': 'HIGH',
            },
          },
          'apns': {
            'payload': {
              'aps': {'sound': 'default', 'badge': 1},
            },
          },
        },
      };
      await client.post(
        Uri.parse(AppConstants.fcmEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      client.close();
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('[NotificationService] sendPush error: $e');
        return true;
      }());
    }
  }
}
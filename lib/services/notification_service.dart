import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:stat_iq/utils/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone
    tz.initializeTimeZones();
    
    // Initialize local notifications
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    // Initialize plugin
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _flutterLocalNotificationsPlugin!.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );
    
    _isInitialized = true;
    AppLogger.d('✅ NotificationService initialized');
  }

  Future<void> scheduleMatchNotification({
    required String matchName,
    required String divisionName,
    required String field,
    required DateTime scheduledTime,
    required int matchId,
    required int minutesBefore,
    required String teamNumber,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Calculate notification time
    final notificationTime = scheduledTime.subtract(Duration(minutes: minutesBefore));
    
    // Don't schedule if in the past
    if (notificationTime.isBefore(DateTime.now())) {
      AppLogger.d('⚠️  Cannot schedule notification in the past');
      return;
    }
    
    // Android notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'match_reminders',
      'Match Reminders',
      channelDescription: 'Notifications for upcoming matches',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    
    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    // Notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Schedule notification
    final tz.TZDateTime scheduledTZDateTime = tz.TZDateTime.from(notificationTime, tz.local);
    
    await _flutterLocalNotificationsPlugin!.zonedSchedule(
      matchId,
      'Match Starting Soon',
      '$teamNumber - $matchName at $field',
      scheduledTZDateTime,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    
    AppLogger.d('✅ Scheduled notification for match $matchId at ${notificationTime.toString()}');
  }

  Future<void> cancelMatchNotification(int matchId) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    await _flutterLocalNotificationsPlugin!.cancel(matchId);
    AppLogger.d('✅ Cancelled notification for match $matchId');
  }

  Future<void> cancelAllMatchNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    await _flutterLocalNotificationsPlugin!.cancelAll();
    AppLogger.d('✅ Cancelled all match notifications');
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    return await _flutterLocalNotificationsPlugin!.pendingNotificationRequests();
  }
}

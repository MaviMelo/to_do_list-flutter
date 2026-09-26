import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'todo_repository.dart';

/// Notificações locais via flutter_local_notifications + timezone.
/// O agendamento usa zonedSchedule com TZDateTime local; o vínculo com a
/// tarefa é feito pelo id derivado (notificationIdFor(taskId)).
class TodoNotifier {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _available = false;

  bool get isAvailable => _available;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      } catch (_) {
        // fuso do dispositivo já é o default quando getLocation falha
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      _available = await _plugin.initialize(settings) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('TodoNotifier.init falhou: $e');
      _available = false;
    }
  }

  /// Permissão de notificações (API 33+). Retorna true se concedida ou não necessária.
  Future<bool> requestPermission() async {
    if (!_available) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> schedule(int taskId, String title, String description, DateTime due) async {
    if (!_available) return;
    await _plugin.zonedSchedule(
      TodoRepository.notificationIdFor(taskId),
      title,
      description,
      tz.TZDateTime.from(due, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Lembretes de tarefas',
          channelDescription: 'Notificações de vencimento das tarefas',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancel(int taskId) async {
    if (!_available) return;
    await _plugin.cancel(TodoRepository.notificationIdFor(taskId));
  }
}

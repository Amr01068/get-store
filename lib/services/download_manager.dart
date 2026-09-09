import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_model.dart';

enum DownloadStatus { idle, pending, downloading, installing, installed, error }

class AppDownloadTask {
  final AppModel app;
  double progress;
  DownloadStatus status;
  CancelToken? cancelToken;
  String? savePath;
  String? errorMessage;
  int notificationId;

  AppDownloadTask({
    required this.app,
    this.progress = 0.0,
    this.status = DownloadStatus.idle,
    this.cancelToken,
    this.savePath,
    this.errorMessage,
    required this.notificationId,
  });
}

class DownloadManager extends ChangeNotifier {
  static final DownloadManager instance = DownloadManager._internal();
  DownloadManager._internal();

  final Map<String, AppDownloadTask> _tasks = {};
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isNotificationsInitialized = false;

  Map<String, AppDownloadTask> get tasks => _tasks;

  AppDownloadTask? getTask(String appId) => _tasks[appId];

  Future<void> initNotifications() async {
    if (_isNotificationsInitialized) return;
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Notification tapped logic
      },
    );

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    _isNotificationsInitialized = true;
  }

  Dio _createDio() {
    final dio = Dio();
    if (!kIsWeb) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
      );
    }
    return dio;
  }

  Future<void> startDownload(AppModel app, String resolvedDirectUrl, Map<String, String> headers) async {
    await initNotifications();

    final notifId = app.id.hashCode.abs();
    final cancelToken = CancelToken();

    final task = AppDownloadTask(
      app: app,
      progress: 0.0,
      status: DownloadStatus.downloading,
      cancelToken: cancelToken,
      notificationId: notifId,
    );

    _tasks[app.id] = task;
    notifyListeners();

    try {
      final dio = _createDio();
      dio.options.headers = headers;
      dio.options.followRedirects = true;
      dio.options.maxRedirects = 10;

      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/${app.id}.apk';
      task.savePath = savePath;

      // Show initial notification
      _updateNotification(task);

      int lastNotificationTime = 0;

      await dio.download(
        resolvedDirectUrl,
        savePath,
        cancelToken: cancelToken,
        options: Options(
          headers: headers,
          followRedirects: true,
          maxRedirects: 10,
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            task.progress = (received / total).clamp(0.0, 1.0);
            task.status = DownloadStatus.downloading;
            notifyListeners();

            // Throttle notifications update to max 1 per 500ms
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastNotificationTime > 500) {
              lastNotificationTime = now;
              _updateNotification(task);
            }
          }
        },
      );

      // Verify file integrity
      final file = File(savePath);
      final fileSize = await file.length();
      if (fileSize < 1000) {
        throw Exception('الملف المحمّل غير صالح');
      }

      // Save metadata JSON sidecar for Storage Vault
      final metaFile = File('${dir.path}/${app.id}.json');
      await metaFile.writeAsString('''{
  "id": "${app.id}",
  "name": "${app.name.replaceAll('"', '\\"')}",
  "iconUrl": "${app.iconUrl}",
  "developerName": "${app.developerName.replaceAll('"', '\\"')}",
  "packageName": "${app.packageName}",
  "size": "${app.size}"
}''');

      // Complete download -> Launch package installer
      task.progress = 1.0;
      task.status = DownloadStatus.installed;
      notifyListeners();

      _showCompletedNotification(task);

      // Launch package installer
      await OpenFilex.open(savePath);
      notifyListeners();

    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _cancelNotification(task.notificationId);
        _tasks.remove(app.id);
      } else {
        task.status = DownloadStatus.error;
        task.errorMessage = e.toString();
        _showErrorNotification(task);
      }
      notifyListeners();
    }
  }

  void cancelDownload(String appId) {
    final task = _tasks[appId];
    if (task != null) {
      try {
        task.cancelToken?.cancel('Cancelled by user');
      } catch (_) {}
      _cancelNotification(task.notificationId);
      _tasks.remove(appId);
      notifyListeners();
    }
  }

  Future<void> _updateNotification(AppDownloadTask task) async {
    final percentInt = (task.progress * 100).round();
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'تنزيلات GET STORE',
      channelDescription: 'إشعارات التنزيل المباشر والتحديثات',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: percentInt,
      ongoing: true,
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      task.notificationId,
      task.app.name,
      'جاري التنزيل... $percentInt%',
      notificationDetails,
      payload: task.app.id,
    );
  }

  Future<void> _showCompletedNotification(AppDownloadTask task) async {
    final androidDetails = const AndroidNotificationDetails(
      'download_channel',
      'تنزيلات GET STORE',
      channelDescription: 'إشعارات التنزيل المباشر والتحديثات',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      task.notificationId,
      task.app.name,
      'اكتمل التنزيل! جاري فتح التثبيت...',
      notificationDetails,
      payload: task.app.id,
    );
  }

  Future<void> _showErrorNotification(AppDownloadTask task) async {
    final androidDetails = const AndroidNotificationDetails(
      'download_channel',
      'تنزيلات GET STORE',
      channelDescription: 'إشعارات التنزيل المباشر والتحديثات',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      task.notificationId,
      task.app.name,
      'فشل التنزيل. اضغط لإعادة المحاولة.',
      notificationDetails,
      payload: task.app.id,
    );
  }

  Future<void> _cancelNotification(int notificationId) async {
    await _notificationsPlugin.cancel(notificationId);
  }
}

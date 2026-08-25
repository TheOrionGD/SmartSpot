// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

Future<bool> requestWebNotificationPermission() async {
  try {
    final status = await html.Notification.requestPermission();
    return status == 'granted';
  } catch (e) {
    debugPrint('Error requesting web notification permission: $e');
    return false;
  }
}

Future<bool> hasWebNotificationPermission() async {
  try {
    return html.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

void showWebNotification(String title, String body) {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  } catch (e) {
    debugPrint('Error displaying web notification: $e');
  }
}

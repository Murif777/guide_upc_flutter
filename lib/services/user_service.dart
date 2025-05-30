import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class UserService {
  final String _baseUrl = kDebugMode 
      ? 'http://192.168.1.2:8080'
      : 'http://192.168.1.2:8080';

  Future<void> sendTelegramNotification(String location) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/telegram/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'location': location,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('Error sending notification: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to send notification: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
      throw Exception('Error sending notification: $e');
    }
  }

  Future<void> sendLocationHelp() async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return;
      }

      // Get current position
      final Position position = await Geolocator.getCurrentPosition();
      final String googleMapsLink = 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
      
      // Send notification with location
      await sendTelegramNotification(googleMapsLink);
      debugPrint('Notification sent successfully');
    } catch (e) {
      debugPrint('Error getting location or sending notification: $e');
    }
  }

  Future getUserName() async {}

  Future<void> saveUserName(String name) async {}
}

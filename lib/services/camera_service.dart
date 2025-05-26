import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CameraService {
  final String _baseUrl = 'http://localhost:8080'; // Production or web

  Future<Map<String, dynamic>> processImage(File imageFile) async {
    try {
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/process-image'),
      );

      // Add file to request
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: 'capture.png',
        ),
      );

      // Set timeout
      final response = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      // Process response
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final parsedData = jsonDecode(responseData);
        
        if (parsedData['results'] is String) {
          try {
            return jsonDecode(parsedData['results']);
          } catch (e) {
            debugPrint('Error parsing results: $e');
            return {'error': 'Failed to parse results'};
          }
        }
        
        return parsedData['results'];
      } else {
        debugPrint('Error processing image: ${response.statusCode} - $responseData');
        return {
          'error': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      return {
        'error': 'Error processing image: $e',
      };
    }
  }
}

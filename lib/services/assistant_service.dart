import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AssistantService {
  // Corregida la URL - agregada la '/' faltante después de 'http:'
  //final String _baseUrl = 'http://localhost:8080';

  Future<String> enviarConsulta(String texto) async {
    try {
      final url = 'http://192.168.1.2:8080/api/ia-navegacion/consulta';
      debugPrint('Enviando consulta a: $url');
      debugPrint('Texto: $texto');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'texto': texto,
        }),
      );
      
      debugPrint('Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.body;
      } else {
        debugPrint('Error response: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to send query: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending query to assistant: $e');
      throw Exception('Error al enviar consulta al asistente: $e');
    }
  }
}
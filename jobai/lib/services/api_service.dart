import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/resume_data.dart';

class ApiService {
  /// The backend URL. Automatically detects platform.
  static String get baseUrl {
    // On web, use localhost
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    // On Android emulator, use special IP
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {
      // Platform might not be available in some contexts
    }

    // Default for iOS simulator, desktop, etc.
    return 'http://localhost:8000';
  }

  /// Extract resume data from PDF file (mobile/desktop only)
  Future<ResumeData> extractResume(File pdfFile) async {
    if (kIsWeb) {
      throw Exception(
        'File path not supported on web. Use extractResumeFromBytes instead.',
      );
    }

    try {
      print(
        '[ApiService] extractResume -> baseUrl = $baseUrl, file=${pdfFile.path}',
      );

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/extract-resume'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('resume', pdfFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('[ApiService] response status=${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ResumeData.fromJson(jsonData);
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['detail'] ?? 'Failed to process resume');
        } catch (err) {
          print('[ApiService] non-json error body: ${response.body}');
          throw Exception(
            'Failed to process resume: ${response.statusCode} ${response.body}',
          );
        }
      }
    } catch (e) {
      print('[ApiService] extractResume error: $e');
      throw Exception('Error: $e');
    }
  }

  /// Extract resume data from raw bytes (works on all platforms including web)
  Future<ResumeData> extractResumeFromBytes(
    Uint8List bytes,
    String filename,
  ) async {
    try {
      print(
        '[ApiService] extractResumeFromBytes -> baseUrl = $baseUrl, file=$filename, bytes=${bytes.length}',
      );

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/extract-resume'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('resume', bytes, filename: filename),
      );

      print('[ApiService] Sending request...');
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - backend might not be running');
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      print('[ApiService] response status=${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('[ApiService] ✅ Success! Received resume data');
        return ResumeData.fromJson(jsonData);
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['detail'] ?? 'Failed to process resume');
        } catch (err) {
          print('[ApiService] non-json response: ${response.body}');
          throw Exception(
            'Failed to process resume: ${response.statusCode} ${response.body}',
          );
        }
      }
    } catch (e) {
      print('[ApiService] extractResumeFromBytes error: $e');

      // Provide more helpful error messages
      if (e.toString().contains('Failed host lookup')) {
        throw Exception(
          'Cannot connect to backend. Make sure it\'s running on $baseUrl',
        );
      } else if (e.toString().contains('Connection refused')) {
        throw Exception(
          'Backend is not running. Start it with: uvicorn main:app --reload',
        );
      } else if (e.toString().contains('timeout')) {
        throw Exception(
          'Backend is taking too long to respond. Check if it\'s running properly.',
        );
      }

      throw Exception('Error: $e');
    }
  }

  /// Health check
  Future<bool> checkHealth() async {
    try {
      print('[ApiService] Checking health at $baseUrl/health');

      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception('Health check timeout');
            },
          );

      print('[ApiService] Health check status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[ApiService] Health check failed: $e');
      return false;
    }
  }
}

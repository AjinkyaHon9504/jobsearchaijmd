import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/job.dart';

class JSearchService {
  // Replace with your actual RapidAPI key
  static const String _apiKey = 'e607abf28fmsh24e7f62929aa90ep101f39jsndc2c8285f3ed';
  static const String _baseUrl = 'https://jsearch.p.rapidapi.com';

  /// Search for jobs based on query and filters
  Future<List<Job>> searchJobs({
    required String query,
    String? location,
    int numPages = 1,
    String? datePosted, // today, 3days, week, month, all
    String? jobType, // FULLTIME, CONTRACTOR, PARTTIME, INTERN
  }) async {
    try {
      // Build query parameters
      final queryParams = {
        'query': query,
        'num_pages': numPages.toString(),
      };

      if (location != null && location.isNotEmpty) {
        queryParams['country'] = 'us';
        queryParams['location'] = location;
      }

      if (datePosted != null) {
        queryParams['date_posted'] = datePosted;
      }

      if (jobType != null) {
        queryParams['employment_types'] = jobType;
      }

      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: queryParams,
      );

      print('[JSearch] Searching: $query${location != null ? " in $location" : ""}');

      final response = await http.get(
        uri,
        headers: {
          'X-RapidAPI-Key': _apiKey,
          'X-RapidAPI-Host': 'jsearch.p.rapidapi.com',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('[JSearch] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final jobsData = data['data'] as List<dynamic>? ?? [];
        
        print('[JSearch] Found ${jobsData.length} jobs');

        return jobsData.map((json) => Job.fromJSearchJson(json)).toList();
      } else {
        print('[JSearch] Error: ${response.body}');
        throw Exception('Failed to fetch jobs: ${response.statusCode}');
      }
    } catch (e) {
      print('[JSearch] Error: $e');
      throw Exception('Error searching jobs: $e');
    }
  }

  /// Search jobs based on resume keywords
  Future<List<Job>> searchJobsFromResume({
    required List<String> skills,
    required List<String> jobTitles,
    String? location,
    String experienceLevel = '',
  }) async {
    try {
      // Create search query from top skills and job titles
      String query = '';
      
      if (jobTitles.isNotEmpty) {
        query = jobTitles.first; // Use primary job title
      } else if (skills.isNotEmpty) {
        query = '${skills.take(3).join(" ")} developer';
      } else {
        query = 'software developer';
      }

      print('[JSearch] Searching with resume query: $query');

      return await searchJobs(
        query: query,
        location: location,
        numPages: 1,
        datePosted: 'week', // Recent postings
      );
    } catch (e) {
      print('[JSearch] Error in resume search: $e');
      return [];
    }
  }
}
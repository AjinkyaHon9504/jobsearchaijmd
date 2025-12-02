import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../app_globals.dart';
import '../services/api_service.dart';
import '../services/jsearch_service.dart';
import '../models/resume_data.dart';
import '../models/job.dart';
import '../widgets/job_card.dart';
import '../data/sample_jobs.dart';

class DashboardPage extends StatefulWidget {
  final void Function(ResumeData resumeData, String? fileName)? onUpload;
  final ResumeData? resumeData;

  const DashboardPage({Key? key, this.onUpload, this.resumeData})
    : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _apiService = ApiService();
  final JSearchService _jSearchService = JSearchService();

  bool _isUploading = false;
  bool _isLoadingJobs = false;
  List<Job> _jobs = [];
  String? _errorMessage;
  bool _isUsingApiJobs = false; // Track if showing API or sample jobs
  String? _searchQuery; // Track what was searched

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resumeData != oldWidget.resumeData &&
        widget.resumeData != null) {
      print('🔄 [Dashboard] Resume data changed, reloading jobs...');
      _loadJobs();
    }
  }

  Future<void> _loadJobs() async {
    if (widget.resumeData != null) {
      await _loadJobsFromResume();
    } else {
      print('📋 [Dashboard] No resume data, showing sample jobs');
      setState(() {
        _jobs = sampleJobs;
        _isUsingApiJobs = false;
        _searchQuery = null;
      });
    }
  }

  Future<void> _loadJobsFromResume() async {
    setState(() {
      _isLoadingJobs = true;
      _errorMessage = null;
    });

    try {
      final resumeData = widget.resumeData!;

      print('📊 [Dashboard] Resume Data:');
      print('  - Name: ${resumeData.contactInfo.name}');
      print('  - Skills: ${resumeData.searchKeywords.primarySkills}');
      print('  - Job Titles: ${resumeData.searchKeywords.jobTitles}');
      print('  - Experience: ${resumeData.searchKeywords.experienceLevel}');
      print('  - Location: ${resumeData.jobPreferences.preferredLocations}');

      // Build search query
      String searchQuery = '';
      if (resumeData.searchKeywords.jobTitles.isNotEmpty) {
        searchQuery = resumeData.searchKeywords.jobTitles.first;
        print('🔍 [Dashboard] Using job title: $searchQuery');
      } else if (resumeData.searchKeywords.primarySkills.isNotEmpty) {
        searchQuery =
            '${resumeData.searchKeywords.primarySkills.take(2).join(" ")} developer';
        print('🔍 [Dashboard] Using skills: $searchQuery');
      } else {
        searchQuery = 'software developer';
        print('🔍 [Dashboard] Using fallback: $searchQuery');
      }

      print('🌐 [Dashboard] Calling JSearch API...');

      final jobs = await _jSearchService.searchJobsFromResume(
        skills: resumeData.searchKeywords.primarySkills,
        jobTitles: resumeData.searchKeywords.jobTitles,
        location: resumeData.jobPreferences.preferredLocations.isNotEmpty
            ? resumeData.jobPreferences.preferredLocations.first
            : null,
        experienceLevel: resumeData.searchKeywords.experienceLevel,
      );

      print('✅ [Dashboard] API returned ${jobs.length} jobs');

      if (jobs.isNotEmpty) {
        // Show first 3 job titles for verification
        print('📝 [Dashboard] Sample job titles:');
        for (var i = 0; i < (jobs.length > 3 ? 3 : jobs.length); i++) {
          print('  ${i + 1}. ${jobs[i].title} at ${jobs[i].company}');
        }
      }

      setState(() {
        _jobs = jobs.isNotEmpty ? jobs : sampleJobs;
        _isLoadingJobs = false;
        _isUsingApiJobs = jobs.isNotEmpty;
        _searchQuery = searchQuery;
      });

      if (jobs.isNotEmpty) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              '✅ Found ${jobs.length} real jobs matching your resume!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        print('⚠️ [Dashboard] No jobs found, using sample jobs');
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('⚠️ No matching jobs found. Showing sample jobs.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ [Dashboard] Error loading jobs: $e');
      setState(() {
        _isLoadingJobs = false;
        _errorMessage = e.toString();
        _jobs = sampleJobs;
        _isUsingApiJobs = false;
      });

      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('API Error: Using sample jobs. ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _uploadResumeAndOpenChat() async {
    try {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Selecting resume...')),
      );

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null) return;

      if (result.files.single.bytes == null &&
          result.files.single.path == null) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Could not read file'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isUploading = true);

      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Processing resume...'),
          duration: Duration(seconds: 3),
        ),
      );

      final fileName = result.files.single.name;
      ResumeData resumeData;

      if (result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        resumeData = await _apiService.extractResumeFromBytes(bytes, fileName);
      } else if (result.files.single.path != null && !kIsWeb) {
        final filePath = result.files.single.path!;
        resumeData = await _apiService.extractResume(File(filePath));
      } else {
        throw Exception('No file data available');
      }

      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('✅ Resume processed! Loading matching jobs...'),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.onUpload != null) {
        widget.onUpload!(resumeData, fileName);
      }
    } catch (e) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Jobs',
            onPressed: _isLoadingJobs ? null : _loadJobs,
          ),
          IconButton(
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            tooltip: 'Upload Resume',
            onPressed: _isUploading ? null : _uploadResumeAndOpenChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status indicator banner
          if (_isUsingApiJobs || _errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: _isUsingApiJobs
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(
                    _isUsingApiJobs ? Icons.check_circle : Icons.warning,
                    color: _isUsingApiJobs ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isUsingApiJobs
                              ? '✅ Showing ${_jobs.length} real jobs from API'
                              : '⚠️ Showing sample jobs',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isUsingApiJobs
                                ? Colors.green.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                        if (_searchQuery != null)
                          Text(
                            'Search: "$_searchQuery"',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isUsingApiJobs)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Job list
          Expanded(
            child: _isLoadingJobs
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('🔍 Searching for matching jobs...'),
                        SizedBox(height: 8),
                        Text(
                          'This may take a few seconds',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadJobs,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _jobs.length,
                      itemBuilder: (context, index) {
                        return JobCard(job: _jobs[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

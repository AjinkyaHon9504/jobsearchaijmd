import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../app_globals.dart';
import '../services/api_service.dart';
import '../models/resume_data.dart';
import '../widgets/job_card.dart';
import '../data/sample_jobs.dart';

class DashboardPage extends StatefulWidget {
  final void Function(ResumeData resumeData, String? fileName)? onUpload;

  const DashboardPage({Key? key, this.onUpload}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _apiService = ApiService();
  bool _isUploading = false;

  Future<void> _uploadResumeAndOpenChat() async {
    try {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Selecting resume...')),
      );
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Force loading bytes (required for web)
      );

      if (result == null) {
        return;
      }

      // Check if we have bytes (works on all platforms)
      if (result.files.single.bytes == null && result.files.single.path == null) {
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

      // Use bytes first (works on web and mobile)
      if (result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        print('📄 Dashboard using bytes: ${bytes.length} bytes');
        resumeData = await _apiService.extractResumeFromBytes(bytes, fileName);
      } else if (result.files.single.path != null && !kIsWeb) {
        // Only use path on non-web platforms
        final filePath = result.files.single.path!;
        print('📄 Dashboard using file path: $filePath');
        resumeData = await _apiService.extractResume(File(filePath));
      } else {
        throw Exception('No file data available');
      }

      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('✅ Resume processed!'),
          backgroundColor: Colors.green,
        ),
      );
      
      if (widget.onUpload != null) {
        widget.onUpload!(resumeData, fileName);
      }
    } catch (e) {
      print('❌ Dashboard upload error: $e');
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
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Add filter
            },
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sampleJobs.length,
        itemBuilder: (context, index) {
          return JobCard(job: sampleJobs[index]);
        },
      ),
    );
  }
}
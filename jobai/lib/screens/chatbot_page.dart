import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/chat_message.dart';
import '../app_globals.dart';
import '../services/api_service.dart';
import '../models/resume_data.dart';

class ChatbotPage extends StatefulWidget {
  final ResumeData? initialResumeData;
  final String? uploadedFileName;
  final VoidCallback? onResumeCleared;

  const ChatbotPage({
    Key? key,
    this.initialResumeData,
    this.uploadedFileName,
    this.onResumeCleared,
  }) : super(key: key);

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ApiService _apiService = ApiService();

  String? _uploadedFileName;
  bool _isChatEnabled = false;
  bool _isProcessing = false;
  ResumeData? _resumeData;
  bool _showPinnedResume = false;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
    
    if (widget.initialResumeData != null) {
      _resumeData = widget.initialResumeData;
      _uploadedFileName = widget.uploadedFileName;
      _isChatEnabled = true;
      _showPinnedResume = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_resumeData != null) {
          _showResumeDataSummary(_resumeData!);
        }
      });
    }
  }

  Future<void> _checkBackendHealth() async {
    try {
      bool isHealthy = await _apiService.checkHealth();
      if (!mounted) return;
      
      if (isHealthy) {
        print('✅ Backend is running');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backend connected'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('❌ Backend not responding');
        _showBackendError();
      }
    } catch (e) {
      print('❌ Backend error: $e');
      if (mounted) _showBackendError();
    }
  }

  void _showBackendError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend Not Running'),
        content: const Text(
          'The backend server is not running.\n\n'
          'Please start it with:\n'
          'cd backend\n'
          'uvicorn main:app --reload\n\n'
          'Make sure it\'s running on http://localhost:8000',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkBackendHealth();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(ChatbotPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialResumeData != null && 
        widget.initialResumeData != oldWidget.initialResumeData) {
      setState(() {
        _resumeData = widget.initialResumeData;
        _uploadedFileName = widget.uploadedFileName;
        _isChatEnabled = true;
        _showPinnedResume = true;
        _messages.clear();
      });
      _showResumeDataSummary(widget.initialResumeData!);
    }
  }

  Future<void> _pickAndProcessPDF() async {
    print('📂 [ChatbotPage] Opening file picker...');
    
    // Show loading immediately
    setState(() {
      _isProcessing = true;
    });
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // IMPORTANT: Force loading bytes for web
      );

      if (result == null) {
        print('❌ [ChatbotPage] User cancelled file selection');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      print('✅ [ChatbotPage] File selected: ${result.files.single.name}');

      // On web, we MUST use bytes (path is not available)
      if (result.files.single.bytes == null) {
        print('❌ [ChatbotPage] No bytes available');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the selected file'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _uploadedFileName = result.files.single.name;
      });

      setState(() {
        _messages.add(
          ChatMessage(
            text: '⏳ Processing your resume... Please wait.',
            isUser: false,
          ),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Uploading and processing resume...'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );

      print('📤 [ChatbotPage] Sending to backend...');
      ResumeData resumeData;
      
      // Try bytes first (works on all platforms including web)
      if (result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final name = result.files.single.name;
        print('📄 Using bytes: ${bytes.length} bytes, name: $name');
        resumeData = await _apiService.extractResumeFromBytes(bytes, name);
      } else if (result.files.single.path != null) {
        // Fallback to path (only works on mobile/desktop)
        File pdfFile = File(result.files.single.path!);
        print('📄 Using file path: ${pdfFile.path}');
        resumeData = await _apiService.extractResume(pdfFile);
      } else {
        throw Exception('No file path or bytes available');
      }

      print('✅ [ChatbotPage] Resume parsed successfully!');
      
      setState(() {
        _resumeData = resumeData;
        _isProcessing = false;
        _isChatEnabled = true;
        _showPinnedResume = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Resume processed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _showResumeDataSummary(resumeData);
      
    } catch (e) {
      print('❌ [ChatbotPage] Error: $e');
      
      setState(() {
        _isProcessing = false;
        _uploadedFileName = null;
      });

      // Show detailed error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upload Failed'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error details:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(e.toString()),
                  const SizedBox(height: 16),
                  const Text('Troubleshooting:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('1. Make sure backend is running:\n   uvicorn main:app --reload'),
                  const SizedBox(height: 4),
                  const Text('2. Check backend URL in api_service.dart'),
                  const SizedBox(height: 4),
                  const Text('3. Verify PDF file is not corrupted'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _checkBackendHealth();
                },
                child: const Text('Check Backend'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      setState(() {
        _messages.add(
          ChatMessage(
            text: '❌ Error processing resume. Please check if the backend is running.',
            isUser: false,
          ),
        );
      });
    }
  }

  void _showResumeDataSummary(ResumeData data) {
    String summary = '''
✅ Resume processed successfully!

📋 Name: ${data.contactInfo.name ?? 'Not found'}
📧 Email: ${data.contactInfo.email ?? 'Not found'}
💼 Experience: ${data.experience.totalYears} years
🎯 Skills: ${data.skills.allSkills.take(5).join(', ')}${data.skills.allSkills.length > 5 ? '...' : ''}

Suggested Job Titles:
${data.searchKeywords.jobTitles.take(3).map((t) => '• $t').join('\n')}

I'm ready to help you find jobs! What are you looking for?
''';

    setState(() {
      _messages.add(ChatMessage(text: summary, isUser: false));
    });
  }

  Widget _buildPinnedResume(ResumeData data) {
    return Dismissible(
      key: const ValueKey('pinned_resume'),
      direction: DismissDirection.up,
      onDismissed: (_) => setState(() => _showPinnedResume = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.contactInfo.name ?? 'Name not found',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Skills: ${data.skills.allSkills.take(6).join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Suggested: ${data.searchKeywords.jobTitles.take(3).join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _showPinnedResume = false),
            ),
          ],
        ),
      ),
    );
  }

  void _clearResume() {
    setState(() {
      _uploadedFileName = null;
      _isChatEnabled = false;
      _resumeData = null;
      _messages.clear();
      _showPinnedResume = false;
    });
    widget.onResumeCleared?.call();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resume cleared')),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: _messageController.text, isUser: true));
    });

    String userQuery = _messageController.text;
    _messageController.clear();

    Future.delayed(const Duration(seconds: 1), () {
      String response = _generateResponse(userQuery);
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
      });
    });
  }

  String _generateResponse(String query) {
    if (_resumeData == null) {
      return "Please upload your resume first.";
    }

    query = query.toLowerCase();

    if (query.contains('skill')) {
      return "Your top skills:\n${_resumeData!.skills.allSkills.take(10).map((s) => '• $s').join('\n')}";
    }

    if (query.contains('job') || query.contains('position')) {
      return "Suitable job titles:\n${_resumeData!.searchKeywords.jobTitles.map((t) => '• $t').join('\n')}";
    }

    if (query.contains('experience')) {
      return "You have ${_resumeData!.experience.totalYears} years of experience.\nPositions: ${_resumeData!.experience.positions.join(', ')}";
    }

    return "I'm analyzing job opportunities. Check the Dashboard tab!";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Job Assistant'),
        actions: [
          // Backend status indicator
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_uploadedFileName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                avatar: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(
                  _uploadedFileName!.length > 15
                      ? '${_uploadedFileName!.substring(0, 15)}...'
                      : _uploadedFileName!,
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: _isProcessing ? null : _clearResume,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_resumeData != null && _showPinnedResume)
            _buildPinnedResume(_resumeData!),
            
          if (_uploadedFileName == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 80,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Upload Your Resume',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Upload your resume to activate the AI assistant',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _pickAndProcessPDF,
                      icon: _isProcessing 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(_isProcessing ? 'Processing...' : 'Upload Resume (PDF)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _checkBackendHealth,
                      icon: const Icon(Icons.health_and_safety, size: 16),
                      label: const Text('Check Backend Connection'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _messages[index],
              ),
            ),

          if (_isChatEnabled && !_isProcessing)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ask about jobs...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    mini: true,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
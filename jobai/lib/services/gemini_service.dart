// lib/services/gemini_service.dart
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/resume_data.dart';

/// IMPORTANT: Do NOT hardcode your real API key here.
/// Use environment variables (flutter_dotenv) or secure storage and
/// pass the key to GeminiService via constructor.
class GeminiService {
  final String apiKey; // Injected; prevents hardcoding
  late final GenerativeModel _model;
  late ChatSession _chat;

  // Local memory of job titles the user has explicitly added in-chat
  final List<String> _userJobTitles = [];

  GeminiService({required this.apiKey, String modelName = 'gemini-2.5-flash'}) {
    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
    );
    _chat = _model.startChat(history: []);
  }

  /// Initialize a new chat session with resume context and optional target job
  void startNewChat(ResumeData resumeData, {String? jobTitle}) {
    final String systemInstruction = _buildSystemInstruction(resumeData, jobTitle);
    _chat = _model.startChat(
      history: [
        Content.model([TextPart(systemInstruction)]),
      ],
    );
  }

  String _buildSystemInstruction(ResumeData data, String? jobTitle) {
    final name = data.contactInfo.name ?? 'N/A';
    final totalExp = data.experience.totalYears;
    final skillsPreview = data.skills.allSkills.isNotEmpty
        ? data.skills.allSkills.take(10).join(', ')
        : 'Not found';
    final positionsPreview = data.experience.positions.isNotEmpty
        ? data.experience.positions.join('; ')
        : 'Not found';
    final job = jobTitle ?? 'Not Specified';

    return '''
You are an AI Job Assistant. Keep responses concise and helpful.
Resume context (do not reveal raw personal contact info): 
Name: $name
Total Experience: $totalExp years
Top Skills: $skillsPreview
Experience Summary: $positionsPreview
CURRENT TARGET JOB TITLE: $job

When asked to evaluate roles, compare against the resume and give:
1) A short suitability score (High / Medium / Low) with 1-2 reasons.
2) Suggested improvements to match the role (1-3 bullets).
3) If asked for company-specific titles, propose 5-8 typical job titles that company might list for this profile and tag each with suitability.
Be professional and do not reveal or output the user's raw resume beyond short summaries.
''';
  }

  /// Sends a message to Gemini and returns the text reply.
  Future<String> sendMessage(String message) async {
    try {
      final response = await _chat.sendMessage(Content.text(message));
      return response.text ?? 'No response from Gemini.';
    } catch (e) {
      return 'Gemini API error: $e';
    }
  }

  /// Adds a custom job title to local memory (user-specified via chat)
  /// Returns a confirmation string for UI display.
  Future<String> addCustomJobTitle(String title, {ResumeData? resume}) async {
    final normalized = title.trim();
    if (normalized.isEmpty) return 'Please provide a non-empty job title.';
    if (!_userJobTitles.contains(normalized)) {
      _userJobTitles.add(normalized);
    } else {
      return 'Job title "$normalized" already saved.';
    }

    // Optionally update chat context to use the new job title as target
    if (resume != null) {
      startNewChat(resume, jobTitle: normalized);
    }

    return 'Added "$normalized" as a target job title.';
  }

  /// Returns the list of user-added job titles
  List<String> getUserJobTitles() => List.unmodifiable(_userJobTitles);

  /// Ask Gemini for job titles relevant to a specific company and evaluate suitability
  /// Uses AI-only approach: Gemini will propose company-specific titles and score them
  Future<String> getCompanyJobTitles(String companyName, ResumeData resumeData) async {
    final prompt = '''
You are asked to propose job titles at "$companyName" that could match the provided resume.
1) Propose 6-8 job titles commonly advertised by $companyName (short list).
2) For each title, give a one-line suitability (High/Medium/Low) and 1 short reason referencing the resume (skills or experience).
3) At the end, give 2 concrete suggestions the candidate can do to improve suitability for the top recommended title.

Resume summary (short): 
- Years: ${resumeData.experience.totalYears}
- Top skills: ${resumeData.skills.allSkills.take(8).join(', ')}
- Recent positions: ${resumeData.experience.positions.take(4).join('; ')}

Keep the answer concise and use bullet points.
''';

    // Send as a new message to the existing chat session
    try {
      final response = await _chat.sendMessage(Content.text(prompt));
      return response.text ?? 'No response from Gemini.';
    } catch (e) {
      return 'Gemini API error: $e';
    }
  }
}

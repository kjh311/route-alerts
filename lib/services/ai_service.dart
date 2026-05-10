import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  GenerativeModel? _model;

  void init() {
    final apiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-3.1-flash-lite',
        apiKey: apiKey,
      );
    }
  }

  Future<String> generateWeatherBriefing(Map<String, dynamic> weatherData) async {
    if (_model == null) {
      init();
      if (_model == null) return "AI Summary unavailable (API Key missing).";
    }

    try {
      final today = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
      
      final prompt = [
        Content.text(
          'You are an expert heavy-haul trucking dispatcher. Today is $today. Using the provided weather JSON, generate a safety briefing with these exact requirements:\n\n'
          '1. Start with: "Here is your route summary for $today."\n'
          '2. Provide the High and Low temperatures for the overall route.\n'
          '3. Identify any hazards: Specifically call out wind gusts >30mph, ice, snow, heavy rain, fog, or tornado risks. Mention the specific city and estimated time for each.\n'
          '4. Professional Tone: Keep it to 3-4 sentences total. Use trucker lingo (e.g., "keep the shiny side up," "watch your following distance").\n'
          '5. End with: "Safe driving," or "Have a good day."\n\n'
          'Weather Data: ${jsonEncode(weatherData)}'
        )
      ];

      final response = await _model!.generateContent(prompt);
      return response.text ?? 'Audit complete. No significant hazards found.';
    } catch (e) {
      return 'AI Briefing failed: ${e.toString()}';
    }
  }
}

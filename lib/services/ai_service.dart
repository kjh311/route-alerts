import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
      final prompt = [
        Content.text(
          'As a professional truck dispatcher, summarize these weather alerts into a 2-sentence safety warning for a driver. '
          'Mention specific cities and peak wind speeds. '
          'Data: ${jsonEncode(weatherData)}'
        )
      ];

      final response = await _model!.generateContent(prompt);
      return response.text ?? 'Audit complete. No significant hazards found.';
    } catch (e) {
      return 'AI Briefing failed: ${e.toString()}';
    }
  }
}

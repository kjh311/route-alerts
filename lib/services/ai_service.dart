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

  Future<String> generateWeatherBriefing(Map<String, dynamic> weatherData, [Map<String, dynamic>? delayData]) async {
    if (_model == null) {
      init();
      if (_model == null) return "AI Summary unavailable (API Key missing).";
    }

    try {
      final today = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
      
      final prompt = [
        Content.text(
          'You are an expert heavy-haul trucking dispatcher. Today is $today. Using the provided weather JSON and the processed route delay data, generate a safety briefing with these exact requirements:\n\n'
          '1. Start with: "Safety briefing for $today:"\n'
          '2. Route Status Flag: If the weather is all clear and there are no critical delays, provide a green flag: ✅. If the weather is cautionary or there are minor/persistent delays, provide a yellow flag: 🟨. If the weather is highly hazardous (e.g., severe storms, high winds, or full road closures), provide a red flag: 🚩. Provide the High and Low temperatures for the overall route, as well as the times for each.\n'
          '3. Identify Weather Hazards: Specifically call out wind gusts >25mph, freezing temps, ice, snow, rain, fog, or tornado risks. Mention the specific city/cities and estimated time range for each. If there are excessive winds > 30 mph suggest a heavy load. If there are winds > 40 mph suggest not driving. If there are very hazardous weather conditions suggest not driving.\n'
          '4. Integrate Live & Historical Traffic Delays: Scan the route delay data for both travel directions. Explicitly call out any active disruptions by their specific highway, travel heading, and mile markers (e.g., "I-40 Eastbound, Mile Marker 120 to 124"). Differentiate between history states: If a delay is flagged as persistent (is_persistent: true), note it as a known backup carried over from yesterday so the driver knows it is a dragging construction zone. If it is flagged as new (is_new: true), warn them of a fresh, sudden bottleneck.\n'
          '5. Professional Tone & Length: Keep the entire briefing concise (around 6–8 sentences total). Use clear trucker lingo (e.g., "keep the shiny side up," "watch your following distance," "hammer down safely").\n'
          '6. End with: "Safe driving," or "Have a good day."\n\n'
          'Weather Data: ${jsonEncode(weatherData)}\n'
          'Traffic Delay Data: ${jsonEncode(delayData ?? {})}'
        )
      ];

      final response = await _model!.generateContent(prompt);
      return response.text ?? 'Audit complete. No significant hazards found.';
    } catch (e) {
      return 'AI Briefing failed: ${e.toString()}';
    }
  }
}

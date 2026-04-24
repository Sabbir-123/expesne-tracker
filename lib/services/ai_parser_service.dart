import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiParserService {
  String get _apiKey => dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
  static const String _url = 'https://openrouter.ai/api/v1/chat/completions';

  Future<Map<String, dynamic>> parseTransaction(String transcript) async {
    final t = transcript.toLowerCase().trim();
    
    // STEP 1: Fast Local Regex Processing
    final localParseResult = _tryLocalParse(t);
    if (localParseResult != null) {
      return localParseResult;
    }

    // STEP 2: Fallback to AI Parser if local fails
    return await _callCloudDeepSeek(transcript);
  }

  Map<String, dynamic>? _tryLocalParse(String text) {
    // Basic heuristics
    String type = 'expense';
    if (text.startsWith('received') ||
        text.startsWith('earned') ||
        text.startsWith('salary') ||
        text.startsWith('got paid')) {
      type = 'income';
    }

    // Extract amount
    final amountRegex = RegExp(r'\$?\s*(\d+(?:\.\d+)?)\s*(dollars?|tk|taka|rupees?|lira)?');
    final match = amountRegex.firstMatch(text);
    if (match == null) return null; // Fallback to AI if no amount found locally

    double amount = double.tryParse(match.group(1) ?? '0') ?? 0;
    
    String currency = 'USD';
    final curMatch = match.group(2);
    if (curMatch != null) {
      if (curMatch.startsWith('tk') || curMatch.startsWith('taka')) currency = 'BDT';
      else if (curMatch.startsWith('rupee')) currency = 'INR';
      else if (curMatch.startsWith('lira')) currency = 'TRY';
    } else if (text.contains('tk') || text.contains('taka')) {
       currency = 'BDT';
    } else if (text.contains('rupee')) {
       currency = 'INR';
    }

    // Extract Category
    String category = 'Miscellaneous';
    if (text.contains('coffee') || text.contains('lunch') || text.contains('food') || text.contains('burger') || text.contains('groceries')) {
      category = 'Food';
    } else if (text.contains('uber') || text.contains('bus') || text.contains('rickshaw') || text.contains('transport') || text.contains('taxi')) {
      category = 'Transport';
    } else if (text.contains('salary') || text.contains('payment') || text.contains('client')) {
      category = 'Income';
    } else if (text.contains('shopping') || text.contains('store') || text.contains('mall')) {
      category = 'Shopping';
    } else if (text.contains('rent') || text.contains('bill')) {
      category = 'Bills';
    }

    // Remove amount/keywords to leave a clean note text
    String note = text
        .replaceAll(amountRegex, '')
        .replaceAll(RegExp(r'(spent|paid|bought|received|earned|got|for|on|my)'), '')
        .trim();
        
    if (note.isEmpty) {
       note = category; // fallback note
    }

    return {
      "type": type,
      "amount": amount,
      "currency": currency,
      "category": category,
      "note": note
    };
  }

  Future<Map<String, dynamic>> _callCloudDeepSeek(String transcript) async {
    final key = _apiKey.trim();
    if (key.isEmpty || key == 'YOUR_OPEN_ROUTER_KEY') {
       throw Exception("No valid OpenRouter Key. Local parse failed.");
    }
  
    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'Authorization': 'Bearer \$key',
        'HTTP-Referer': 'https://speakspend.app',
        'X-OpenRouter-Title': 'SpeakSpend App',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "deepseek/deepseek-chat",
        "response_format": {"type": "json_object"},
        "messages": [
          {
            "role": "system",
            "content": """
Convert expense text into JSON only.
Return ONLY JSON:
{
  "type":"expense",
  "amount":5,
  "currency":"USD",
  "category":"Food",
  "note":"coffee"
}
Must support: Bangla, English, Hindi, mixed language.
Examples:
kal 200 rupees uber diyechi -> {"type":"expense", "amount":200, "currency":"INR", "category":"Transport", "note":"uber"}
            """
          },
          {
            "role": "user",
            "content": transcript
          }
        ]
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String content = data['choices'][0]['message']['content'];
      
      // Clean markdown codeblocks
      content = content.replaceAll(RegExp(r'```json'), '').replaceAll(RegExp(r'```'), '').trim();
      
      return jsonDecode(content) as Map<String, dynamic>;
    } else {
      throw Exception('DeepSeek API Error: \${response.statusCode} - \${response.body}');
    }
  }
}

final aiParserServiceProvider = Provider((ref) => AiParserService());

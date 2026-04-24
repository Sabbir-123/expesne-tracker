import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class WhisperService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  String? _currentPath;
  String _fallbackTranscript = '';
  bool _useFallback = false;

  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<void> _checkApiKey() async {
    final key = _apiKey.trim();
    if (key.isEmpty || key == 'YOUR_OPENAI_KEY') {
      _useFallback = true;
    }
  }

  Future<String> startRecording() async {
    await _checkApiKey();

    if (_useFallback) {
      debugPrint("OPENAI_API_KEY Missing. Falling back to native SpeechToText...");
      bool available = await _speech.initialize(
        onStatus: (status) => debugPrint('STT Status: \$status'),
        onError: (err) => debugPrint('STT Error: \$err'),
      );
      if (available) {
        _fallbackTranscript = '';
        await _speech.listen(
          onResult: (result) {
            if (result.finalResult || result.recognizedWords.isNotEmpty) {
               _fallbackTranscript = result.recognizedWords;
            }
          },
          listenMode: stt.ListenMode.dictation,
        );
        return 'fallback_stream';
      } else {
        throw Exception('Native Speech Recognition unavailable.');
      }
    }

    // Normal Whisper Record Process
    if (await _audioRecorder.hasPermission()) {
      if (kIsWeb) {
        _currentPath = '';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.opus), path: _currentPath!);
        return 'web_stream';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = '\${const Uuid().v4()}.m4a';
        _currentPath = '\${dir.path}/\$fileName';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _currentPath!);
        return _currentPath!;
      }
    } else {
      throw Exception('Microphone permission denied');
    }
  }

  Future<String> stopRecording() async {
    if (_useFallback) {
      await _speech.stop();
      // Give native speech reco a moment to finalize
      await Future.delayed(const Duration(milliseconds: 500));
      return _fallbackTranscript; // Return the transcript text directly encoded for the parser to catch
    }

    final path = await _audioRecorder.stop();
    return path ?? _currentPath ?? '';
  }

  Future<String> transcribeAudio(String pathOrText) async {
    if (_useFallback) {
      debugPrint("Returning STT Fallback Transcript: \$pathOrText");
      if (pathOrText.isEmpty || pathOrText == "fallback_stream") {
          throw Exception("Could not hear clearly.");
      }
      return pathOrText; 
    }

    final key = _apiKey.trim();
    if (key.isEmpty || key == 'YOUR_OPENAI_KEY') {
       throw Exception("Voice API key missing");
    }

    final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer \$key';

    request.fields['model'] = 'whisper-1';

    if (kIsWeb) {
       final response = await http.get(Uri.parse(pathOrText));
       request.files.add(http.MultipartFile.fromBytes('file', response.bodyBytes, filename: 'audio.weba'));
    } else {
       request.files.add(await http.MultipartFile.fromPath('file', pathOrText, filename: 'audio.m4a'));
    }

    final streamlinedResponse = await request.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamlinedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['text'] ?? '';
    } else {
      if (response.statusCode == 401) {
         throw Exception("Voice API key invalid (401 Unauthorized)");
      }
      throw Exception('Whisper error: \${response.statusCode}');
    }
  }

  void dispose() {
    _audioRecorder.dispose();
    _speech.cancel();
  }
}

final whisperServiceProvider = Provider((ref) => WhisperService());

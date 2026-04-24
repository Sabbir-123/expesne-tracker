import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/whisper_service.dart';
import '../services/ai_parser_service.dart';
import '../services/firebase_transaction_service.dart';
import '../models/transaction_model.dart';
import 'package:flutter/foundation.dart';

class VoiceExpenseState {
  final bool isListening;
  final bool isProcessing;
  final String transcript;
  final String error;

  VoiceExpenseState({
    this.isListening = false,
    this.isProcessing = false,
    this.transcript = '',
    this.error = '',
  });

  VoiceExpenseState copyWith({
    bool? isListening,
    bool? isProcessing,
    String? transcript,
    String? error,
  }) {
    return VoiceExpenseState(
      isListening: isListening ?? this.isListening,
      isProcessing: isProcessing ?? this.isProcessing,
      transcript: transcript ?? this.transcript,
      error: error ?? this.error,
    );
  }
}

class VoiceExpenseController extends StateNotifier<VoiceExpenseState> {
  final Ref ref;
  bool _isLocked = false;
  String? _lastProcessedTranscript;

  VoiceExpenseController(this.ref) : super(VoiceExpenseState());

  Future<void> startListening() async {
    if (_isLocked || state.isListening || state.isProcessing) return;
    _isLocked = true;

    debugPrint("VOICE STARTED");

    try {
      final whisper = ref.read(whisperServiceProvider);
      await whisper.startRecording();
      state = state.copyWith(isListening: true, error: '', transcript: '');
    } catch (e) {
      state = state.copyWith(error: 'Microphone permission denied');
      _clearError();
    } finally {
      _isLocked = false;
    }
  }

  Future<void> stopListeningAndProcess() async {
    if (_isLocked || !state.isListening || state.isProcessing) return;
    _isLocked = true;

    state = state.copyWith(isListening: false, isProcessing: true);
    
    debugPrint("PROCESS CALLED");

    try {
      final whisper = ref.read(whisperServiceProvider);
      final audioPath = await whisper.stopRecording();
      
      if (audioPath.isEmpty) {
        state = state.copyWith(isProcessing: false, error: 'Could not hear clearly');
        _clearError();
        _isLocked = false;
        return;
      }

      await processVoiceExpense(audioPath);
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: 'Could not hear clearly');
      _clearError();
      _isLocked = false;
    }
  }

  Future<void> processVoiceExpense(String audioPath) async {
    final whisper = ref.read(whisperServiceProvider);
    final parser = ref.read(aiParserServiceProvider);
    final firebase = ref.read(firebaseTransactionServiceProvider);

    try {
      // 1. Whisper transcript
      final finalTranscript = await whisper.transcribeAudio(audioPath);
      debugPrint("VOICE FINAL RESULT: \$finalTranscript");
      state = state.copyWith(transcript: finalTranscript);

      if (finalTranscript.trim().isEmpty) {
        state = state.copyWith(isProcessing: false, error: 'Could not hear clearly');
        _clearError();
        _isLocked = false;
        return;
      }
      
      // Duplication check locally
      if (_lastProcessedTranscript == finalTranscript.trim()) {
        debugPrint("PROCESS BLOCKED DUPLICATE: Local Transcript Matched");
        state = state.copyWith(isProcessing: false, error: 'Already processed this expense');
        _clearError();
        _isLocked = false;
        return;
      }
      
      // Lock it in for this session
      _lastProcessedTranscript = finalTranscript.trim();

      // 2. DeepSeek parse JSON
      final parsedJson = await parser.parseTransaction(finalTranscript);

      if (parsedJson.isEmpty) {
        state = state.copyWith(isProcessing: false, error: 'Could not parse transcript');
        _clearError();
        _isLocked = false;
        return;
      }

      // 3. Save to Firestore
      final tx = TransactionModel(
        id: '', // Will be assigned by Firestore
        uid: '', // Set by firebase_transaction_service
        type: parsedJson['type'] ?? 'expense',
        amount: (parsedJson['amount'] as num?)?.toDouble() ?? 0.0,
        currency: parsedJson['currency'] ?? 'USD',
        category: parsedJson['category'] ?? 'general',
        note: parsedJson['note'] ?? finalTranscript.trim(),
        createdAt: DateTime.now(),
      );

      debugPrint("FIRESTORE WRITE: Attempting...");
      await firebase.addTransaction(tx);

      // 4. Refresh & Reset State
      state = state.copyWith(isProcessing: false, transcript: "Success:\${parsedJson['amount']}:\${parsedJson['note']}");
      
      // Delay before clearing transcript overlay logically
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          state = state.copyWith(transcript: '');
          _isLocked = false; // Fully unlock after success cooldown
        }
      });
      
    } catch (e) {
      debugPrint("Error: \$e");
      String errStr = e.toString();
      if (errStr.contains("Voice API key missing") || errStr.contains("401 Unauthorized")) {
        state = state.copyWith(isProcessing: false, error: 'Voice API key missing or invalid');
      } else {
        // As requested: "If parsing fails: Couldn't understand. Try again."
        state = state.copyWith(isProcessing: false, error: "Couldn't understand. Try again.");
      }
      _clearError();
      _isLocked = false;
    }
  }

  void _clearError() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) state = state.copyWith(error: '');
    });
  }
}

final voiceExpenseProvider = StateNotifierProvider<VoiceExpenseController, VoiceExpenseState>((ref) {
  return VoiceExpenseController(ref);
});

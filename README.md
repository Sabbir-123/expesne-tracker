# SpeakSpend - AI Expense Tracker

SpeakSpend is an elite, voice-first expense tracker powered by Flutter, engineered with a beautiful glassmorphic UI representing 2026 fintech application aesthetics.

## Features

- **Voice-First Input**: Integrates the `record` package with high-fidelity streams for instantaneous voice dictation.
- **NLP Expense Parsing**: A sophisticated dual-tier parsing engine. 
   - **Tier 1 (Regex)**: Ultra-fast local identification of currencies, categories, and amounts directly offline.
   - **Tier 2 (AI)**: Seamless cloud delegation to DeepSeek via OpenRouter and OpenAI Whisper for complex contextual phrasing processing.
- **Glassmorphic Financial Dashboard**: Features a premium animated floating AI Orb, frosted backdrop blur filters, and real-time sparkline balance widgets.
- **Instant Firestore Synchronization**: State-sync seamlessly across Android, iOS, and Web backends in real-time.

## Architecture & Technology
- Framework: Flutter & Dart
- Audio Engine: Record 
- State Controller: Riverpod 
- APIs: OpenAI Whisper (Audio), OpenRouter DeepSeek (NLP)
- Database: Firebase Firestore

## Demo Environments
Fully adaptive environments rendering flawlessly on iOS natively, Android Studio, and Chrome Web debug.

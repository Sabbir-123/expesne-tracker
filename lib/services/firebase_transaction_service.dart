import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import 'package:flutter/foundation.dart';

class FirebaseTransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<List<TransactionModel>> getTransactionsStream() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return TransactionModel.fromMap(doc.data(), doc.id);
            }).toList());
  }

  Future<void> addTransaction(TransactionModel tx) async {
    final uid = currentUserId;
    if (uid == null) throw Exception("User not logged in");

    // Fix: 5-second duplicate protection guard
    try {
      final fiveSecondsAgo = DateTime.now().subtract(const Duration(seconds: 5));
      final recentSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('createdAt', isGreaterThanOrEqualTo: fiveSecondsAgo.toIso8601String())
          .get();

      for (var doc in recentSnapshot.docs) {
        final data = doc.data();
        if (data['amount'] == tx.amount &&
            data['category'] == tx.category &&
            data['note'] == tx.note) {
          debugPrint("FIRESTORE DEDUPE BLOCKED: Identical transaction found within 5 seconds.");
          return; // Skip duplicate write
        }
      }
    } catch (e) {
      debugPrint("Deduplication check failed, proceeding to write. Error: \$e");
    }

    try {
      // Ensure the uid perfectly matches the logged in user
      final toSave = TransactionModel(
        id: tx.id,
        uid: uid,
        type: tx.type,
        amount: tx.amount,
        currency: tx.currency,
        category: tx.category,
        note: tx.note,
        createdAt: tx.createdAt,
      );

      await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc()
          .set(toSave.toMap());
    } catch (e) {
      // Prompt specification: "If Firebase fails: retry once"
      debugPrint("Firebase failed. Retrying once... \$e");
      await Future.delayed(const Duration(seconds: 1));
      final toSave = TransactionModel(
        id: tx.id,
        uid: uid,
        type: tx.type,
        amount: tx.amount,
        currency: tx.currency,
        category: tx.category,
        note: tx.note,
        createdAt: tx.createdAt,
      );
      await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .doc()
          .set(toSave.toMap());
    }
  }

  Future<void> deleteTransaction(String id) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('transactions').doc(id).delete();
  }
}

final firebaseTransactionServiceProvider = Provider((ref) => FirebaseTransactionService());

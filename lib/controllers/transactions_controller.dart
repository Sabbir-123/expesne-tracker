import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../services/firebase_transaction_service.dart';

final transactionsStreamProvider = StreamProvider<List<TransactionModel>>((ref) {
  final firebaseService = ref.watch(firebaseTransactionServiceProvider);
  return firebaseService.getTransactionsStream();
});

final transactionStatsProvider = Provider<Map<String, double>>((ref) {
  final transactionsAsync = ref.watch(transactionsStreamProvider);
  
  return transactionsAsync.when(
    data: (transactions) {
      double income = 0;
      double expense = 0;
      for (var t in transactions) {
        if (t.type == 'income') {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      return {
        'income': income,
        'expense': expense,
        'balance': income - expense,
      };
    },
    loading: () => {'income': 0.0, 'expense': 0.0, 'balance': 0.0},
    error: (_, __) => {'income': 0.0, 'expense': 0.0, 'balance': 0.0},
  );
});

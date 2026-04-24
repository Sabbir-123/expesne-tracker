class TransactionModel {
  final String id;
  final String uid;
  final String type; // 'income' or 'expense'
  final double amount;
  final String currency;
  final String category;
  final String note;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.uid,
    required this.type,
    required this.amount,
    required this.currency,
    required this.category,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'type': type,
      'amount': amount,
      'currency': currency,
      'category': category,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String docId) {
    return TransactionModel(
      id: docId,
      uid: map['uid'] ?? '',
      type: map['type'] ?? 'expense',
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'USD',
      category: map['category'] ?? 'general',
      note: map['note'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
    );
  }
}

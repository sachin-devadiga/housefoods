class PayoutRequestModel {
  final String id;
  final String chefId;
  final String chefName;
  final double amount;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String status; // 'pending', 'processed', 'rejected'
  final DateTime requestedAt;
  final DateTime? processedAt;

  PayoutRequestModel({
    required this.id,
    required this.chefId,
    required this.chefName,
    required this.amount,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.status,
    required this.requestedAt,
    this.processedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'chefId': chefId,
      'chefName': chefName,
      'amount': amount,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'status': status,
      'requestedAt': requestedAt,
      'processedAt': processedAt,
    };
  }

  factory PayoutRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return PayoutRequestModel(
      id: docId,
      chefId: map['chefId'] ?? '',
      chefName: map['chefName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      ifscCode: map['ifscCode'] ?? '',
      status: map['status'] ?? 'pending',
      requestedAt: map['requestedAt'] as DateTime,
      processedAt: map['processedAt'] as DateTime?,
    );
  }
}

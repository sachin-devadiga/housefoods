class PayoutRequestModel {
  final String id;
  final String chefId;
  final String chefName;
  final double amount;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String status; // 'pending', 'approved', 'rejected', 'paid'
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
      'amount': amount,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
    };
  }

  factory PayoutRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return PayoutRequestModel(
      id: docId,
      chefId: map['chefId'] ?? map['chef_id'] ?? '',
      chefName: map['chefName'] ?? map['chef_name'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      bankName: map['bankName'] ?? map['bank_name'] ?? '',
      accountNumber: map['accountNumber'] ?? map['account_number'] ?? '',
      ifscCode: map['ifscCode'] ?? map['ifsc_code'] ?? '',
      status: map['status'] ?? 'pending',
      requestedAt: DateTime.tryParse(map['requestedAt']?.toString() ?? map['requested_at']?.toString() ?? '') ?? DateTime.now(),
      processedAt: DateTime.tryParse(map['processedAt']?.toString() ?? map['processed_at']?.toString() ?? ''),
    );
  }
}

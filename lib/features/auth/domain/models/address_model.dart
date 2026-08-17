class AddressModel {
  final String id;
  final String label; // e.g., Home, Work, Other
  final String fullAddress;
  final String houseNo;
  final String landmark;

  AddressModel({
    required this.id,
    required this.label,
    required this.fullAddress,
    required this.houseNo,
    required this.landmark,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'address_line1': fullAddress,
      'address_line2': houseNo,
      'landmark': landmark,
    };
  }

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: (map['id'] ?? '').toString(),
      label: map['label'] ?? 'Home',
      fullAddress: map['fullAddress'] ?? map['address_line1'] ?? '',
      houseNo: map['houseNo'] ?? map['address_line2'] ?? '',
      landmark: map['landmark'] ?? '',
    );
  }
}

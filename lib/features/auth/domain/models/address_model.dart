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
      'id': id,
      'label': label,
      'fullAddress': fullAddress,
      'houseNo': houseNo,
      'landmark': landmark,
    };
  }

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'] ?? '',
      label: map['label'] ?? 'Home',
      fullAddress: map['fullAddress'] ?? '',
      houseNo: map['houseNo'] ?? '',
      landmark: map['landmark'] ?? '',
    );
  }
}

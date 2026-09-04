class AddressModel {
  final String id;
  final String label; // e.g., Home, Work, Other
  final String fullAddress;
  final String houseNo;
  final String landmark;
  final double? latitude;
  final double? longitude;

  AddressModel({
    required this.id,
    required this.label,
    required this.fullAddress,
    required this.houseNo,
    required this.landmark,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'label': label,
      'address_line1': fullAddress,
      'address_line2': houseNo,
      'landmark': landmark,
    };
    if (latitude != null) map['latitude'] = latitude;
    if (longitude != null) map['longitude'] = longitude;
    return map;
  }

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: (map['id'] ?? '').toString(),
      label: map['label'] ?? 'Home',
      fullAddress: map['fullAddress'] ?? map['address_line1'] ?? '',
      houseNo: map['houseNo'] ?? map['address_line2'] ?? '',
      landmark: map['landmark'] ?? '',
      latitude: map['latitude'] != null ? double.tryParse(map['latitude'].toString()) : null,
      longitude: map['longitude'] != null ? double.tryParse(map['longitude'].toString()) : null,
    );
  }
}

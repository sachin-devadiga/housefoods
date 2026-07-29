import 'package:flutter/material.dart';

class BusinessHoursModel {
  final TimeOfDay openTime;
  final TimeOfDay closeTime;
  final bool isClosed; // For holidays/off-days

  BusinessHoursModel({
    required this.openTime,
    required this.closeTime,
    this.isClosed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'openHour': openTime.hour,
      'openMinute': openTime.minute,
      'closeHour': closeTime.hour,
      'closeMinute': closeTime.minute,
      'isClosed': isClosed,
    };
  }

  factory BusinessHoursModel.fromMap(Map<String, dynamic> map) {
    return BusinessHoursModel(
      openTime: TimeOfDay(hour: map['openHour'] ?? 9, minute: map['openMinute'] ?? 0),
      closeTime: TimeOfDay(hour: map['closeHour'] ?? 21, minute: map['closeMinute'] ?? 0),
      isClosed: map['isClosed'] ?? false,
    );
  }
}

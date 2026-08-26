class HospitalData {
  final String hospitalId;
  final String hospitalName;

  final bool? isOpen;

  final String? openTime;
  final String? closeTime;

  final double distanceKm;

  final String? phoneNumber;

  final String? address;
  final bool hasEmergencyRoom;

  const HospitalData({
    required this.hospitalId,
    required this.hospitalName,
    required this.isOpen,
    this.openTime,
    this.closeTime,
    required this.distanceKm,
    this.phoneNumber,
    this.address,
    this.hasEmergencyRoom = false,
  });

  factory HospitalData.fromJson(Map<String, dynamic> json) {
    final hours = json['today_hours']?.toString().split('~');
    return HospitalData(
      hospitalId: json['id'].toString(),
      hospitalName: json['name'].toString(),
      isOpen: json['is_open'] as bool?,
      openTime: hours != null && hours.isNotEmpty ? hours.first : null,
      closeTime: hours != null && hours.length > 1 ? hours[1] : null,
      distanceKm: ((json['distance_m'] as num?)?.toDouble() ?? 0) / 1000,
      phoneNumber: json['phone']?.toString(),
      address: json['address']?.toString(),
      hasEmergencyRoom: json['has_emergency_room'] == true,
    );
  }

  String get operatingTime {
    if (openTime == null || closeTime == null) {
      return '진료 시간 정보 없음';
    }

    return '$openTime~$closeTime';
  }
}

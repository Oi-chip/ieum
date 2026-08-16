class HospitalData {
  final String hospitalId;
  final String hospitalName;

  // 현재 진료 중인지 여부
  final bool isOpen;

  // 오늘 운영 시간
  final String? openTime;
  final String? closeTime;

  // 현재 위치에서 병원까지 거리
  final double distanceKm;

  // 전화번호
  final String? phoneNumber;

  // 주소
  final String? address;

  const HospitalData({
    required this.hospitalId,
    required this.hospitalName,
    required this.isOpen,
    this.openTime,
    this.closeTime,
    required this.distanceKm,
    this.phoneNumber,
    this.address,
  });

  String get operatingTime {
    if (openTime == null || closeTime == null) {
      return '진료 시간 정보 없음';
    }

    return '$openTime~$closeTime';
  }
}
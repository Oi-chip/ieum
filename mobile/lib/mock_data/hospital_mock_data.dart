import '../models/hospital_data.dart';

// 병원 목록 테스트용 임시 데이터
const List<HospitalData> mockHospitalList = [
  HospitalData(
    hospitalId: 'HOSPITAL001',
    hospitalName: '봉화해성병원 (임시)',
    isOpen: true,
    openTime: '08:00',
    closeTime: '17:00',
    distanceKm: 1.2,
    phoneNumber: '054-000-0001 (임시)',
    address: '경상북도 봉화군 봉화읍 봉화로 000 (임시)',
  ),
  HospitalData(
    hospitalId: 'HOSPITAL002',
    hospitalName: '봉화중앙의원 (임시)',
    isOpen: false,
    openTime: '08:00',
    closeTime: '16:30',
    distanceKm: 1.8,
    phoneNumber: '054-000-0002 (임시)',
    address: '경상북도 봉화군 봉화읍 내성로 000 (임시)',
  ),
  HospitalData(
    hospitalId: 'HOSPITAL003',
    hospitalName: '봉화가정의학과의원 (임시)',
    isOpen: true,
    openTime: '09:00',
    closeTime: '18:00',
    distanceKm: 2.4,
    phoneNumber: '054-000-0003 (임시)',
    address: '경상북도 봉화군 봉화읍 봉화길 000 (임시)',
  ),
];

// 병원 검색 테스트용 임시 데이터
List<HospitalData> searchMockHospitals(String keyword) {
  final normalizedKeyword = keyword.trim().toLowerCase();

  if (normalizedKeyword.isEmpty) {
    return mockHospitalList;
  }

  return mockHospitalList.where((hospital) {
    return hospital.hospitalName
        .toLowerCase()
        .contains(normalizedKeyword);
  }).toList();
}
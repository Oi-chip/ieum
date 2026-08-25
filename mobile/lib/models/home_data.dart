class LocationData {
  final double latitude;
  final double longitude;
  final String locationName;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.locationName,
  });
}

class BusSummary {
  final String stopName;
  final String busNumber;
  final String route;
  final String arrivalTime;

  const BusSummary({
    required this.stopName,
    required this.busNumber,
    required this.route,
    required this.arrivalTime,
  });
}

class HospitalSummary {
  final String hospitalName;
  final String distance;

  const HospitalSummary({required this.hospitalName, required this.distance});
}

class WeatherSummary {
  final String temperature;
  final String condition;

  const WeatherSummary({required this.temperature, required this.condition});
}

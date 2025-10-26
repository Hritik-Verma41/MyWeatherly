class WeatherException implements Exception {
  final int statusCode;
  WeatherException(this.statusCode);
}

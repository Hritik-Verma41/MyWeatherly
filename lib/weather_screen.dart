import 'dart:convert';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:weather_app/exceptions/weather_expection.dart';
import 'package:weather_app/utils/weather_icon_mapper.dart';
import 'package:weather_app/widgets/additional_info_item.dart';
import 'package:weather_app/widgets/hourly_forecast_item.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:http/http.dart' as http;

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _searchTextEditingController = TextEditingController();
  Timer? _debounce;

  String _city = 'Patna';
  Future<Map<String, dynamic>>? weather;
  List<dynamic> _citySuggestions = [];

  @override
  void initState() {
    super.initState();
    _determinePositionAndSetCity();
  }

  Future<void> _determinePositionAndSetCity() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // -> Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        setState(() {
          _loadDefaultCity();
        });
        return;
      }

      // -> Check for permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied.');
          setState(() {
            _loadDefaultCity();
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        setState(() {
          _loadDefaultCity();
        });
        return;
      }

      // -> Timeour to prevent infinite wait
      // -> Fetch city if location services and permissions are enabled
      final position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Location fetch timed out');
              throw TimeoutException('Location fetch timeout');
            },
          );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final cityName =
            place.locality ?? place.subAdministrativeArea ?? 'Patna';
        debugPrint('Detected city: $cityName');

        setState(() {
          _city = cityName;
          weather = getCurrentWeather(_city);
        });
      } else {
        setState(() {
          weather = getCurrentWeather(_city);
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      _loadDefaultCity();
    }
  }

  void _loadDefaultCity() {
    weather = getCurrentWeather('Patna');
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.trim().isNotEmpty) {
        _fetchCitySuggestions(query.trim());
      } else {
        setState(() {
          _citySuggestions.clear();
        });
      }
    });
  }

  Future<void> _fetchCitySuggestions(String query) async {
    final apiKey = dotenv.get('OPEN_WEATHER_API_KEY', fallback: 'no-key');
    final url =
        'https://api.openweathermap.org/geo/1.0/direct?q=$query&limit=5&appid=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw WeatherException(response.statusCode);
      }

      final data = jsonDecode(response.body);

      setState(() {
        _citySuggestions = data;
      });
    } catch (err) {
      throw err.toString();
    }
  }

  Future<Map<String, dynamic>> getCurrentWeather(String city) async {
    String openWeatherApiKey = dotenv.get(
      'OPEN_WEATHER_API_KEY',
      fallback: 'no-key',
    );
    String url =
        'https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$openWeatherApiKey&units=metric';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 404) {
        throw WeatherException(404);
      }
      if (response.statusCode != 200) {
        throw WeatherException(response.statusCode);
      }
      final data = jsonDecode(response.body);
      return data;
    } catch (err) {
      rethrow;
    }
  }

  void _selectCity(String city) {
    _debounce?.cancel();
    _searchTextEditingController.text = '';
    FocusScope.of(context).unfocus();
    setState(() {
      _citySuggestions.clear();
      _city = city;
      weather = getCurrentWeather(city);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchTextEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (weather == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(WeatherIcons.sunrise),
            SizedBox(width: 10),
            Text('MyWeatherly', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                weather = getCurrentWeather(_city);
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Searchbar for weather search by city
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchTextEditingController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search city...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _debounce?.cancel();
                      setState(() {
                        _citySuggestions.clear();
                      });
                      _selectCity(value);
                    }
                  },
                ),
              ),
              Expanded(
                child: FutureBuilder(
                  future: weather,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator.adaptive(),
                      );
                    }

                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      if (error is WeatherException &&
                          error.statusCode == 404) {
                        return const Center(
                          child: Text(
                            'Weather not found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      if (error is WeatherException) {
                        return Center(
                          child: Text(
                            'Could not fetch weather data\nServer Error: ${error.statusCode}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.orangeAccent),
                          ),
                        );
                      }
                      return const Center(
                        child: Text(
                          'Could not fetch weather data.\n Some error occured.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }

                    final data = snapshot.data!;

                    final currentCity = data['city']['name'];
                    final currentCountryCode = data['city']['country'];
                    final currentTemp = data['list'][0]['main']['temp'];
                    final currentWeatherId =
                        data['list'][0]['weather'][0]['id'];
                    final currentWeatherDescription =
                        data['list'][0]['weather'][0]['description']
                            .split(' ')
                            .map(
                              (w) => w.isEmpty
                                  ? ''
                                  : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
                            )
                            .join(' ');
                    final currentWeatherHumidity =
                        data['list'][0]['main']['humidity'].toString();
                    final currentWeatherWindSpeed =
                        data['list'][0]['wind']['speed'].toString();
                    final currentWeatherPressure =
                        data['list'][0]['main']['pressure'].toString();

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // main card
                          SizedBox(
                            width: double.infinity,
                            child: Card(
                              elevation: 10,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$currentTemp°C',
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$currentCity, $currentCountryCode',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Icon(
                                          getWeatherIcon(currentWeatherId),
                                          size: 64,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          currentWeatherDescription,
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // weather forecast cards
                          const Text(
                            'Hourly Forecast',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 131,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: data['list'].length > 1
                                  ? data['list'].length - 1
                                  : 0,
                              itemBuilder: (context, index) {
                                final hourlyForecastTime = DateTime.parse(
                                  data['list'][index + 1]['dt_txt'],
                                );
                                final hourlyForecastWeatherId =
                                    data['list'][index + 1]['weather'][0]['id'];
                                final hourlyForecastTemprature =
                                    data['list'][index + 1]['main']['temp']
                                        .toString();

                                return HourlyForecastItem(
                                  time: DateFormat.Hm().format(
                                    hourlyForecastTime,
                                  ),
                                  date: DateFormat(
                                    'd MMM',
                                  ).format(hourlyForecastTime),
                                  icon: getWeatherIcon(hourlyForecastWeatherId),
                                  temprature: hourlyForecastTemprature,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          // additional information
                          const Text(
                            'Additional Information',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              AdditionalInfoItem(
                                icon: WeatherIcons.humidity,
                                label: 'Humidity',
                                value: '$currentWeatherHumidity%',
                              ),
                              AdditionalInfoItem(
                                icon: WeatherIcons.wind,
                                label: 'Wind Speed',
                                value: '$currentWeatherWindSpeed kph',
                              ),
                              AdditionalInfoItem(
                                icon: WeatherIcons.barometer,
                                label: 'Pressure',
                                value: '$currentWeatherPressure hPA',
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // show the list of all the cities
          if (_citySuggestions.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: kToolbarHeight + 12,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _citySuggestions.length,
                    itemBuilder: (context, index) {
                      final city = _citySuggestions[index];
                      final name = city['name'];
                      final country = city['country'];
                      return ListTile(
                        title: Text('$name, $country'),
                        onTap: () => _selectCity('$name,$country'),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

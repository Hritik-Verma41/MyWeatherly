import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
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
  late Future<Map<String, dynamic>> weather;

  @override
  void initState() {
    super.initState();
    weather = getCurrentWeather();
  }

  Future<Map<String, dynamic>> getCurrentWeather() async {
    try {
      String cityName = 'Pune';
      String openWeatherApiKey = dotenv.get(
        'OPEN_WEATHER_API_KEY',
        fallback: 'no-key',
      );
      final response = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/forecast?q=$cityName&appid=$openWeatherApiKey&units=metric',
        ),
      );

      final data = jsonDecode(response.body);

      if (int.parse(data['cod']) != 200) {
        throw 'An unexpected error occured';
      }

      return data;
    } catch (err) {
      throw err.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(WeatherIcons.sunrise),
            SizedBox(width: 10),
            Text('Weather App', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                weather = getCurrentWeather();
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder(
        future: weather,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (snapshot.hasError) {
            return Text(snapshot.error.toString());
          }

          final data = snapshot.data!;

          final currentCity = data['city']['name'];
          final currentCountryCode = data['city']['country'];
          final currentTemp = data['list'][0]['main']['temp'];
          final currentWeatherId = data['list'][0]['weather'][0]['id'];
          final currentWeatherDescription =
              data['list'][0]['weather'][0]['description']
                  .split(' ')
                  .map(
                    (w) => w.isEmpty
                        ? ''
                        : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
                  )
                  .join(' ');
          final currentWeatherHumidity = data['list'][0]['main']['humidity']
              .toString();
          final currentWeatherWindSpeed = data['list'][0]['wind']['speed']
              .toString();
          final currentWeatherPressure = data['list'][0]['main']['pressure']
              .toString();

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
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                              Icon(getWeatherIcon(currentWeatherId), size: 64),
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
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 131,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: data['list'].length - 1,
                    itemBuilder: (context, index) {
                      final hourlyForecastTime = DateTime.parse(
                        data['list'][index + 1]['dt_txt'],
                      );
                      final hourlyForecastWeatherId =
                          data['list'][index + 1]['weather'][0]['id'];
                      final hourlyForecastTemprature =
                          data['list'][index + 1]['main']['temp'].toString();

                      return HourlyForecastItem(
                        time: DateFormat.Hm().format(hourlyForecastTime),
                        date: DateFormat('d MMM').format(hourlyForecastTime),
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
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
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
    );
  }
}

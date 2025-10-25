import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:flutter/widgets.dart';

/// Returns an appropriate WeatherIcons icon based on the OpenWeatherMap weather condition [id].
IconData getWeatherIcon(int id) {
  if (id >= 200 && id < 300) {
    // Thunderstorm
    return WeatherIcons.thunderstorm;
  } else if (id >= 300 && id < 400) {
    // Drizzle
    return WeatherIcons.sprinkle;
  } else if (id >= 500 && id < 600) {
    // Rain
    switch (id) {
      case 500:
        return WeatherIcons.rain;
      case 501:
        return WeatherIcons.rain_mix;
      case 502:
        return WeatherIcons.rain_wind;
      case 503:
        return WeatherIcons.rain_wind;
      case 504:
        return WeatherIcons.rain_wind;
      case 511:
        return WeatherIcons.rain_mix;
      default:
        return WeatherIcons.showers;
    }
  } else if (id >= 600 && id < 700) {
    // Snow
    return WeatherIcons.snow;
  } else if (id >= 700 && id < 800) {
    // Atmosphere (fog, mist, smoke, haze, etc.)
    switch (id) {
      case 701:
        return WeatherIcons.raindrops;
      case 741:
        return WeatherIcons.fog;
      case 711:
        return WeatherIcons.smoke;
      case 721:
        return WeatherIcons.day_haze;
      case 731:
        return WeatherIcons.dust;
      case 751:
        return WeatherIcons.sandstorm;
      case 761:
        return WeatherIcons.dust;
      case 762:
        return WeatherIcons.volcano;
      case 771:
        return WeatherIcons.strong_wind;
      case 781:
        return WeatherIcons.tornado;
      default:
        return WeatherIcons.na;
    }
  } else if (id == 800) {
    // Clear sky
    return WeatherIcons.day_sunny;
  } else if (id > 800 && id < 805) {
    // Clouds
    switch (id) {
      case 801:
        return WeatherIcons.day_sunny_overcast;
      case 802:
        return WeatherIcons.cloud;
      case 803:
        return WeatherIcons.cloudy;
      case 804:
        return WeatherIcons.cloudy_windy;
      default:
        return WeatherIcons.cloud;
    }
  } else {
    // Unknown / default
    return WeatherIcons.na;
  }
}

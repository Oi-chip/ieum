import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/selected_location_service.dart';
import '../services/tts_service.dart';
import '../utils/korea_date.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  DateTime _selectedDate = DateTime.now();
  _WeatherData? _weather;
  String? _errorMessage;
  bool _isLoading = true;
  bool _hasAnnouncedInitialWeather = false;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final requestId = ++_loadRequestId;
    final today = _today;
    if (_selectedDate.isBefore(today)) {
      _selectedDate = today;
    }
    final requestedDate = _selectedDate;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final location = await SelectedLocationService.instance.getLocation();
      final grid = SelectedLocationService.instance.weatherGrid(location);
      final json = await ApiService.instance.getWeather(
        requestedDate,
        nx: grid.nx,
        ny: grid.ny,
      );
      if (!mounted || requestId != _loadRequestId) return;
      final weather = _WeatherData.fromJson(json);
      setState(() => _weather = weather);

      if (!_hasAnnouncedInitialWeather &&
          DateUtils.isSameDay(requestedDate, today)) {
        _hasAnnouncedInitialWeather = true;
        unawaited(_speakWeather(weather));
      }
    } on ApiException catch (error) {
      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _errorMessage = '날씨 정보를 불러오는 중 오류가 발생했습니다.';
      });
    } finally {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _speakWeather(_WeatherData data) async {
    try {
      await TtsService.instance.speak(data.summarySentence);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('음성 안내를 시작하지 못했습니다.')));
    }
  }

  DateTime get _today {
    return koreaToday();
  }

  bool get _canGoPrevious => _selectedDate.isAfter(_today);
  bool get _canGoNext =>
      _selectedDate.isBefore(_today.add(const Duration(days: 4)));

  void _changeDate(int deltaDays) {
    final nextDate = _selectedDate.add(Duration(days: deltaDays));
    final lastForecastDate = _today.add(const Duration(days: 4));
    if (nextDate.isBefore(_today) || nextDate.isAfter(lastForecastDate)) return;
    setState(() {
      _selectedDate = nextDate;
    });
    _loadWeather();
  }

  @override
  Widget build(BuildContext context) {
    final data = _weather;

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘 날씨', style: TextStyle(fontSize: 22)),
        centerTitle: true,
        actions: [
          IconButton(
            iconSize: 30,
            tooltip: '음성으로 듣기',
            icon: const Icon(Icons.volume_up),
            onPressed: data == null ? null : () => _speakWeather(data),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? _WeatherError(
                  message: _errorMessage!,
                  onRetry: _loadWeather,
                )
              : data == null
                  ? _WeatherError(
                      message: '날씨 정보를 불러오지 못했습니다.',
                      onRetry: _loadWeather,
                    )
                  : SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TopStatusRow(
                              data: data,
                            ),

                            const SizedBox(height: 20),

                            _DateNavigator(
                              date: _selectedDate,
                              onPrevious: _canGoPrevious
                                  ? () => _changeDate(-1)
                                  : null,
                              onNext: _canGoNext
                                  ? () => _changeDate(1)
                                  : null,
                            ),

                            const SizedBox(height: 16),

                            const _SectionLabel(
                              '시간별 예보',
                            ),

                            const SizedBox(height: 8),

                            _HourlyForecastRow(
                              hours: data.hourly,
                            ),

                            const SizedBox(height: 20),

                            const _SectionLabel(
                              '상세 정보',
                            ),

                            const SizedBox(height: 8),

                            _DetailGrid(
                              data: data,
                            ),

                            const SizedBox(height: 24),

                            _SpeakButton(
                              onPressed: () {
                                _speakWeather(data);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

class _TopStatusRow extends StatelessWidget {
  const _TopStatusRow({required this.data});

  final _WeatherData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusCircleCard(
            title: '날씨',
            subtitle: '(하늘상태)',
            icon: data.conditionIcon,
            iconColor: Colors.orange.shade700,
            valueLabel: data.conditionLabel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatusCircleCard(
            title: '미세먼지',
            icon: data.airQualityLevel.icon,
            iconColor: data.airQualityLevel.color,
            valueLabel: data.airQualityLevel.label,
          ),
        ),
      ],
    );
  }
}

class _StatusCircleCard extends StatelessWidget {
  const _StatusCircleCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.valueLabel,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final String valueLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 4),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 48, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            valueLabel,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateNavigator extends StatelessWidget {
  const _DateNavigator({
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final label = '${date.month}월 ${date.day}일 (${_weekdayKo(date.weekday)})';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PillButton(
          icon: Icons.chevron_left,
          label: '전날',
          onPressed: onPrevious,
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        _PillButton(
          icon: Icons.chevron_right,
          label: '다음날',
          onPressed: onNext,
          iconTrailing: true,
        ),
      ],
    );
  }

  static String _weekdayKo(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[weekday - 1];
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconTrailing = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool iconTrailing;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 22);
    final textWidget = Text(label, style: const TextStyle(fontSize: 16));

    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconTrailing ? textWidget : iconWidget,
        label: iconTrailing ? iconWidget : textWidget,
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}

class _HourlyForecastRow extends StatelessWidget {
  const _HourlyForecastRow({required this.hours});

  final List<_HourlyForecast> hours;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hour = hours[index];
          return _HourlyCard(hour: hour);
        },
      ),
    );
  }
}

class _HourlyCard extends StatelessWidget {
  const _HourlyCard({required this.hour});

  final _HourlyForecast hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNow = hour.isCurrent;
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: isNow
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isNow
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hour.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isNow ? FontWeight.w600 : FontWeight.w400,
                color: isNow ? theme.colorScheme.primary : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              hour.icon,
              size: 30,
              color: isNow ? theme.colorScheme.primary : Colors.grey.shade600,
            ),
            const SizedBox(height: 6),
            Text(
              '${hour.temperatureC}°',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isNow ? theme.colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.data});

  final _WeatherData data;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _DetailTile(
          icon: Icons.thermostat,
          label: '기온',
          value: '${data.temperatureC}°C',
        ),
        _DetailTile(
          icon: Icons.water_drop_outlined,
          label: '강수확률',
          value: '${data.precipitationPercent}%',
        ),
        _DetailTile(
          icon: Icons.ac_unit,
          label: '눈',
          value: '${data.snowPercent}%',
        ),
        _DetailTile(icon: Icons.air, label: '바람', value: data.windLabel),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 26, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SpeakButton extends StatelessWidget {
  const _SpeakButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.volume_up, size: 24),
        label: const Text(
          '오늘 날씨 읽어주기',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 17, color: Colors.grey.shade700),
    );
  }
}

class _WeatherError extends StatelessWidget {
  const _WeatherError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AirQualityLevel {
  good,
  normal,
  bad,
  veryBad;

  Color get color => switch (this) {
    _AirQualityLevel.good => Colors.green,
    _AirQualityLevel.normal => Colors.lightGreen.shade700,
    _AirQualityLevel.bad => Colors.orange,
    _AirQualityLevel.veryBad => Colors.red,
  };

  String get label => switch (this) {
    _AirQualityLevel.good => '좋음',
    _AirQualityLevel.normal => '보통',
    _AirQualityLevel.bad => '나쁨',
    _AirQualityLevel.veryBad => '매우 나쁨',
  };

  IconData get icon => switch (this) {
    _AirQualityLevel.good => Icons.sentiment_very_satisfied,
    _AirQualityLevel.normal => Icons.sentiment_satisfied,
    _AirQualityLevel.bad => Icons.sentiment_dissatisfied,
    _AirQualityLevel.veryBad => Icons.sentiment_very_dissatisfied,
  };
}

class _WeatherData {
  final String conditionLabel;
  final int temperatureC;
  final _AirQualityLevel airQualityLevel;
  final int precipitationPercent;
  final int snowPercent;
  final String windLabel;
  final List<_HourlyForecast> hourly;

  const _WeatherData({
    required this.conditionLabel,
    required this.temperatureC,
    required this.airQualityLevel,
    required this.precipitationPercent,
    required this.snowPercent,
    required this.windLabel,
    required this.hourly,
  });

  IconData get conditionIcon => _weatherIcon(conditionLabel);

  String get summarySentence =>
      '오늘 날씨는 $conditionLabel, 기온은 $temperatureC도입니다. '
      '미세먼지는 ${airQualityLevel.label}이고, '
      '강수량은 $precipitationPercent퍼센트입니다.';

  factory _WeatherData.fromJson(Map<String, dynamic> json) {
    final currentRaw = json['current'];

    final Map<String, dynamic> current =
        currentRaw is Map<String, dynamic>
            ? currentRaw
            : <String, dynamic>{};

    final hourlyRaw = json['hourly'];

    final List<dynamic> hourlyJson =
        hourlyRaw is List
            ? hourlyRaw
            : <dynamic>[];

    final currentAt = DateTime.tryParse(
      current['forecast_at']?.toString() ?? '',
    );

    final windSpeed =
        (current['wind_speed_ms'] as num?)?.toDouble();
    return _WeatherData(
      conditionLabel: current['condition']?.toString() ?? '알 수 없음',
      temperatureC: ((current['temperature_c'] as num?) ?? 0).round(),
      airQualityLevel: _AirQualityLevel.normal,
      precipitationPercent:
          ((current['precipitation_probability'] as num?) ?? 0).round(),
      snowPercent: ((current['snow_cm'] as num?) ?? 0).round(),
      windLabel: _windLabel(windSpeed),
      hourly: hourlyJson
          .whereType<Map<String, dynamic>>()
          .map((item) => _HourlyForecast.fromJson(item, currentAt))
          .toList(),
    );
  }
}

class _HourlyForecast {
  final String label;
  final String condition;
  final int temperatureC;
  final bool isCurrent;

  const _HourlyForecast({
    required this.label,
    required this.condition,
    required this.temperatureC,
    required this.isCurrent,
  });

  IconData get icon => _weatherIcon(condition);

  factory _HourlyForecast.fromJson(
    Map<String, dynamic> json,
    DateTime? currentAt,
  ) {
    final forecastAt = DateTime.tryParse(json['forecast_at']?.toString() ?? '');
    final koreaTime = forecastAt?.toUtc().add(const Duration(hours: 9));
    return _HourlyForecast(
      label: koreaTime == null ? '-' : '${koreaTime.hour}시',
      condition: json['condition']?.toString() ?? '알 수 없음',
      temperatureC: ((json['temperature_c'] as num?) ?? 0).round(),
      isCurrent:
          forecastAt != null &&
          currentAt != null &&
          forecastAt.isAtSameMomentAs(currentAt),
    );
  }
}

IconData _weatherIcon(String condition) {
  if (condition.contains('눈') && condition.contains('비')) return Icons.grain;
  if (condition.contains('눈')) return Icons.ac_unit;
  if (condition.contains('소나기')) return Icons.thunderstorm;
  if (condition.contains('비') || condition.contains('강수')) {
    return Icons.umbrella;
  }
  if (condition.contains('흐림')) return Icons.cloud;
  if (condition.contains('구름')) return Icons.cloud_outlined;
  if (condition.contains('맑음')) return Icons.wb_sunny;
  return Icons.help_outline;
}

String _windLabel(double? speed) {
  if (speed == null) return '정보 없음';
  if (speed < 4) return '약함';
  if (speed < 9) return '보통';
  return '강함';
}

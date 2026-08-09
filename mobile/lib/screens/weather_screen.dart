import 'package:flutter/material.dart';

/// 날씨 화면 (어르신 친화적 재설계)
///
/// 설계 원칙
/// - 아이콘만으로 정보를 전달하지 않는다. 모든 아이콘 옆에는 반드시 텍스트를 붙인다.
///   (예: 미세먼지를 스마일 표정으로만 표시하지 않고 "좋음/보통/나쁨" 글자를 함께 표시)
/// - 가장 중요한 정보(현재 기온)를 화면에서 가장 크게 보여준다.
/// - 버튼과 터치 영역은 최소 44~48px 이상으로 크게 만든다.
/// - 화면을 위아래로 나눠 스크롤을 강요하지 않고, 한 화면 안에 핵심 정보를 담는다.
/// - TTS(음성 안내) 버튼을 화면 하단에 항상 보이게 배치해 글자를 읽기 어려운
///   사용자도 정보를 들을 수 있게 한다. (기획서 2.6 TTS 음성안내 기능과 연동 지점)
///
/// 1주차(더미 데이터) 단계 화면입니다. 실제 API 연동 시
/// `_WeatherData.dummy()` 자리를 `ApiService.fetchWeather()` 호출로 교체하세요.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  // 봉화군의 region.json 격자 좌표. 기상청 단기예보 요청 시 사용한다.
  static const int _gridX = 90;
  static const int _gridY = 106;

  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  // TODO(총괄+Team B): flutter_tts 패키지를 pubspec.yaml에 추가한 뒤
  // 아래 함수에서 실제 TTS 재생 로직으로 교체하세요.
  // 서버(/api/weather)가 "짧고 자연스러운 한 문장"을 함께 내려주면
  // 그 문장을 그대로 TTS에 넘기는 방식을 기획서 2.6에서 권장하고 있습니다.
  void _speakWeather(_WeatherData data) {
    // 예시: await FlutterTts().speak(data.summarySentence);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('음성 안내: ${data.summarySentence}')),
    );
  }

  void _changeDate(int deltaDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: deltaDays));
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _WeatherData.dummy(); // TODO: 실제 API 응답으로 교체

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘 날씨', style: TextStyle(fontSize: 22)),
        centerTitle: true,
        actions: [
          // 음성 안내 버튼을 상단에도 배치해 접근 경로를 두 곳으로 늘림
          IconButton(
            iconSize: 30,
            tooltip: '음성으로 듣기',
            icon: const Icon(Icons.volume_up),
            onPressed: () => _speakWeather(data),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DateNavigator(
                date: _selectedDate,
                onPrevious: () => _changeDate(-1),
                onNext: () => _changeDate(1),
              ),
              const SizedBox(height: 16),
              _CurrentWeatherCard(data: data),
              const SizedBox(height: 16),
              _AirQualityBadge(level: data.airQualityLevel),
              const SizedBox(height: 20),
              const _SectionLabel('시간별 예보'),
              const SizedBox(height: 8),
              _HourlyForecastRow(hours: data.hourly),
              const SizedBox(height: 20),
              const _SectionLabel('상세 정보'),
              const SizedBox(height: 8),
              _DetailGrid(data: data),
              const SizedBox(height: 24),
              _SpeakButton(onPressed: () => _speakWeather(data)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 날짜 이동: 화살표 버튼을 48px 원형으로 키워 터치하기 쉽게 만든다.
// ---------------------------------------------------------------------------
class _DateNavigator extends StatelessWidget {
  const _DateNavigator({
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = '${date.month}월 ${date.day}일 (${_weekdayKo(date.weekday)})';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundIconButton(
          icon: Icons.chevron_left,
          label: '전날',
          onPressed: onPrevious,
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        _RoundIconButton(
          icon: Icons.chevron_right,
          label: '다음날',
          onPressed: onNext,
        ),
      ],
    );
  }

  static String _weekdayKo(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[weekday - 1];
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, size: 28),
          tooltip: label,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 현재 날씨: 기온을 가장 크게(44px), 날씨 아이콘 + 상태 텍스트를 함께 표시.
// ---------------------------------------------------------------------------
class _CurrentWeatherCard extends StatelessWidget {
  const _CurrentWeatherCard({required this.data});

  final _WeatherData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(data.conditionIcon, size: 80, color: Colors.orange.shade700),
        const SizedBox(height: 8),
        Text(
          data.conditionLabel,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '${data.temperatureC}°C',
          style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 미세먼지: 이모지 대신 색상 배지 + 텍스트로 표시. 색상만으로 판단하지 않도록
// "좋음/보통/나쁨/매우나쁨" 글자를 항상 함께 보여준다.
// ---------------------------------------------------------------------------
enum _AirQualityLevel { good, normal, bad, veryBad }

class _AirQualityBadge extends StatelessWidget {
  const _AirQualityBadge({required this.level});

  final _AirQualityLevel level;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (level) {
      _AirQualityLevel.good => (Colors.green, '좋음'),
      _AirQualityLevel.normal => (Colors.lightGreen, '보통'),
      _AirQualityLevel.bad => (Colors.orange, '나쁨'),
      _AirQualityLevel.veryBad => (Colors.red, '매우 나쁨'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '미세먼지',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 시간별 예보: 작은 원 대신 76px 폭 카드로 확대. 현재 시각은 강조 표시.
// ---------------------------------------------------------------------------
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
      child: Column(
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
    );
  }
}

// ---------------------------------------------------------------------------
// 상세 정보(강수확률/바람 등): 2열 그리드로 압축해 스크롤 의존도를 낮춘다.
// ---------------------------------------------------------------------------
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
          icon: Icons.water_drop_outlined,
          label: '강수 확률',
          value: '${data.precipitationPercent}%',
        ),
        _DetailTile(
          icon: Icons.air,
          label: '바람',
          value: data.windLabel,
        ),
        _DetailTile(
          icon: Icons.ac_unit,
          label: '적설 확률',
          value: '${data.snowPercent}%',
        ),
        _DetailTile(
          icon: Icons.thermostat,
          label: '체감 온도',
          value: '${data.feelsLikeC}°C',
        ),
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
          // 아이콘 + 라벨을 한 줄로 붙여서 크게 표시
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

// ---------------------------------------------------------------------------
// 음성 안내 버튼: 화면 하단에 항상 보이도록 배치, 높이 52px로 크게.
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// 더미 데이터 모델. 실제 연동 시 서버 /api/weather 응답 스키마에 맞춰
// fromJson 팩토리를 추가하고, region.json의 nx/ny를 요청 파라미터로 사용하세요.
// ---------------------------------------------------------------------------
class _WeatherData {
  final IconData conditionIcon;
  final String conditionLabel;
  final int temperatureC;
  final int feelsLikeC;
  final _AirQualityLevel airQualityLevel;
  final int precipitationPercent;
  final int snowPercent;
  final String windLabel;
  final List<_HourlyForecast> hourly;

  const _WeatherData({
    required this.conditionIcon,
    required this.conditionLabel,
    required this.temperatureC,
    required this.feelsLikeC,
    required this.airQualityLevel,
    required this.precipitationPercent,
    required this.snowPercent,
    required this.windLabel,
    required this.hourly,
  });

  /// TTS로 읽어줄 한 문장 요약. 서버가 이 문장을 직접 내려주는 방식을
  /// 기획서 2.6에서 권장하므로, 실제 연동 시 서버 응답 필드로 교체하세요.
  String get summarySentence =>
      '오늘 날씨는 $conditionLabel, 기온은 $temperatureC도입니다. '
      '미세먼지는 ${_airQualityLabel(airQualityLevel)}이고, '
      '강수 확률은 $precipitationPercent퍼센트입니다.';

  static String _airQualityLabel(_AirQualityLevel level) => switch (level) {
        _AirQualityLevel.good => '좋음',
        _AirQualityLevel.normal => '보통',
        _AirQualityLevel.bad => '나쁨',
        _AirQualityLevel.veryBad => '매우 나쁨',
      };

  factory _WeatherData.dummy() {
    return _WeatherData(
      conditionIcon: Icons.wb_sunny,
      conditionLabel: '맑음',
      temperatureC: 30,
      feelsLikeC: 32,
      airQualityLevel: _AirQualityLevel.good,
      precipitationPercent: 10,
      snowPercent: 0,
      windLabel: '약함',
      hourly: const [
        _HourlyForecast(label: '1시', icon: Icons.wb_sunny_outlined, temperatureC: 29, isCurrent: false),
        _HourlyForecast(label: '2시', icon: Icons.wb_sunny, temperatureC: 30, isCurrent: true),
        _HourlyForecast(label: '3시', icon: Icons.cloud_outlined, temperatureC: 29, isCurrent: false),
        _HourlyForecast(label: '4시', icon: Icons.cloud_outlined, temperatureC: 28, isCurrent: false),
        _HourlyForecast(label: '5시', icon: Icons.cloud, temperatureC: 27, isCurrent: false),
      ],
    );
  }
}

class _HourlyForecast {
  final String label;
  final IconData icon;
  final int temperatureC;
  final bool isCurrent;

  const _HourlyForecast({
    required this.label,
    required this.icon,
    required this.temperatureC,
    required this.isCurrent,
  });
}

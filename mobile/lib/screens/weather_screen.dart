import 'package:flutter/material.dart';

/// 날씨 화면
///
/// 와이어프레임(docs/wireframe/날씨 페이지 스케치.png) 구성을 그대로 따른다.
/// 1) 상단: 나가기 버튼
/// 2) 하늘상태(아이콘+라벨) / 미세먼지(아이콘+라벨) 좌우 2분할
/// 3) 날짜 네비게이터 (전날 - 월 일 - 다음날)
/// 4) 시간별 예보 (현재 시각 강조)
/// 5) 상세 정보 2x2 그리드: 기온 -> 강수량 -> 눈 -> 바람
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  DateTime _selectedDate = DateTime.now();

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
    final data = _WeatherData.dummy();

    return Scaffold(
      appBar: AppBar(
        // 와이어프레임 좌측 상단 "나가기" 버튼
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          label: const Text('나가기', style: TextStyle(fontSize: 16)),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
          ),
        ),
        leadingWidth: 100,
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
              // 하늘상태 / 미세먼지 좌우 2분할 (와이어프레임 상단 두 원)
              _TopStatusRow(data: data),
              const SizedBox(height: 20),
              _DateNavigator(
                date: _selectedDate,
                onPrevious: () => _changeDate(-1),
                onNext: () => _changeDate(1),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('시간별 예보'),
              const SizedBox(height: 8),
              _HourlyForecastRow(hours: data.hourly),
              const SizedBox(height: 20),
              const _SectionLabel('상세 정보'),
              const SizedBox(height: 8),
              // 기온 -> 강수량 -> 눈 -> 바람 순서 (와이어프레임 순서 그대로)
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

/// 하늘상태 / 미세먼지 카드를 좌우로 배치하는 행.
/// 와이어프레임에서 두 개의 큰 원(아이콘)이 나란히 놓인 부분에 대응한다.
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
          // 색상 + 아이콘 (원형 배경으로 와이어프레임의 원 느낌을 살림)
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
          // 색상만으로 구분하지 않고 한글 라벨을 반드시 함께 표시 (고령층 접근성)
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
  final VoidCallback onPrevious;
  final VoidCallback onNext;

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

/// 와이어프레임의 "전날 / 다음날" 캡슐(알약) 버튼 모양을 그대로 구현.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconTrailing = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool iconTrailing;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 22);
    final textWidget = Text(label, style: const TextStyle(fontSize: 16));

    return SizedBox(
      height: 48, // 최소 터치 타겟 48px 보장
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
    // 와이어프레임에서 현재 시각을 "원"으로 강조한 부분을 색상 + 테두리로 표현
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
                color:
                    isNow ? theme.colorScheme.primary : Colors.grey.shade700,
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

/// 상세 정보 2x2 그리드: 기온 -> 강수량 -> 눈 -> 바람
/// (와이어프레임 순서를 그대로 반영. 스크롤하면 아래쪽 두 칸이 보이는 구조도
/// SingleChildScrollView 안에 이 위젯이 이어서 배치되므로 그대로 재현된다.)
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
          label: '강수량',
          value: '${data.precipitationPercent}%',
        ),
        _DetailTile(
          icon: Icons.ac_unit,
          label: '눈',
          value: '${data.snowPercent}%',
        ),
        _DetailTile(
          icon: Icons.air,
          label: '바람',
          value: data.windLabel,
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
      height: 56, // 최소 터치 타겟 48px 이상 확보
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

  // 이모지 단독 표시는 지양하고, 아이콘 + 색상 + 한글 라벨을 함께 사용한다.
  IconData get icon => switch (this) {
        _AirQualityLevel.good => Icons.sentiment_very_satisfied,
        _AirQualityLevel.normal => Icons.sentiment_satisfied,
        _AirQualityLevel.bad => Icons.sentiment_dissatisfied,
        _AirQualityLevel.veryBad => Icons.sentiment_very_dissatisfied,
      };
}

class _WeatherData {
  final IconData conditionIcon;
  final String conditionLabel;
  final int temperatureC;
  final _AirQualityLevel airQualityLevel;
  final int precipitationPercent;
  final int snowPercent;
  final String windLabel;
  final List<_HourlyForecast> hourly;

  const _WeatherData({
    required this.conditionIcon,
    required this.conditionLabel,
    required this.temperatureC,
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
      '미세먼지는 ${airQualityLevel.label}이고, '
      '강수량은 $precipitationPercent퍼센트입니다.';

  factory _WeatherData.dummy() {
    return _WeatherData(
      conditionIcon: Icons.wb_sunny,
      conditionLabel: '맑음',
      temperatureC: 30,
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

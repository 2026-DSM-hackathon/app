import 'package:flutter/material.dart';

import 'widgets/notification_section.dart';
import 'widgets/vehicle_model_selector.dart';

void main() {
  runApp(const HackApp());
}

/// 선택 가능한 차량 기종 목록 (샘플 데이터).
const List<String> kVehicleModels = <String>[
  '현대 아이오닉 5',
  '기아 EV6',
  '제네시스 GV60',
  '테슬라 Model 3',
  '현대 코나',
];

class HackApp extends StatelessWidget {
  const HackApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color seed = Color(0xFF2E6BE6);
    return MaterialApp(
      title: '차량 모니터',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

/// 홈 화면. 알림 섹션과 차량 기종 선택 섹션을 조합하고 상태를 보관한다.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedModel = kVehicleModels.first;

  // 데모용 센서 값 (실제 연동 전 샘플 데이터).
  double _temperature = 27.5;
  bool _personDetected = true;

  void _onModelChanged(String? model) {
    if (model == null) return;
    setState(() => _selectedModel = model);
  }

  /// 데모: 센서 값을 임의로 갱신한다.
  void _refresh() {
    final int s = DateTime.now().second;
    setState(() {
      _temperature = 20 + (s % 25).toDouble();
      _personDetected = s.isEven;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('차량 모니터')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('새로고침'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // 알림: 차량 온도 + 사람 감지
            NotificationSection(
              temperature: _temperature,
              personDetected: _personDetected,
            ),
            const SizedBox(height: 24),
            // 차량 기종 선택
            VehicleModelSelector(
              models: kVehicleModels,
              selectedModel: _selectedModel,
              onChanged: _onModelChanged,
            ),
          ],
        ),
      ),
    );
  }
}

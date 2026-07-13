import 'package:flutter/foundation.dart';

/// 센서 1회 샘플.
@immutable
class SensorReading {
  const SensorReading({
    required this.time,
    required this.temperatureC,
    required this.humidity,
    required this.co2,
    required this.motion,
    this.heatstrokeRisk = 0,
  });

  final DateTime time;
  final double temperatureC; // 섭씨
  final double humidity; // 상대습도 %
  final double co2; // CO2 농도 ppm
  final double motion; // 0.0 ~ 1.0 (움직임 강도)
  final double heatstrokeRisk; // 0.0 ~ 1.0 열사병 확률(POD telemetry 로 수신)
}

/// CO2 공기질 등급(실내 기준 근사값). 위젯/차트 색상에 사용.
enum AirQuality { good, moderate, poor }

extension Co2AirQuality on double {
  /// ppm → 공기질 등급. 800/1500 ppm 기준(임시값, 펌웨어/기준 확정 시 조정).
  AirQuality get airQuality => this >= 1500
      ? AirQuality.poor
      : (this >= 800 ? AirQuality.moderate : AirQuality.good);
}

extension AirQualityLabel on AirQuality {
  String get label => switch (this) {
        AirQuality.good => '쾌적',
        AirQuality.moderate => '보통',
        AirQuality.poor => '나쁨',
      };
}

/// 센서 데이터 소스(목업 ↔ ESP HTTP ↔ MQTT 시리얼 통신).
enum SensorDataSource { mock, esp, mqtt }

extension SensorDataSourceLabel on SensorDataSource {
  String get label => switch (this) {
        SensorDataSource.mock => '목업 데이터',
        SensorDataSource.esp => 'ESP 서버',
        SensorDataSource.mqtt => 'MQTT(시리얼)',
      };
}

/// 기기(POD)의 온라인 상태 — MQTT `status` 토픽/LWT 기준.
enum PodConnection { unknown, online, offline }

extension PodConnectionLabel on PodConnection {
  String get label => switch (this) {
        PodConnection.unknown => '확인 중',
        PodConnection.online => '온라인',
        PodConnection.offline => '오프라인',
      };
}

/// 추론 출처: 실제 모델 vs 폴백 휴리스틱.
enum InferenceSource { model, fallback }

/// 추론 결과(탑승 확률).
@immutable
class InferenceResult {
  const InferenceResult({
    required this.time,
    required this.probability,
    required this.source,
  });

  final DateTime time;
  final double probability; // 0.0 ~ 1.0
  final InferenceSource source;

  bool get occupied => probability >= 0.5;
}

/// 알림 심각도.
enum AlertSeverity { info, warning, critical }

/// 알림 유형.
enum AlertType {
  occupancyDetected,
  highTemperature,
  highCo2,
  prolongedOccupancy,
  deviceOffline,
}

@immutable
class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.time,
    required this.title,
    required this.message,
    this.acknowledged = false,
    this.escalated = false,
  });

  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final DateTime time;
  final String title;
  final String message;
  final bool acknowledged;
  final bool escalated;

  AlertEvent copyWith({bool? acknowledged, bool? escalated}) => AlertEvent(
        id: id,
        type: type,
        severity: severity,
        time: time,
        title: title,
        message: message,
        acknowledged: acknowledged ?? this.acknowledged,
        escalated: escalated ?? this.escalated,
      );
}

/// 센서 유형(F-10 표시용).
enum SensorType { radar, thermal, pressure, camera }

extension SensorTypeLabel on SensorType {
  String get label => switch (this) {
        SensorType.radar => '레이더',
        SensorType.thermal => '열화상',
        SensorType.pressure => '압력',
        SensorType.camera => '카메라',
      };
}

/// 페어링된 기기.
@immutable
class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.battery,
    required this.connected,
    required this.sensorType,
  });

  final String id;
  final String name;
  final int battery; // 0 ~ 100, 미확인 시 -1
  final bool connected;
  final SensorType sensorType;

  /// 배터리 정보를 아는 기기인지(실제 BLE 스캔 결과는 -1일 수 있음).
  bool get hasBattery => battery >= 0;

  DeviceInfo copyWith({int? battery, bool? connected}) => DeviceInfo(
        id: id,
        name: name,
        battery: battery ?? this.battery,
        connected: connected ?? this.connected,
        sensorType: sensorType,
      );
}

/// 공간 유형(비차량 모드 포함).
enum SpaceType { car, stroller, room, other }

extension SpaceTypeLabel on SpaceType {
  String get label => switch (this) {
        SpaceType.car => '차량',
        SpaceType.stroller => '유모차',
        SpaceType.room => '실내 공간',
        SpaceType.other => '기타',
      };

  bool get isVehicle => this == SpaceType.car;
}

/// 제조사별 차종 모델 카탈로그(직접 입력 지원).
const String kCustomManufacturer = '직접 입력';

const Map<String, List<String>> kVehicleCatalog = <String, List<String>>{
  '현대': <String>['아이오닉 5', '아이오닉 6', '코나', '그랜저', '싼타페'],
  '기아': <String>['EV6', 'EV9', '니로', '쏘렌토', '스포티지'],
  '제네시스': <String>['GV60', 'GV70', 'GV80', 'G80'],
  '테슬라': <String>['Model 3', 'Model Y'],
  'KGM': <String>['토레스', '티볼리'],
};

/// 차종/공간 프로필(F-08). 차량(제조사)과 차종 모델로 구분한다.
@immutable
class SpaceProfile {
  const SpaceProfile({
    required this.userName,
    required this.email,
    required this.spaceType,
    required this.manufacturer,
    required this.modelName,
  });

  final String userName;
  final String email; // 로그인 미사용 시 빈 문자열
  final SpaceType spaceType;
  final String manufacturer; // 제조사(차량 모드) 또는 '직접 입력'
  final String modelName; // 차종 모델명 / 비차량 모드에서는 공간 이름

  bool get isVehicleMode => spaceType.isVehicle;

  /// 카탈로그에 있는 제조사인지(아니면 직접 입력).
  bool get isCatalogManufacturer => kVehicleCatalog.containsKey(manufacturer);

  SpaceProfile copyWith({
    String? userName,
    String? email,
    SpaceType? spaceType,
    String? manufacturer,
    String? modelName,
  }) =>
      SpaceProfile(
        userName: userName ?? this.userName,
        email: email ?? this.email,
        spaceType: spaceType ?? this.spaceType,
        manufacturer: manufacturer ?? this.manufacturer,
        modelName: modelName ?? this.modelName,
      );
}

/// 비상 연락처.
@immutable
class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone});
  final String name;
  final String phone;
}

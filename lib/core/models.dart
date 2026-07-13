import 'package:flutter/foundation.dart';

/// 센서 1회 샘플.
@immutable
class SensorReading {
  const SensorReading({
    required this.time,
    required this.temperatureC,
    required this.motion,
  });

  final DateTime time;
  final double temperatureC; // 섭씨
  final double motion; // 0.0 ~ 1.0 (움직임 강도)
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
  final int battery; // 0 ~ 100
  final bool connected;
  final SensorType sensorType;

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

/// 차종/공간 프로필(F-08).
@immutable
class SpaceProfile {
  const SpaceProfile({
    required this.userName,
    required this.email,
    required this.spaceType,
    required this.modelName,
  });

  final String userName;
  final String email;
  final SpaceType spaceType;
  final String modelName; // 차종명 또는 직접 입력값

  bool get isVehicleMode => spaceType.isVehicle;

  SpaceProfile copyWith({
    String? userName,
    String? email,
    SpaceType? spaceType,
    String? modelName,
  }) =>
      SpaceProfile(
        userName: userName ?? this.userName,
        email: email ?? this.email,
        spaceType: spaceType ?? this.spaceType,
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

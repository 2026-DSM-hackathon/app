import 'dart:collection';

import '../models.dart';

/// 추론 엔진 인터페이스(6.8). 실제 구현은 tflite_flutter 로 학습 모델을 로드해 교체.
abstract interface class InferenceEngine {
  InferenceResult infer(List<SensorReading> window);
}

/// 슬라이딩 윈도우 버퍼. 최근 [size]개 샘플을 유지한다.
class WindowBuffer {
  WindowBuffer({this.size = 15});

  final int size;
  final Queue<SensorReading> _buf = Queue<SensorReading>();

  void add(SensorReading r) {
    _buf.addLast(r);
    while (_buf.length > size) {
      _buf.removeFirst();
    }
  }

  List<SensorReading> get window => List.unmodifiable(_buf);
  bool get isReady => _buf.length >= size;
}

/// 윈도우 버퍼 기반 휴리스틱 폴백 추론.
///
/// TODO(real): TFLite Interpreter 로드에 성공하면 모델 추론을 사용하고,
/// 실패(모델 없음/런타임 오류) 시 이 폴백으로 자동 전환.
class FallbackInferenceEngine implements InferenceEngine {
  @override
  InferenceResult infer(List<SensorReading> window) {
    if (window.isEmpty) {
      return InferenceResult(
        time: DateTime.now(),
        probability: 0,
        source: InferenceSource.fallback,
      );
    }

    // 최근 움직임 평균 + 피크를 결합한 단순 확률 추정.
    final double avgMotion =
        window.map((r) => r.motion).reduce((a, b) => a + b) / window.length;
    final double maxMotion =
        window.map((r) => r.motion).reduce((a, b) => a > b ? a : b);

    final double p = (avgMotion * 0.7 + maxMotion * 0.3).clamp(0.0, 1.0);

    return InferenceResult(
      time: window.last.time,
      probability: double.parse(p.toStringAsFixed(2)),
      source: InferenceSource.fallback,
    );
  }
}

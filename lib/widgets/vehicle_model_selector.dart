import 'package:flutter/material.dart';

/// 차량 기종 선택 위젯.
///
/// [models] 중 하나를 드롭다운으로 선택하고 [onChanged]로 변경을 알린다.
class VehicleModelSelector extends StatelessWidget {
  const VehicleModelSelector({
    super.key,
    required this.models,
    required this.selectedModel,
    required this.onChanged,
  });

  /// 선택 가능한 차량 기종 목록.
  final List<String> models;

  /// 현재 선택된 기종.
  final String selectedModel;

  /// 선택 변경 콜백.
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.directions_car_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text('차량 기종 선택', style: textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedModel,
                icon: const Icon(Icons.expand_more),
                items: models
                    .map(
                      (String model) => DropdownMenuItem<String>(
                        value: model,
                        child: Text(model),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

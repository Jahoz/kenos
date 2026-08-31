import 'package:flutter_test/flutter_test.dart';
import 'package:kenos/core/utils/low_pass_filter.dart';

void main() {
  test('converge doucement vers la valeur cible', () {
    final filter = LowPassFilter(alpha: 0.5);
    final first = filter.filter(0);
    expect(first, 0);
    final second = filter.filter(1);
    expect(second, 0.5); // 0 + 0.5 * (1 - 0)
    final third = filter.filter(1);
    expect(third, 0.75);
  });

  test('un alpha faible lisse fortement les sauts', () {
    final filter = LowPassFilter(alpha: 0.1);
    filter.filter(0);
    final afterSpike = filter.filter(10);
    expect(afterSpike, closeTo(1.0, 1e-9)); // 90% of the noise absorbed
  });

  test('reset repart de zéro', () {
    final filter = LowPassFilter(alpha: 0.5)..filter(100);
    filter.reset();
    expect(filter.value, isNull);
    expect(filter.filter(3), 3);
  });
}

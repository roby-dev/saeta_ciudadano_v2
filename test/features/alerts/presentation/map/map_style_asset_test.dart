import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/map/map_style_asset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled map style asset loads and parses as a JSON style array', () async {
    final raw = await loadMapStyleJson();
    final decoded = jsonDecode(raw);

    expect(decoded, isA<List<dynamic>>());
    expect(decoded, isNotEmpty);
    for (final rule in decoded as List<dynamic>) {
      expect(rule, isA<Map<String, dynamic>>());
      expect((rule as Map<String, dynamic>)['stylers'], isA<List<dynamic>>());
    }
  });
}

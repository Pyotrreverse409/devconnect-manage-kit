import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devconnect/app.dart';

void main() {
  testWidgets('DevConnect app launches', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DevConnectApp()),
    );
    await tester.pumpAndSettle();
  });
}

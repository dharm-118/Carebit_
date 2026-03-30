import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_client/constants/app_constants.dart';

import 'package:frontend/app/app.dart';

void main() {
  testWidgets('splash redirects to connect device screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: CarebitApp()));

    expect(find.text('Carebit'), findsOneWidget);
    await tester.pump(AppConstants.splashRedirectDelay);
    await tester.pumpAndSettle();

    expect(find.text('Connect Device'), findsWidgets);
  });
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:off_the_record/pages/login_ui.dart';

void main() {
  testWidgets('Login screen shows sign-in options', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    expect(find.text('Guest Sign In'), findsOneWidget);
    expect(find.text('Spotify Sign In'), findsOneWidget);
    expect(find.text('Enter your name'), findsOneWidget);
  });
}

// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_bin/main.dart';
import 'package:smart_bin/config/app_routes.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We pass the login route as the initial route for the test.
    await tester.pumpWidget(const MyApp(initialRoute: AppRoutes.login));

    // Basic check to see if the app builds without crashing.
    // In a real app, you would check for login screen elements here.
    expect(find.byType(MyApp), findsOneWidget);
  });
}

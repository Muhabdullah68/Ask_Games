import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_projects/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GameHubApp());
    expect(find.text('GameHub'), findsNothing);
    expect(find.text('All your favorite games'), findsWidgets);
  });
}

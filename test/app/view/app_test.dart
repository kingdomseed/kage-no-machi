import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/app/app.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_page.dart';

void main() {
  group('App', () {
    testWidgets('renders ShukubaPage', (tester) async {
      await tester.pumpWidget(const App());
      expect(find.byType(ShukubaPage), findsOneWidget);
    });
  });
}

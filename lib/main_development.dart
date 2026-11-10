import 'package:kage_no_machi/app/app.dart';
import 'package:kage_no_machi/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}

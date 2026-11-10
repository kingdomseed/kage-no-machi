import 'package:kage_no_machi/l10n/l10n.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_page.dart';
import 'package:material_ui/material_ui.dart';

class App extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ShukubaPage(),
    );
  }
}

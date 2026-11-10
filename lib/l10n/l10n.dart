import 'package:flutter/widgets.dart';
import 'package:kage_no_machi/l10n/gen/app_localizations.dart';

export 'package:kage_no_machi/l10n/gen/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

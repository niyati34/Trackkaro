// Only compiled on web
// ignore: uri_does_not_exist
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void configureAppUrlStrategy() {
  setUrlStrategy(PathUrlStrategy());
}

import 'package:injector/injector.dart';

import '../configuration.dart';

final injector = Injector.appInstance;

void initInjector() {
  injector.registerSingleton<Configuration>(() => Configuration());
}

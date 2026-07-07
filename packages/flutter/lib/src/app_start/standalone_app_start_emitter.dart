import 'package:meta/meta.dart';

import 'app_start_info.dart';

@internal
abstract interface class StandaloneAppStartEmitter {
  Future<void> emit(AppStartInfo appStartInfo);
}

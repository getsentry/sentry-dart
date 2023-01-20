import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:injector/injector.dart';
import 'package:process/process.dart';

import '../cli/_sources.dart';
import '../cli/setup.dart';
import '../configuration.dart';

/// Injector singleton instance
final injector = Injector.appInstance;

/// Register and inits the [Configuration] class as a Singleton
void initInjector() {
  injector.registerSingleton<Configuration>(() => Configuration());
  injector.registerSingleton<ProcessManager>(() => LocalProcessManager());
  injector.registerSingleton<FileSystem>(() => LocalFileSystem());
  injector.registerSingleton<CLISetup>(() => CLISetup(currentCLISources));
}

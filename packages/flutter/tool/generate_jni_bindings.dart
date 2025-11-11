import 'package:jnigen/jnigen.dart';
import 'package:jnigen/src/elements/j_elements.dart' as j;

Future<void> main(List<String> args) async {
  await generateJniBindings(Config(
    outputConfig: OutputConfig(
      dartConfig: DartCodeOutputConfig(
        path: Uri.parse('lib/src/native/java/binding.g.dart'),
        structure: OutputStructure.singleFile,
      ),
    ),
    androidSdkConfig: AndroidSdkConfig(
      addGradleDeps: true,
      androidExample: 'example/',
    ),
    classes: ['io.sentry.SentryOptions'],
    visitors: [
      KeepOnlyOneMethodVisitor('io.sentry.SentryOptions',
          ['setSendClientReports', 'setDsn', 'setDebug'], 'fieldname'),
    ],
  ));
}

class KeepOnlyOneMethodVisitor extends j.Visitor {
  KeepOnlyOneMethodVisitor(
      this.classBinaryName, this.methodNames, this.fieldName);
  final String classBinaryName;
  final List<String> methodNames;
  final String fieldName;

  @override
  void visitClass(j.ClassDecl c) {
    if (c.binaryName != classBinaryName) {
      c.isExcluded = true; // exclude other classes, including nested ones
    }
  }

  @override
  void visitField(j.Field f) {
    if (f.name == fieldName) {
      f.isExcluded = false;
    } else {
      f.isExcluded = true;
    }
  }

  @override
  void visitMethod(j.Method m) {
    if (!methodNames.contains(m.originalName) || m.isConstructor) {
      m.isExcluded = true;
    }
  }
}

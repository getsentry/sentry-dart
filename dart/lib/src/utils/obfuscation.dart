bool isAppObfuscated() {
  final testObject = _TestClass();

  // In non-obfuscated builds, this will return "_TestClass"
  // In obfuscated builds, this will return something like "a" or other short identifier
  final typeName = testObject.runtimeType.toString();

  // If the type name doesn't contain "TestClass", it's likely obfuscated
  return !typeName.contains('TestClass');
}

// This class is only used to check its runtime type name
class _TestClass {}

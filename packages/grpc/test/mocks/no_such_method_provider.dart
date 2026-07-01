mixin NoSuchMethodProvider {
  @override
  Never noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'Method ${invocation.memberName} was called '
      'with arguments ${invocation.positionalArguments}',
    );
  }
}

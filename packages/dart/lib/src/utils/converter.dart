extension NumToBool on num {
  bool? toBool() {
    return this == 0
        ? false
        : this == 1
            ? true
            : null;
  }
}

bool? asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v.toBool();
  return null;
}

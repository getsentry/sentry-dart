import 'dart:ffi';

DynamicLibrary openOnWindows() {
  // Use the system SQLite DLL installed by Chocolatey
  try {
    // Try to load from system path first
    return DynamicLibrary.open('sqlite3.dll');
  } catch (e) {
    // Fallback to absolute path from Chocolatey installation
    return DynamicLibrary.open(
      'C:\\ProgramData\\chocolatey\\lib\\sqlite\\tools\\sqlite3.dll',
    );
  }
}

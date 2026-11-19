#include <windows.h>
BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
  if (reason == DLL_PROCESS_ATTACH) Sleep(3000);
  return TRUE;
}
__declspec(dllexport) int fixture_value(void) { return 42; }

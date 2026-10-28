#ifdef _WIN32
#include <windows.h>
BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
  if (reason == DLL_PROCESS_ATTACH) Sleep(3000);
  return TRUE;
}
__declspec(dllexport) int fixture_value(void) { return 42; }
#else
#include <unistd.h>
__attribute__((constructor)) static void initialize(void) { sleep(3); }
int fixture_value(void) { return 42; }
#endif

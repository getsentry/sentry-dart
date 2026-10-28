#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>

static _Thread_local uint32_t last_error;

void* LoadLibraryExW(const uint16_t* path, void* file, uint32_t flags) {
  if (file != NULL || flags != 0) { last_error = 87; return NULL; }
  size_t length = 0;
  while (path[length]) length++;
  char* utf8 = malloc(length * 3 + 1);
  size_t out = 0;
  for (size_t i = 0; i < length; i++) {
    uint16_t c = path[i];
    if (c < 0x80) utf8[out++] = c;
    else if (c < 0x800) {
      utf8[out++] = 0xc0 | (c >> 6);
      utf8[out++] = 0x80 | (c & 0x3f);
    } else {
      utf8[out++] = 0xe0 | (c >> 12);
      utf8[out++] = 0x80 | ((c >> 6) & 0x3f);
      utf8[out++] = 0x80 | (c & 0x3f);
    }
  }
  utf8[out] = 0;
  void* handle = dlopen(utf8, RTLD_LAZY);
  free(utf8);
  last_error = handle == NULL ? 126 : 0;
  return handle;
}

uint32_t GetLastError(void) { return last_error; }

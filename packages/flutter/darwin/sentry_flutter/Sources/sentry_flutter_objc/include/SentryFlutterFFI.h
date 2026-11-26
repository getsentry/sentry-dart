#ifndef SentryFlutterFFI_h
#define SentryFlutterFFI_h

#include <stddef.h>
#include <stdint.h>

// C types shared by the Swift plugin and the Dart FFI bindings (generated
// from this header via `ffi-cocoa.yaml`).
//
// These are types only: no function is declared or exported. Swift hands the
// address of a static `SentryFlutterFfiEntryPoints` to Dart over the method
// channel (`ffiEntryPoints`), so nothing is looked up by symbol name at
// runtime and release-build symbol stripping cannot break the calls.

/// Adds a breadcrumb from UTF-8 encoded JSON bytes.
///
/// The buffer is only read during the call; the caller owns and frees it.
typedef void (*SentryFlutterAddBreadcrumbFn)(const uint8_t *_Nonnull json, size_t length);

/// Native entry points callable from Dart. Fields may be NULL when an entry
/// point is unavailable; Dart then falls back to the method channel.
typedef struct {
    SentryFlutterAddBreadcrumbFn _Nullable addBreadcrumb;
} SentryFlutterFfiEntryPoints;

#endif /* SentryFlutterFFI_h */

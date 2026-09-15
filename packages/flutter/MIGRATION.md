# Standalone app-start span migration (v10)

The standalone `App Start` trace (`app.start`) now separates SDK initialization,
observed framework work, and first-frame rasterization. Static and streaming
tracing use the same measurements. Legacy app-start spans attached to `ui.load`
are unchanged.

| Span | Operation | Measured interval |
| --- | --- | --- |
| Pre-Init Startup | `app.start.pre_init` | Native startup timestamp → Sentry initialization start |
| Sentry Initialization | `app.start.sentry_init` | SDK initialization start → completion, excluding app-runner execution |
| Root Widget Attachment | `app.start.root_widget_attachment` | Initial `attachToBuildOwner` entry → successful return |
| Frame Build | `app.start.frame_build` | `handleBeginFrame` entry → successful `drawFrame` return |
| Frame Rasterization | `app.start.frame_raster` | First frame's engine-reported raster start → raster finish |

Pre-Init Startup replaces `App start to plugin registration` and
`Before Sentry Init Setup`. Plugin attachment depends on plugin ordering and no
longer divides the timeline. Native detail retains `app.start.native`; those
intervals can overlap Pre-Init Startup, so the children are not additive.

## Framework observations

Frame Build includes frame callbacks, intervening microtasks, widget updates,
layout, paint, compositing and finalization. It excludes post-frame callbacks.
It is measured through binding hooks, not `FrameTiming.buildDuration`: the
engine's build/vsync timestamps can omit earlier work during warm-up frames.

A frame can do framework work without being submitted when `deferFirstFrame()`
is active. Multiple Frame Build spans can precede one Frame Rasterization span;
they are siblings and do not imply one-to-one pairing. Deferral waiting remains
a gap rather than being attributed to build or raster work.

The SDK retains at most ten complete Frame Build intervals, plus the initial attachment while awaiting the
first raster report. Only intervals contained within the automatic startup
window are emitted. Crossing intervals are omitted, not truncated. The
`app.start.frame_builds.omitted` attribute counts observed build intervals
omitted because the buffer was full; it can include work after raster completion
but before callback delivery. Frame Build spans carry `app.start.frame.warm_up` and
`app.start.frame.deferred`, the latter observed at draw completion, not a claim
that a scene was submitted.

## Bootstrap and fallback

Initialize Sentry before calling `runApp`, either through `appRunner` or by
awaiting `SentryFlutter.init` and then calling `runApp` yourself. Both support
the same detail when Sentry creates the binding.

If the standard binding already exists, first-frame rasterization remains
available when initialization precedes rendering, but attachment and build
observations require Sentry's binding mixin. The SDK does not replace an existing
binding. Initialization after root attachment or first rasterization is rejected
for standalone startup observation, including the interval before a pending
raster callback is delivered. A later frame is never substituted for the first.

The automatic startup endpoint is the first raster-finish timestamp, not callback
arrival. Post-frame synchronous work may delay callback delivery without extending
the measurement. Raster completion does not mean physical display presentation or
full application responsiveness. Explicit app-start extensions retain their
existing behavior.

## Dashboards and alerts

The old `First frame render` span measured from Sentry initialization through
raster completion. It is replaced by the separate intervals above. The intermediate
revamp's Post-Init Startup, First Frame Render, Vsync Overhead and Raster Handoff
spans are removed. Frame Build now measures framework execution rather than the
engine's build interval.

Update searches using `app.start.plugin_registration`, `app.start.sentry_setup`,
`app.start.first_frame_render`, `app.start.post_init`, `app.start.frame_vsync` or
`app.start.frame_raster_handoff`. Compare overall app-start measurements across the
migration and establish new baselines for child spans. Cold/warm identity remains
in `app.vitals.start.type`.

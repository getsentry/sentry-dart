#include <sentry.h>
#include <string.h>

static int transport_result = 1;

static void capture_envelope(sentry_envelope_t *envelope, void *path)
{
    transport_result = sentry_envelope_write_to_file(envelope, path);
    sentry_envelope_free(envelope);
}

int main(int argc, char **argv)
{
    if (argc != 4) {
        return 2;
    }
    sentry_options_t *options = sentry_options_new();
    sentry_options_set_dsn(options, "https://public@example.com/1");
    sentry_options_set_database_path(options, argv[2]);
    sentry_options_set_auto_session_tracking(options, 0);
    sentry_transport_t *transport = sentry_transport_new(capture_envelope);
    sentry_transport_set_state(transport, argv[3]);
    sentry_options_set_transport(options, transport);
    if (sentry_init(options) != 0) {
        return 3;
    }
    if (strcmp(argv[1], "crash") == 0) {
        sentry_set_tag("migration", "breakpad");
        /* Crash in a child process so the test runner survives. */
        *(volatile int *)0 = 1;
        return 4;
    }
    sentry_close();
    return transport_result;
}

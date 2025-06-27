package io.sentry.flutter;
import android.content.Context;

import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

import io.sentry.Attachment;
import io.sentry.EventProcessor;
import io.sentry.Hint;
import io.sentry.SentryEvent;

public class AttachLogcatEventProcess implements EventProcessor {
    private String getLogcatOutput() {
        StringBuilder logOutput = new StringBuilder();
        Process process = null;
        try {
            // get most recent 1000 lines of logs and filter warnings.
            process = Runtime.getRuntime().exec("logcat -d -t 1000 *:W");
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                long maxLogSize = 1024 * 1024 * 2; // 2M
                while ((line = reader.readLine()) != null) {
                    if (logOutput.length() + line.length() + 1 > maxLogSize) {
                        // Stop reading if the log size exceeds a certain limit, add a mark to indicate this.
                        logOutput.append("Ended due to size limit.").append("\n");
                        break;
                    }
                    logOutput.append(line).append("\n");
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        finally {
            // destroy process
            if (process != null) {
                process.destroy();
            }
        }
        return logOutput.toString();
    }

    @Override
    public @Nullable SentryEvent process(@NotNull SentryEvent event, @NotNull Hint hint) {
        EventProcessor.super.process(event, hint);
        String logcatOutput = getLogcatOutput();
        if(!logcatOutput.isEmpty()) {
            hint.addAttachment(new Attachment(logcatOutput.getBytes(StandardCharsets.UTF_8), "logcat-output.txt", "text/plain"));
        }
        return event;
    }
}

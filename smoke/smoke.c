// Smoke test, run under Wine: loads libmpv with no video or audio output, opens clip.mp4 (a 20-second H.264 test pattern,
// 25 fps, keyframes only at 0 s and 10 s), seeks exactly to a time between keyframes, steps one frame, and prints mpv's
// and FFmpeg's versions and mpv's configuration.
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mpv/client.h>

static mpv_handle *mpv;

static void check(int status, const char *what)
{
    if (status < 0) {
        fprintf(stderr, "FAIL: %s: %s\n", what, mpv_error_string(status));
        exit(1);
    }
}

static void wait_for(mpv_event_id id)
{
    for (;;) {
        mpv_event *event = mpv_wait_event(mpv, 10);
        if (event->event_id == id)
            return;
        if (event->event_id == MPV_EVENT_NONE) {
            fprintf(stderr, "FAIL: timed out waiting for %s\n", mpv_event_name(id));
            exit(1);
        }
        if (event->event_id == MPV_EVENT_END_FILE) {
            fprintf(stderr, "FAIL: playback ended while waiting for %s\n", mpv_event_name(id));
            exit(1);
        }
    }
}

static double time_pos(void)
{
    double t = -1;
    check(mpv_get_property(mpv, "time-pos", MPV_FORMAT_DOUBLE, &t), "time-pos");
    return t;
}

int main(void)
{
    mpv = mpv_create();
    if (!mpv) {
        fprintf(stderr, "FAIL: mpv_create\n");
        return 1;
    }
    const char *options[][2] = {
        {"vo", "null"}, {"ao", "null"}, {"config", "no"}, {"osd-level", "0"}, {"terminal", "no"},
        {"hr-seek", "yes"}, {"keep-open", "yes"}, {"pause", "yes"},
    };
    for (size_t i = 0; i < sizeof(options) / sizeof(options[0]); i++)
        check(mpv_set_option_string(mpv, options[i][0], options[i][1]), options[i][0]);
    check(mpv_initialize(mpv), "initialize");

    // No scripting is built in (no Lua, JavaScript or C plugins), so neither are the options that control scripts or
    // the yt-dlp hook (a script): nothing can fetch from the network or run code from a file.
    const char *absent[] = {"options/load-scripts", "options/scripts", "options/ytdl"};
    for (size_t i = 0; i < sizeof(absent) / sizeof(absent[0]); i++) {
        char *value = mpv_get_property_string(mpv, absent[i]);
        if (value) {
            fprintf(stderr, "FAIL: %s exists (%s), so scripting is built in\n", absent[i], value);
            return 1;
        }
    }

    char *version = mpv_get_property_string(mpv, "mpv-version");
    char *ffmpeg = mpv_get_property_string(mpv, "ffmpeg-version");
    char *configuration = mpv_get_property_string(mpv, "mpv-configuration");
    printf("mpv: %s\nFFmpeg: %s\nconfiguration: %s\n", version, ffmpeg, configuration);
    if (!configuration || !strstr(configuration, "-Dgpl=false")) {
        fprintf(stderr, "FAIL: mpv's configuration doesn't say -Dgpl=false\n");
        return 1;
    }

    // Keyframes only at 0 s and 10 s, so only an exact seek lands at 6.2 s.
    const char *load[] = {"loadfile", "clip.mp4", NULL};
    check(mpv_command(mpv, load), "loadfile");
    wait_for(MPV_EVENT_FILE_LOADED);
    // Loading ends with a playback restart of its own; the seek's comes after it.
    wait_for(MPV_EVENT_PLAYBACK_RESTART);

    const char *seek[] = {"seek", "6.2", "absolute+exact", NULL};
    check(mpv_command(mpv, seek), "seek");
    wait_for(MPV_EVENT_PLAYBACK_RESTART);
    double at = time_pos();
    printf("after seeking to 6.2: %.3f\n", at);
    if (fabs(at - 6.2) > 0.05) {
        fprintf(stderr, "FAIL: seek landed at %.3f\n", at);
        return 1;
    }

    // A frame step plays one frame and pauses again; wait until the position moves.
    const char *step[] = {"frame-step", NULL};
    check(mpv_command(mpv, step), "frame-step");
    double stepped = at;
    for (int i = 0; i < 100 && stepped == at; i++) {
        mpv_wait_event(mpv, 0.1);
        stepped = time_pos();
    }
    printf("after one frame step: %.3f\n", stepped);
    if (fabs(stepped - at - 0.04) > 0.005) {
        fprintf(stderr, "FAIL: frame step went from %.3f to %.3f\n", at, stepped);
        return 1;
    }

    mpv_free(version);
    mpv_free(ffmpeg);
    mpv_free(configuration);
    mpv_terminate_destroy(mpv);
    printf("OK\n");
    return 0;
}

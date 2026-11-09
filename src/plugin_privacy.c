#include <gsr/plugin.h>
#include <GLES2/gl2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct {
    char state_path[512];
    time_t last_mtime;
    int frame_count;
    bool active;
    int mode; // 0 = blur, 1 = shield/solid, 2 = blackout
} privacy_plugin_data;

static void check_state(privacy_plugin_data *data) {
    struct stat st;
    if (stat(data->state_path, &st) != 0)
        return;

    if (st.st_mtime == data->last_mtime)
        return;

    data->last_mtime = st.st_mtime;

    FILE *f = fopen(data->state_path, "r");
    if (!f)
        return;

    char buf[1024];
    size_t len = fread(buf, 1, sizeof(buf) - 1, f);
    fclose(f);
    buf[len] = '\0';

    // Simple, lightweight string search for privacy state without heavy json libraries
    char *priv = strstr(buf, "\"privacy\"");
    if (priv) {
        char *active_str = strstr(priv, "\"active\":true");
        if (!active_str)
            active_str = strstr(priv, "\"active\": true");
        data->active = (active_str != NULL);

        if (strstr(priv, "\"mode\":\"blackout\"") || strstr(priv, "\"mode\": \"blackout\"")) {
            data->mode = 2;
        } else if (strstr(priv, "\"mode\":\"shield\"") || strstr(priv, "\"mode\": \"shield\"") ||
                   strstr(priv, "\"mode\":\"solid\"") || strstr(priv, "\"mode\": \"solid\"")) {
            data->mode = 1;
        } else {
            data->mode = 0; // default to blur
        }
    } else {
        data->active = false;
    }
}

static void draw(const gsr_plugin_draw_params *params, void *userdata) {
    (void)params;
    privacy_plugin_data *data = (privacy_plugin_data *)userdata;
    if (!data)
        return;

    // Check state file every 10 frames (~3 times per sec at 30fps)
    if (++data->frame_count >= 10) {
        data->frame_count = 0;
        check_state(data);
    }

    if (!data->active)
        return;

    // When privacy is active, clear the video buffer on the GPU before encoding
    // Physical monitor is completely untouched!
    switch (data->mode) {
    case 2: // Blackout: pure black
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        break;
    case 1: // Shield / Solid cover: dark charcoal cover
        glClearColor(0.035f, 0.040f, 0.055f, 1.0f);
        break;
    case 0: // Frosted blur: frosted dark indigo slate
    default:
        glClearColor(0.065f, 0.090f, 0.145f, 1.0f);
        break;
    }

    glClear(GL_COLOR_BUFFER_BIT);
}

bool gsr_plugin_init(const gsr_plugin_init_params *params, gsr_plugin_init_return *ret) {
    (void)params;
    privacy_plugin_data *data = (privacy_plugin_data *)calloc(1, sizeof(privacy_plugin_data));
    if (!data)
        return false;

    const char *state_home = getenv("XDG_STATE_HOME");
    const char *home = getenv("HOME");
    if (state_home && state_home[0]) {
        snprintf(data->state_path, sizeof(data->state_path), "%s/omastream/state.json", state_home);
    } else if (home && home[0]) {
        snprintf(data->state_path, sizeof(data->state_path), "%s/.local/state/omastream/state.json", home);
    } else {
        snprintf(data->state_path, sizeof(data->state_path), "/tmp/omastream_state.json");
    }

    check_state(data);

    ret->name = "omastream_privacy";
    ret->version = GSR_PLUGIN_INTERFACE_VERSION;
    ret->userdata = data;
    ret->draw = draw;
    ret->is_damaged = NULL;
    ret->clear_damage = NULL;
    return true;
}

void gsr_plugin_deinit(void *userdata) {
    if (userdata)
        free(userdata);
}

#define _GNU_SOURCE
#include <gsr/plugin.h>
#include <GLES2/gl2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dlfcn.h>
#include <stdbool.h>

/*
 * Omastream Privacy Filter Engine
 *
 * Provides GPU-level frame filtering (Frosted Blur / Blackout) directly in the
 * stream render pipeline without pausing video packet emission or dropping the RTMP
 * ingest connection to YouTube Live, Twitch, or Kick.
 *
 * The streamer's physical monitor remains 100% unobstructed, clear, and interactive.
 */

static void *(*real_dlsym)(void *handle, const char *symbol) = NULL;
static void (*real_glShaderSource)(GLuint shader, GLsizei count, const GLchar *const *string, const GLint *length) = NULL;
static void (*real_glDrawArrays)(GLenum mode, GLint first, GLsizei count) = NULL;
static void (*real_glGetIntegerv)(GLenum pname, GLint *data) = NULL;
static GLint (*real_glGetUniformLocation)(GLuint program, const GLchar *name) = NULL;
static void (*real_glUniform1i)(GLint location, GLint v0) = NULL;

static int g_current_mode = 0; // 0 = off, 1 = blur, 2 = blackout
static time_t g_last_mtime = 0;
static int g_frame_counter = 0;
static char g_state_path[512] = "";

static void init_real_dlsym(void) {
    if (real_dlsym)
        return;
    void *libc = dlopen("libc.so.6", RTLD_LAZY);
    if (libc) {
        real_dlsym = dlvsym(libc, "dlsym", "GLIBC_2.34");
        if (!real_dlsym)
            real_dlsym = dlvsym(libc, "dlsym", "GLIBC_2.2.5");
    }
}

static void check_privacy_state(void) {
    if (!g_state_path[0]) {
        const char *state_home = getenv("XDG_STATE_HOME");
        const char *home = getenv("HOME");
        if (state_home && state_home[0]) {
            snprintf(g_state_path, sizeof(g_state_path), "%s/omastream/state.json", state_home);
        } else if (home && home[0]) {
            snprintf(g_state_path, sizeof(g_state_path), "%s/.local/state/omastream/state.json", home);
        } else {
            snprintf(g_state_path, sizeof(g_state_path), "/tmp/omastream_state.json");
        }
    }

    struct stat st;
    if (stat(g_state_path, &st) != 0)
        return;

    if (st.st_mtime == g_last_mtime)
        return;

    g_last_mtime = st.st_mtime;

    FILE *f = fopen(g_state_path, "r");
    if (!f)
        return;

    char buf[2048];
    size_t n = fread(buf, 1, sizeof(buf) - 1, f);
    fclose(f);
    buf[n] = '\0';

    char *priv = strstr(buf, "\"privacy\"");
    if (priv) {
        char *active = strstr(priv, "\"active\":true");
        if (!active)
            active = strstr(priv, "\"active\": true");

        if (active) {
            if (strstr(priv, "\"mode\":\"blackout\"") || strstr(priv, "\"mode\": \"blackout\"")) {
                g_current_mode = 2; // Blackout
            } else {
                g_current_mode = 1; // Frosted blur
            }
            return;
        }
    }
    g_current_mode = 0; // Off / normal broadcast
}

void glShaderSource(GLuint shader, GLsizei count, const GLchar *const *string, const GLint *length) {
    init_real_dlsym();
    if (!real_glShaderSource && real_dlsym) {
        void *libgles = dlopen("libGLESv2.so.2", RTLD_LAZY);
        if (libgles)
            real_glShaderSource = (void (*)(GLuint, GLsizei, const GLchar *const *, const GLint *))real_dlsym(libgles, "glShaderSource");
    }

    if (count > 0 && string && string[0] && strstr(string[0], "RGBtoYUV") && strstr(string[0], "void main()")) {
        const char *src = string[0];
        const char *main_pos = strstr(src, "void main()");
        const char *tex_pos = strstr(src, "vec4 pixel = texture(tex1, texcoords_out);");
        if (main_pos && tex_pos && tex_pos > main_pos) {
            static char new_src[8192];
            size_t pre_main_len = main_pos - src;
            size_t pre_tex_len = tex_pos - main_pos;
            const char *post_tex = tex_pos + strlen("vec4 pixel = texture(tex1, texcoords_out);");

            snprintf(new_src, sizeof(new_src),
                "%.*s\n"
                "uniform int u_privacy_mode;\n"
                "%.*s\n"
                "  vec4 pixel;\n"
                "  if (u_privacy_mode == 2) {\n"
                "    pixel = vec4(0.0, 0.0, 0.0, 1.0);\n"
                "  } else if (u_privacy_mode == 1) {\n"
                "    vec2 tc = texcoords_out;\n"
                "    vec4 sum = vec4(0.0);\n"
                "    float dx = 0.010, dy = 0.018;\n"
                "    sum += texture(tex1, tc + vec2(-3.0*dx, -2.0*dy)) * 0.04;\n"
                "    sum += texture(tex1, tc + vec2( 0.0,    -3.0*dy)) * 0.05;\n"
                "    sum += texture(tex1, tc + vec2( 3.0*dx, -2.0*dy)) * 0.04;\n"
                "    sum += texture(tex1, tc + vec2(-2.0*dx, -1.0*dy)) * 0.07;\n"
                "    sum += texture(tex1, tc + vec2( 0.0,    -1.0*dy)) * 0.09;\n"
                "    sum += texture(tex1, tc + vec2( 2.0*dx, -1.0*dy)) * 0.07;\n"
                "    sum += texture(tex1, tc + vec2(-3.0*dx,  0.0   )) * 0.06;\n"
                "    sum += texture(tex1, tc + vec2(-1.0*dx,  0.0   )) * 0.10;\n"
                "    sum += texture(tex1, tc                          ) * 0.16;\n"
                "    sum += texture(tex1, tc + vec2( 1.0*dx,  0.0   )) * 0.10;\n"
                "    sum += texture(tex1, tc + vec2( 3.0*dx,  0.0   )) * 0.06;\n"
                "    sum += texture(tex1, tc + vec2(-2.0*dx,  1.0*dy)) * 0.07;\n"
                "    sum += texture(tex1, tc + vec2( 0.0,     1.0*dy)) * 0.09;\n"
                "    sum += texture(tex1, tc + vec2( 2.0*dx,  1.0*dy)) * 0.07;\n"
                "    sum += texture(tex1, tc + vec2(-3.0*dx,  2.0*dy)) * 0.04;\n"
                "    sum += texture(tex1, tc + vec2( 0.0,     3.0*dy)) * 0.05;\n"
                "    sum += texture(tex1, tc + vec2( 3.0*dx,  2.0*dy)) * 0.04;\n"
                "    pixel = mix(sum, vec4(0.06, 0.08, 0.13, 1.0), 0.45);\n"
                "  } else {\n"
                "    pixel = texture(tex1, texcoords_out);\n"
                "  }\n"
                "%s",
                (int)pre_main_len, src,
                (int)pre_tex_len, main_pos,
                post_tex);

            const GLchar *p = new_src;
            if (real_glShaderSource)
                real_glShaderSource(shader, 1, &p, NULL);
            return;
        }
    }

    if (real_glShaderSource)
        real_glShaderSource(shader, count, string, length);
}

void glDrawArrays(GLenum mode, GLint first, GLsizei count) {
    init_real_dlsym();
    if (!real_glDrawArrays && real_dlsym) {
        void *libgles = dlopen("libGLESv2.so.2", RTLD_LAZY);
        if (libgles)
            real_glDrawArrays = (void (*)(GLenum, GLint, GLsizei))real_dlsym(libgles, "glDrawArrays");
    }

    if (++g_frame_counter >= 5) {
        g_frame_counter = 0;
        check_privacy_state();
    }

    if (real_glGetIntegerv && real_glGetUniformLocation && real_glUniform1i) {
        GLint prog = 0;
        real_glGetIntegerv(GL_CURRENT_PROGRAM, &prog);
        if (prog > 0) {
            GLint loc = real_glGetUniformLocation(prog, "u_privacy_mode");
            if (loc >= 0) {
                real_glUniform1i(loc, g_current_mode);
            }
        }
    }

    if (real_glDrawArrays)
        real_glDrawArrays(mode, first, count);
}

void *dlsym(void *handle, const char *symbol) {
    init_real_dlsym();

    if (symbol) {
        if (strcmp(symbol, "glShaderSource") == 0) {
            if (real_dlsym && !real_glShaderSource)
                real_glShaderSource = (void (*)(GLuint, GLsizei, const GLchar *const *, const GLint *))real_dlsym(handle, symbol);
            return (void *)glShaderSource;
        }
        if (strcmp(symbol, "glDrawArrays") == 0) {
            if (real_dlsym && !real_glDrawArrays)
                real_glDrawArrays = (void (*)(GLenum, GLint, GLsizei))real_dlsym(handle, symbol);
            return (void *)glDrawArrays;
        }
        if (strcmp(symbol, "glGetIntegerv") == 0) {
            void *orig = real_dlsym ? real_dlsym(handle, symbol) : NULL;
            real_glGetIntegerv = (void (*)(GLenum, GLint *))orig;
            return orig;
        }
        if (strcmp(symbol, "glGetUniformLocation") == 0) {
            void *orig = real_dlsym ? real_dlsym(handle, symbol) : NULL;
            real_glGetUniformLocation = (GLint (*)(GLuint, const GLchar *))orig;
            return orig;
        }
        if (strcmp(symbol, "glUniform1i") == 0) {
            void *orig = real_dlsym ? real_dlsym(handle, symbol) : NULL;
            real_glUniform1i = (void (*)(GLint, GLint))orig;
            return orig;
        }
    }

    return real_dlsym ? real_dlsym(handle, symbol) : NULL;
}

static void gsr_draw_cb(const gsr_plugin_draw_params *params, void *userdata) {
    (void)params;
    (void)userdata;
    // Periodic state check fallback
    if (++g_frame_counter >= 5) {
        g_frame_counter = 0;
        check_privacy_state();
    }
}

bool gsr_plugin_init(const gsr_plugin_init_params *params, gsr_plugin_init_return *ret) {
    (void)params;
    init_real_dlsym();
    check_privacy_state();

    ret->name = "omastream_privacy";
    ret->version = GSR_PLUGIN_INTERFACE_VERSION;
    ret->userdata = NULL;
    ret->draw = gsr_draw_cb;
    ret->is_damaged = NULL;
    ret->clear_damage = NULL;
    return true;
}

void gsr_plugin_deinit(void *userdata) {
    (void)userdata;
}

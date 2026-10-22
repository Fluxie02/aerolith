// Verification-only Wayland input client. No production shell dependency.
#include <wayland-client.h>
#include <linux/input-event-codes.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "virtual-pointer-client.h"
static struct zwlr_virtual_pointer_manager_v1 *manager;
static void add(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    if (!strcmp(interface, "zwlr_virtual_pointer_manager_v1"))
        manager = wl_registry_bind(registry, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
}
static void remove_global(void *data, struct wl_registry *registry, uint32_t name) {}
static const struct wl_registry_listener listener = {add, remove_global};
static uint32_t stamp(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1000 + t.tv_nsec / 1000000; }
int main(int argc, char **argv) {
    if (argc < 3) return 2;
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) return 3;
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &listener, NULL);
    wl_display_roundtrip(display);
    if (!manager) return 4;
    struct zwlr_virtual_pointer_v1 *pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, NULL);
    wl_display_roundtrip(display);
    zwlr_virtual_pointer_v1_motion_absolute(pointer, stamp(), atoi(argv[1]), atoi(argv[2]), 1920, 1080);
    zwlr_virtual_pointer_v1_frame(pointer);
    wl_display_roundtrip(display);
    usleep(60000);
    if (argc < 4 || strcmp(argv[3], "hover")) {
        zwlr_virtual_pointer_v1_button(pointer, stamp(), BTN_LEFT, WL_POINTER_BUTTON_STATE_PRESSED);
        zwlr_virtual_pointer_v1_frame(pointer); wl_display_roundtrip(display); usleep(40000);
        zwlr_virtual_pointer_v1_button(pointer, stamp(), BTN_LEFT, WL_POINTER_BUTTON_STATE_RELEASED);
        zwlr_virtual_pointer_v1_frame(pointer); wl_display_roundtrip(display);
    }
    zwlr_virtual_pointer_v1_destroy(pointer);
    zwlr_virtual_pointer_manager_v1_destroy(manager);
    wl_registry_destroy(registry);
    wl_display_roundtrip(display); wl_display_disconnect(display);
    return 0;
}

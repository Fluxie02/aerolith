/* A virtual pointer for the headless harness: the headless sway has no input
 * devices, so scenarios cannot click. This client creates one through
 * zwlr_virtual_pointer_v1 and clicks at a layout position:
 *
 *   vpointer click X Y WIDTH HEIGHT
 *
 * WIDTH and HEIGHT are the layout size the coordinates refer to (the output
 * size at scale 1). Built by tools/headless/session.sh; test-only.
 */
#include <linux/input-event-codes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>

#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"

static struct wl_seat *seat;
static struct zwlr_virtual_pointer_manager_v1 *manager;

static void global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
	(void)data;
	if (strcmp(interface, wl_seat_interface.name) == 0)
		seat = wl_registry_bind(registry, name, &wl_seat_interface, 1);
	else if (strcmp(interface, zwlr_virtual_pointer_manager_v1_interface.name) == 0)
		manager = wl_registry_bind(registry, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
	(void)version;
}

static void global_remove(void *data, struct wl_registry *registry, uint32_t name) {
	(void)data; (void)registry; (void)name;
}

static const struct wl_registry_listener listener = { global, global_remove };

static uint32_t now_ms(void) {
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (uint32_t)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

int main(int argc, char **argv) {
	if (argc != 6 || strcmp(argv[1], "click") != 0) {
		fprintf(stderr, "usage: vpointer click X Y WIDTH HEIGHT\n");
		return 2;
	}
	uint32_t x = (uint32_t)atoi(argv[2]), y = (uint32_t)atoi(argv[3]);
	uint32_t w = (uint32_t)atoi(argv[4]), h = (uint32_t)atoi(argv[5]);

	struct wl_display *display = wl_display_connect(NULL);
	if (!display) {
		fprintf(stderr, "vpointer: no Wayland display\n");
		return 1;
	}
	struct wl_registry *registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &listener, NULL);
	wl_display_roundtrip(display);
	if (!manager) {
		fprintf(stderr, "vpointer: compositor lacks zwlr_virtual_pointer_manager_v1\n");
		return 1;
	}
	struct zwlr_virtual_pointer_v1 *pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, seat);

	zwlr_virtual_pointer_v1_motion_absolute(pointer, now_ms(), x, y, w, h);
	zwlr_virtual_pointer_v1_frame(pointer);
	wl_display_roundtrip(display);
	usleep(150000); /* let the client see enter and motion first */
	zwlr_virtual_pointer_v1_button(pointer, now_ms(), BTN_LEFT, WL_POINTER_BUTTON_STATE_PRESSED);
	zwlr_virtual_pointer_v1_frame(pointer);
	wl_display_roundtrip(display);
	usleep(50000);
	zwlr_virtual_pointer_v1_button(pointer, now_ms(), BTN_LEFT, WL_POINTER_BUTTON_STATE_RELEASED);
	zwlr_virtual_pointer_v1_frame(pointer);
	wl_display_roundtrip(display);

	zwlr_virtual_pointer_v1_destroy(pointer);
	wl_display_roundtrip(display);
	wl_display_disconnect(display);
	return 0;
}

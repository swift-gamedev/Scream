#include "CFlecsShims.h"

#include <stdatomic.h>

// A spinlock: worlds are created and destroyed rarely, and this must not depend on Flecs' own OS
// API, which is what the lock protects.
static atomic_flag worldLock = ATOMIC_FLAG_INIT;

static void lockWorlds(void) {
    while (atomic_flag_test_and_set_explicit(&worldLock, memory_order_acquire)) {
    }
}

static void unlockWorlds(void) {
    atomic_flag_clear_explicit(&worldLock, memory_order_release);
}

ecs_world_t *screamInitWorld(void) {
    lockWorlds();
    ecs_world_t *world = ecs_init();
    unlockWorlds();
    return world;
}

int screamFiniWorld(ecs_world_t *world) {
    lockWorlds();
    int result = ecs_fini(world);
    unlockWorlds();
    return result;
}

static ScreamLogHandler screamLogHandler = NULL;
static ecs_os_api_log_t flecsDefaultLog = NULL;

static void screamForwardLog(int32_t level, const char *file, int32_t line, const char *message) {
    ScreamLogHandler handler = screamLogHandler;
    if (handler) {
        handler(level, file, line, message);
    } else if (flecsDefaultLog) {
        flecsDefaultLog(level, file, line, message);
    }
}

void screamSetLogHandler(ScreamLogHandler handler) {
    // ecs_os_set_api_defaults fills in the default log and the rest of the OS API once; a later
    // call is a no-op, so the default callback is still the real one when it is read here.
    ecs_os_set_api_defaults();
    if (!flecsDefaultLog) {
        flecsDefaultLog = ecs_os_api.log_;
    }
    screamLogHandler = handler;
    ecs_os_api.log_ = screamForwardLog;
}

#define SCREAM_LAYOUT(T) \
    size_t screamSizeOf_##T(void) { return sizeof(T); } \
    size_t screamAlignOf_##T(void) { return _Alignof(T); }

SCREAM_LAYOUT(ecs_iter_t)
SCREAM_LAYOUT(ecs_query_desc_t)
SCREAM_LAYOUT(ecs_system_desc_t)
SCREAM_LAYOUT(ecs_observer_desc_t)
SCREAM_LAYOUT(ecs_component_desc_t)
SCREAM_LAYOUT(ecs_entity_desc_t)
SCREAM_LAYOUT(ecs_type_hooks_t)
SCREAM_LAYOUT(ecs_type_info_t)
SCREAM_LAYOUT(ecs_term_t)
SCREAM_LAYOUT(ecs_term_ref_t)
SCREAM_LAYOUT(ecs_world_info_t)

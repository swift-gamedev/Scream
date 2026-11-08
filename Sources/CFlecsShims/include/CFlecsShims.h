// C helpers for the parts of Flecs that Swift cannot import: function-like macros, the mutable
// global ecs_os_api, and the struct sizes the layout test compares against.
#ifndef CFLECS_SHIMS_H
#define CFLECS_SHIMS_H

#include "CFlecs.h"

#ifdef __cplusplus
extern "C" {
#endif

// Pairs. ecs_pair and friends are macros over bit operations, so they get functions here.

static inline ecs_id_t screamPair(ecs_entity_t first, ecs_entity_t second) {
    return ecs_pair(first, second);
}

static inline bool screamIdIsPair(ecs_id_t id) {
    return ECS_IS_PAIR(id);
}

static inline ecs_entity_t screamPairFirst(const ecs_world_t *world, ecs_id_t pair) {
    return ecs_pair_first(world, pair);
}

static inline ecs_entity_t screamPairSecond(const ecs_world_t *world, ecs_id_t pair) {
    return ecs_pair_second(world, pair);
}

// The entity part of an id, without the generation or the pair bit.
static inline ecs_entity_t screamStripGeneration(ecs_entity_t entity) {
    return ecs_strip_generation(entity);
}

// Logging. Flecs formats the message before it reaches ecs_os_api.log_, so the handler receives
// a finished string. level is Flecs' level: negative for errors and warnings, 0 for trace, higher
// for debug detail.
typedef void (*ScreamLogHandler)(int32_t level, const char *file, int32_t line, const char *message);

// Routes Flecs' log through handler, or back to Flecs' own stderr output when NULL. Must be called
// before the first world is created, as ecs_os_set_api requires.
void screamSetLogHandler(ScreamLogHandler handler);

// Struct sizes as the C compiler sees them, for the layout test. SwiftPM only defines NDEBUG for
// the C compile, so Swift always sees Flecs' debug layout; these catch a struct whose size depends
// on it.
#define SCREAM_LAYOUT(T) \
    size_t screamSizeOf_##T(void); \
    size_t screamAlignOf_##T(void);

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

#undef SCREAM_LAYOUT

#ifdef __cplusplus
}
#endif

#endif

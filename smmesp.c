#ifndef PGE_RELATIONAL_MEMORY_H
#define PGE_RELATIONAL_MEMORY_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdalign.h>

#define PGE_CACHE_LINE_BYTES 64
#define PGE_STREAM_LANE_SIZE 256

typedef enum {
    PGE_EVID_DIRECT_OBSERVED = 0x00,
    PGE_EVID_INFERRED        = 0x01,
    PGE_EVID_REPORTED        = 0x02
} pge_evid_t;

typedef enum {
    PGE_REL_CURRENT_POS = 0x00,
    PGE_REL_DOWNSTREAM  = 0x01,
    PGE_REL_UPSTREAM    = 0x02,
    PGE_REL_TRANSVERSE  = 0x03
} pge_rel_vector_t;

#pragma pack(push, 1)
/**
 * Strict 64-byte aligned cache node.
 * Guaranteed invariant across 32-bit and 64-bit compilation targets.
 */
typedef struct alignas(PGE_CACHE_LINE_BYTES) pge_stream_node {
    int32_t  payload[8];            /*  0..31 (32 bytes) */
    uint64_t provenance_signature;  /* 32..39 ( 8 bytes) */
    uint8_t  evidentiality;         /* 40     ( 1 byte ) */
    uint8_t  downstream_offset;     /* 41     ( 1 byte ) */
    uint8_t  upstream_offset;       /* 42     ( 1 byte ) */
    uint8_t  reserved[21];          /* 43..63 (21 bytes) */
} pge_stream_node_t;
#pragma pack(pop)

// Compile-time assertion ensuring structure adheres to cache-line width
static_assert(sizeof(pge_stream_node_t) == PGE_CACHE_LINE_BYTES, 
              "pge_stream_node_t must occupy exactly 64 bytes");

typedef struct {
    pge_stream_node_t nodes[PGE_STREAM_LANE_SIZE];
    uint32_t current_head;
    uint32_t active_depth;
    uint8_t  system_trust_ceiling;
} pge_stream_allocator_t;

static inline void pge_stream_init(pge_stream_allocator_t* alloc, pge_evid_t trust_ceiling) {
    alloc->current_head = 0;
    alloc->active_depth = 0;
    alloc->system_trust_ceiling = (uint8_t)trust_ceiling;
    for (size_t i = 0; i < PGE_STREAM_LANE_SIZE; ++i) {
        alloc->nodes[i].evidentiality = PGE_EVID_REPORTED;
        alloc->nodes[i].downstream_offset = 1;
        alloc->nodes[i].upstream_offset = 1;
        alloc->nodes[i].provenance_signature = 0;
    }
}

static inline pge_stream_node_t* pge_stream_advance(
    pge_stream_allocator_t* alloc, 
    pge_rel_vector_t vector, 
    pge_evid_t evidentiality
) {
    if ((uint8_t)evidentiality > alloc->system_trust_ceiling) {
        return NULL;
    }

    uint32_t target_index;
    switch (vector) {
        case PGE_REL_DOWNSTREAM:
            target_index = (alloc->current_head + 1) % PGE_STREAM_LANE_SIZE;
            break;
        case PGE_REL_UPSTREAM:
            target_index = (alloc->current_head + PGE_STREAM_LANE_SIZE - 1) % PGE_STREAM_LANE_SIZE;
            break;
        case PGE_REL_TRANSVERSE:
            target_index = (alloc->current_head + 16) % PGE_STREAM_LANE_SIZE;
            break;
        case PGE_REL_CURRENT_POS:
        default:
            target_index = alloc->current_head;
            break;
    }

    pge_stream_node_t* node = &alloc->nodes[target_index];
    node->evidentiality = (uint8_t)evidentiality;
    alloc->current_head = target_index;

    if (alloc->active_depth < PGE_STREAM_LANE_SIZE) {
        alloc->active_depth++;
    }

    return node;
}

#endif // PGE_RELATIONAL_MEMORY_H

#include <stdio.h>
#include <assert.h>
#include "pge_relational_memory.h"

int main(void) {
    // Assert struct alignment and size invariants
    assert(sizeof(pge_stream_node_t) == 64);
    assert(alignof(pge_stream_node_t) == 64);

    // Verify individual member byte offsets
    assert(offsetof(pge_stream_node_t, payload) == 0);
    assert(offsetof(pge_stream_node_t, provenance_signature) == 32);
    assert(offsetof(pge_stream_node_t, evidentiality) == 40);
    assert(offsetof(pge_stream_node_t, downstream_offset) == 41);
    assert(offsetof(pge_stream_node_t, upstream_offset) == 42);
    assert(offsetof(pge_stream_node_t, reserved) == 43);

    pge_stream_allocator_t alloc;
    pge_stream_init(&alloc, PGE_EVID_INFERRED);

    // Test upstream wrap-around indexing
    pge_stream_node_t* n0 = pge_stream_advance(&alloc, PGE_REL_CURRENT_POS, PGE_EVID_DIRECT_OBSERVED);
    assert(n0 != NULL);
    assert(alloc.current_head == 0);

    pge_stream_node_t* n_up = pge_stream_advance(&alloc, PGE_REL_UPSTREAM, PGE_EVID_INFERRED);
    assert(n_up != NULL);
    assert(alloc.current_head == PGE_STREAM_LANE_SIZE - 1);

    // Test evidential threshold rejection
    pge_stream_node_t* n_bad = pge_stream_advance(&alloc, PGE_REL_DOWNSTREAM, PGE_EVID_REPORTED);
    assert(n_bad == NULL); // Must be rejected by INFERRED ceiling

    printf("[PASS] ABI struct offsets and relational allocator verified for target architecture.\n");
    return 0;
}

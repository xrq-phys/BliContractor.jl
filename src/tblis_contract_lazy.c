#include <stdint.h>
#include <stdio.h>
#include "tblis.h"

#ifdef EXPAND_NAME
#undef EXPAND_NAME
#endif
#define EXPAND_NAME( funcname, typechar ) tblis_##funcname##_##typechar

#ifdef PASTE_DEF
#undef PASTE_DEF
#endif
#define PASTE_DEF( typename, typechar ) \
void EXPAND_NAME( contract, typechar ) \
    (uint8_t *addrA, uint64_t ndA, long *szA, long *stA, long sftA, char *idxA, \
     uint8_t *addrB, uint64_t ndB, long *szB, long *stB, long sftB, char *idxB, \
     uint8_t *addrC, uint64_t ndC, long *szC, long *stC, long sftC, char *idxC, \
     typename *alpha, typename *beta) \
{ \
    tblis_tensor A, B, C; \
    if (*alpha == (typename)1.0) { \
        EXPAND_NAME(init_tensor, typechar)(&A, ndA, szA, (typename *)(addrA + sftA), stA); \
    } else { \
        /* Scale A with Alpha. */ \
        EXPAND_NAME(init_tensor_scaled, typechar)(&A, *alpha, ndA, szA, (typename *)(addrA + sftA), stA); \
    } \
    EXPAND_NAME(init_tensor, typechar)(&B, ndB, szB, (typename *)(addrB + sftB), stB); \
\
    /* Note: Beta*C branches w.r.t. 1.0 instead of 0.0. */ \
    if (*beta == (typename)1.0) { \
        EXPAND_NAME(init_tensor, typechar)(&C, ndC, szC, (typename *)(addrC + sftC), stC); \
    } else { \
        EXPAND_NAME(init_tensor_scaled, typechar)(&C, *beta, ndC, szC, (typename *)(addrC + sftC), stC); \
    } \
\
    tblis_tensor_mult(NULL, NULL, \
                      &A, idxA, \
                      &B, idxB, \
                      &C, idxC); \
}

PASTE_DEF( float,    s )
PASTE_DEF( double,   d )
PASTE_DEF( scomplex, c )
PASTE_DEF( dcomplex, z )


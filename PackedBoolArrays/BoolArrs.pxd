from libc.stdint cimport uintptr_t
cdef extern from "stdint.h":
    ctypedef unsigned long long uint64_t
ctypedef struct uint64BoolArr:
    uint64_t *bools
    int bitLen

ctypedef struct padBool64:
    int *data
    int padLen
    int trueLen

cdef void unpack_ba64_ba(int *to, uint64BoolArr *fro)

cdef void u64ba_mask(uint64BoolArr *to_mask, uint64BoolArr *mask, uint64BoolArr *to_store) 

cdef padBool64* paddedBA_init(int *input, int length)

cdef void paddedBA_free(padBool64 *to_free)

cdef int u64ba_compare(uint64BoolArr *vector1, uint64BoolArr *vector2)

cdef inline void bintArr_to_int(unsigned int *to, int *fro)

cdef inline void intArr_to_uint64(uint64_t *to, unsigned int *fro)

cdef void padBI64_to_uint64BA(uint64_t *to, padBool64 *fro)

cdef void create_uint64BA_from_padBI64(uint64BoolArr *data, padBool64 *fro)

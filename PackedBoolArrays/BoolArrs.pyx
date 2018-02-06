from cpython cimport array
import array
from cBoolArrs cimport uint64BoolArr, padBool64
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from libc.stdlib cimport malloc, calloc, free

cdef void unpack_ba64_ba(int *to, uint64BoolArr *fro):
    """Takes a uint64BoolArr and takes the containing uint64_t array and represents each bit as a single int of 1 or 0.
    
    **Process**
    1. Create looping variables i and j set to 0
    2. Initiate uint64_t to contain current uint64_t that is being unpacked
    3. Loop over every value 0 (inclusive) to fro.bitLen/64+1 using i as loop variable  
    4. Set the cur to the fro.bools[i] or set the cur to the next uint64_t to be unpacked
    5. Loop over 0 (inclusive) to 64 (exclusive) as j
    6. Set the corresponding array value in to as the uint64BoolArr's bit
        a. The array index is calculated as i [the index of the current uint we are unpacking] times 64 [length of a uint64_t] plus j [the number of bits we have already packed into to]
        b. The bit is calculated by bit shifting the uint64_t right 63-j times and then bit shift and with 000...01.
            - This works as it bit shifts t
            - May be able to be optimized if on hardware without a logical shift/ barrell shifter. Out platform was Intel Haswell and above which has the shl assembly command as hardware. 
    :param fro: Pointer to uint64BoolArr which the data to pack will be retrieved from. Also contains information on array length.
    :param to: Pointer to int array we are going to be putting the uint64 bits into. MUST BE OF LENGTH fro.bitLen+64
    """
    cdef int i = 0
    cdef int j = 0
    cdef uint64_t cur = 0
    cdef uint64_t curBit = 1
    for i in range((fro.bitLen/64)+1):
        cur = fro.bools[i]
        #print "Start at :", cur
        curBit = 1
        for j in range(64):
            to[((i)*64)+j] = <int> ((cur >> 63-j)&curBit)

cdef void u64ba_mask(uint64BoolArr *to_mask, uint64BoolArr *mask, uint64BoolArr *store_to):
    cdef int *unpack_to_mask = <int *>calloc((to_mask.bitLen/64+1)*64, sizeof(int))
    cdef int *unpack_mask = <int *>calloc((mask.bitLen/64+1)*64, sizeof(int))
    cdef int *inter = <int *>calloc((mask.bitLen/64+1)*64, sizeof(int))
    cdef int i = 0
    cdef int cur_bit = 0
    unpack_ba64_ba(unpack_to_mask, to_mask)
    unpack_ba64_ba(unpack_mask, mask)
    for i in range(to_mask.bitLen/64+1):
        store_to.bools[i] = 0
    for i in range(to_mask.bitLen):
        if unpack_mask[i] == 0:
            inter[cur_bit] = unpack_to_mask[i]
            cur_bit+=1
    cdef padBool64 *to_uint = paddedBA_init(inter, mask.bitLen)
    create_uint64BA_from_padBI64(store_to, to_uint)
    store_to.bitLen = cur_bit
    paddedBA_free(to_uint)
    free(unpack_to_mask)
    free(unpack_mask)
    free(inter)

cdef padBool64* paddedBA_init(int *input, int length):
    """Create a padBool64 from an array of integers each representing a 1 or 0.
    **Process**
    1. Create the padBool64 pointer
    2. Calculate the padded length as the integer divison of the length of the array divided by 64 plus 64.
        -This is done as the int divison will round down and we need the extra bits to be present so the array is divisible by 64
    3. Malloc and int array to store the data to 
    4. For 0 to function parameter length store input[i] to new.data[i] 
    5. For the remaining bits to the padded length set the ints to 0
    6. set the padLen, and trueLen attributes
    7. Return the pointer
    :param input: pointer to int array of ones and zeroes 
    """
    cdef padBool64 *new = <padBool64 *>PyMem_Malloc(sizeof(padBool64))
    cdef int paddedLen = ((length/64)+1)*64
    new.data = <int *>PyMem_Malloc(paddedLen*sizeof(int))
    cdef int i = 0
    for i in range(length):
        new.data[i]=input[i]
    for i in range(paddedLen-length):
        new.data[i+length]=0
    new.padLen = paddedLen
    new.trueLen = length
    return new

cdef int u64ba_compare(uint64BoolArr *vector1, uint64BoolArr *vector2):
    """Compares two uint64BoolArs and returns an int of -1 if they are the same, or the index of their first difference. Used for testing.
    """
    cdef int i = 0
    for i in range(vector1.bitLen/64+1):
        if vector1.bools[i] != vector2.bools[i]:
            return i
    return -1

cdef void paddedBA_free(padBool64 *to_free):
    """Frees the struct from memory, this exists as it allows the developer to keep tracker of which malloc should be used to allocate memory for it.
    ..Warning:
    - Uses PyMem_Malloc/PyMem_Free as the code is not performance critical.
    - Using PyMem allows for the memory to be deallocated by the python interpreter if there is a memory leak.
    - That may require dereferencing the python reference to the C/Cython/Python object which called it
    :param to_free: pointer to struct to free
    """
    PyMem_Free(to_free.data)
    PyMem_Free(to_free)

cdef inline void bintArr_to_int(unsigned int *to, int *fro):
    """Packs array of 32 int 1 or 0s into a single integer
    **Process**
    1. Create looping variable i, set i=0 
    2. Over the range 0 (inclusive) to 32 (exclusive) pack a bit into to[0]
        a. bitshift the bit at i left 31-i times
        b. add that to to[0]
    :param to: int array/pointer of 1 int. Data will be packed into here.
    :param fro: int array of 1 and 0s must be at least 32 bits in length
    """
    cdef int i = 0
    for i in range(32):
        to[0]+= (fro[i] << (31-i))

cdef inline void intArr_to_uint64(uint64_t *to, unsigned int *fro):
    """Takes a pointer to an array of 2 ints which contain bit vector packed into it and packs those into a uint64_t at another pointer. 
    **Process**
    1. Create a uint64_t called new to pack the bits into. Set new to 0
    2. Create uint64_t front and back set to fro[0] and fro[1] respectively 
    3. To actually pack bits use new = ((front << 32) | back)
        a. Bit shift left front 32 times placing its bits in the upper half of a uint64_t
        b. bitwise xor that value with back which is contained in the lower half of a uint64_t
        c. result is one uint64_t with fro[0] as the first 32 bits and fro[1] as the final 32 bits.
    4. Sets the value at to[0] to the value of new
    
    :param to: pointer to uint64_t (or an array only the first element will be changed) which the data will be packed into
    :param fro: pointer to int array of 2 elements (or more only the first two will be accessed) which currently stores the data
    """
    cdef uint64_t new = 0
    cdef uint64_t front = 0 + fro[0]
    cdef uint64_t back = 0 + fro[1]
    new = ((front << 32) | back)
    to[0] = new

cdef void padBI64_to_uint64BA(uint64_t *to, padBool64 *fro):
    """Takes a padBool64 and packs the bits into a uint64_t bool array
    **Process**
    1. Create loop variable i, set i=0, PyMem_Malloc memory for an array of unsigned ints the length of the padded length of fro
    2. 0 out all ints in iArr
    3. For each 32 bits [i*32 to (i+1)*32] in fro pack them into iArr at i using bint_to_int
    4. For each 2 int in iArr pack to a single uint64_t in to using intArr_to_uint64
    5. Free iArr
    :param to: uint64_t array to pack data from padBool64 into. MUST BE AT LEAST fro.padLen/64 in length
    :param fro: padBool64 array containing the bit vectors as int 1 and 0s 0 padded to a length divisible by 64.
    """
    cdef int i = 0
    cdef unsigned int *iArr = <unsigned int *>PyMem_Malloc((fro.padLen/32)*sizeof(unsigned int))
    for i in range(fro.padLen/32):
        iArr[i] = 0
    for i in range(fro.padLen/32):
        bintArr_to_int(&(iArr[i]), &(fro.data[i*32]))
    for i in range(fro.padLen/64):
        to[i] = 0
        intArr_to_uint64(&(to[i]),&(iArr[i*2]))
    PyMem_Free(iArr)

cdef void create_uint64BA_from_padBI64(uint64BoolArr *data, padBool64 *fro):
    """Fills a uint64BoolArr from a padBool64 via padBI64_to_uint64BA, then fills in the bitLen attribute.
    
    :param data: uint64BoolArr where all the data will be stored
    :param fro: padBool64 where all the data will be pulled from
    """
    padBI64_to_uint64BA(data.bools, fro)
    data.bitLen = fro.trueLen

cdef class BoolArrPy:
    cdef uint64BoolArr *data

    def __init__(self, intBits):
        """Creates a Python wrapper for a bool arg.
    To use a BoolArr in a function you create a function which takes two uint64BoolArrs and their length as agruments, or the length can be taken from the uint64BoolArrs, but they must be checked to make sure they conform to the operations requirements.
    Wrap it in a python function which takes two BoolArrPy, and operates on the uint64BoolArrs by retrieving the BoolArrPy.data property. This should be done in Cython."""
        self.alloc_arr(len(intBits))
        self.create_arr_py(intBits)

    def alloc_arr(self, int lenBits):
        self.data = <uint64BoolArr *>PyMem_Malloc(sizeof(uint64BoolArr))
        self.data.bools = <uint64_t *> PyMem_Malloc(((lenBits/64)+1)*sizeof(uint64_t))
        self.data.bitLen = lenBits

    def create_arr_py(self, int[:] intBits):
        cdef int lenBits = len(intBits)
        cdef int *intArrRaw = <int *>PyMem_Malloc((lenBits)*sizeof(int))
        for i in range(lenBits):
            intArrRaw[i] = <int> intBits[i]
        cdef padBool64 *arrWrapped = paddedBA_init(intArrRaw, lenBits)
        PyMem_Free(intArrRaw)
        create_uint64BA_from_padBI64(self.data , arrWrapped)
        PyMem_Free(arrWrapped)


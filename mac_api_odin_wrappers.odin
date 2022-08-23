package main
import NS "vendor:darwin/Foundation"
import "core:mem"
import "core:time"

cfnum :: #force_inline proc (number: int) -> CFNumberRef  {
    n := number
    return CFNumberCreate(nil, .kCFNumberLongType, &n)
}
cfarray :: #force_inline proc(objs: []$T) -> CFArrayRef {
    objs_ptr := cast([^]CFTypeRef)raw_data(objs)
    return CFArrayCreate(nil, objs_ptr, auto_cast len(objs), &kCFTypeArrayCallBacks)
}

cfdictionary :: proc(key_values_alternating: ..CFTypeRef) -> CFDictionaryRef {
    scoped_temp_memory()

    assert(len(key_values_alternating) % 2 == 0 && len(key_values_alternating) > 0)
    keys := make([]CFTypeRef, len(key_values_alternating)/2)
    values := make([]CFTypeRef, len(key_values_alternating)/2)
    for i := 0; i < len(key_values_alternating); i += 2 {
        keys[i/2] = auto_cast key_values_alternating[i]
        values[i/2] = auto_cast key_values_alternating[i+1]
    }
    return CFDictionaryCreate(nil, 
        raw_data(keys), raw_data(values), 
        auto_cast len(keys), &kCFCopyStringDictionaryKeyCallBacks, 
        &kCFTypeDictionaryValueCallBacks) 
}
cfarray_int :: proc(ints: ..int) -> CFArrayRef {
    scoped_temp_memory()

    num_objs := make([]CFNumberRef, len(ints))
    for num, i in ints {
        num_objs[i] = cfnum(num)
    }
    defer {
        for num_obj in num_objs {
            CFRelease(num_obj)
        }
    }

    return cfarray(num_objs)
}
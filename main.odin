package main
import "core:fmt"
import "core:io"
import "core:mem"
import "core:os"

main :: proc() {
    register_custom_type_formatters()
    if len(os.args) != 2 && len(os.args) != 3 {
        print("Usage: %v <cdi image> [--print-tracks]", os.args[0])
        return
    }
    filename := os.args[1]
    should_print_track_listing := len(os.args) == 3 && os.args[2] == "--print-tracks"
    data, success := os.read_entire_file_from_filename(filename)
    if !success {
        burn_session_error("Failed to read {}. Exiting...\n", filename)
    }

    burn_session_arena: mem.Arena
    mem.arena_init(&burn_session_arena, make([]byte, 4 * mem.Gigabyte))
    context.allocator = mem.arena_allocator(&burn_session_arena)

    dreamcast_disc := parse_dreamcast_cdi_data(data)
    if !should_print_track_listing {
        burn_dreamcast_disc(dreamcast_disc)
    } else {
        // test_disc_eject()
        print_track_listing(dreamcast_disc)
        os.write_entire_file("iso_test.iso", dreamcast_disc.data_session.tracks[0].sectors)
    }
}

print_track_listing :: proc(disc: DreamcastDisc) {
    print_track :: proc(session: DiscSession) {
        for track in session.tracks {
            pregap_count, sector_count := sector_count_of_track(track)
            pregap_msf, actual_msf := msf_of_track(track)
            print("\tTrack %v:", track.number)
            print("\t\tLBA start %v:", track.start_lba)
            print("\t\tPregap %v:%v.%v, %v bytes, %v sectors", 
                pregap_msf.minutes, pregap_msf.seconds, pregap_msf.frames,
                track.number_of_pregap_bytes, pregap_count)
            print("\t\tActual %v:%v.%v, %v bytes, %v sectors",
                actual_msf.minutes, actual_msf.seconds, actual_msf.frames,
                len(track.sectors), sector_count)
        }
    }
    print("Audio Session:")
    print_track(disc.audio_session)
    print("Data Session:")
    print_track(disc.data_session)
}

//utilities
print :: proc(format: string, args: ..any) {
    fmt.printf(format, ..args)
    fmt.println()
}
burn_session_error :: proc(format: string, args: ..any) -> ! {
    print(format, ..args)
    os.exit(1)
}
register_custom_type_formatters :: proc() {
    cfstring_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
        scoped_temp_memory()

        cfstr := arg.(CFStringRef)
        character_length := CFStringGetLength(cfstr)
        buffer_length := CFStringGetMaximumSizeForEncoding(character_length, .kCFStringEncodingUTF8) + 1
        buffer := make([]byte, buffer_length)

        if CFStringGetCString(cfstr, raw_data(buffer[:]), auto_cast len(buffer), .kCFStringEncodingUTF8) != 0 {
            str_len: int
            for ; buffer[str_len] != 0; str_len += 1 {}
            _, err := io.write(fi.writer, buffer[:str_len])
            return err == .None
        }
        return false
    }
    cfobject_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
        cfobj: CFTypeRef
        switch obj in arg {
            case CFArrayRef: cfobj = auto_cast obj
            case CFDictionaryRef: cfobj = auto_cast obj
            case CFNumberRef: cfobj = auto_cast obj
            case CFBooleanRef: cfobj = auto_cast obj
        }
        cfstr :=  CFCopyDescription(cfobj)
        defer CFRelease(cfstr)
        return cfstring_formatter(fi, cfstr, verb)
    }
    @(static)user_formatters: map[typeid]fmt.User_Formatter
    fmt.set_user_formatters(&user_formatters)

    err := fmt.register_user_formatter(CFStringRef, cfstring_formatter) 
    assert(err == .None)
    err = fmt.register_user_formatter(CFDictionaryRef, cfobject_formatter) 
    assert(err == .None)
    err = fmt.register_user_formatter(CFArrayRef, cfobject_formatter) 
    assert(err == .None)
    err = fmt.register_user_formatter(CFNumberRef, cfobject_formatter) 
    assert(err == .None)
    err = fmt.register_user_formatter(CFBooleanRef, cfobject_formatter) 
    assert(err == .None)
    
}
@(deferred_out=mem.end_arena_temp_memory)
scoped_temp_memory :: proc() -> mem.Arena_Temp_Memory {
    return mem.begin_arena_temp_memory(auto_cast context.allocator.data)
}
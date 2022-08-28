package main
import "core:fmt"
import "core:io"
import "core:mem"
import "core:os"

ProgramState :: struct {
    is_verbose: bool,
}

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

    program_state := ProgramState {
        is_verbose = false,
    }
    context.user_ptr = &program_state

    dreamcast_disc := parse_dreamcast_cdi_data(data)
    if !should_print_track_listing {
        burn_dreamcast_disc(dreamcast_disc)
    } else {
        // test_disc_eject()
        print_track_listing(dreamcast_disc)
        os.write_entire_file("iso1.iso", dreamcast_disc.audio_session.tracks[0].sectors)
        os.write_entire_file("iso2.iso", dreamcast_disc.data_session.tracks[0].sectors)
    }
}

print_track_listing :: proc(disc: DreamcastDisc) {
    end_lba := 0
    total_disc_sectors := 0
    LBA_OFFSET :: 150
    {
        print("Audio Session:")
        total_sector_count := 0
        total_byte_count := 0
        for track, i in disc.audio_session.tracks {
            pregap_count, sector_count := sector_count_of_track(track)
            //Pregap starts before the actual track, pregap LBA is negative for the first track
            start_pregap_lba := track.start_lba - pregap_count
            pregap_start_msf := sectors_to_msf(start_pregap_lba+pregap_count)
            pregap_end_msf := sectors_to_msf(start_pregap_lba+pregap_count+pregap_count)

            end_lba = track.start_lba+sector_count
            actual_start_msf := sectors_to_msf(track.start_lba+LBA_OFFSET)
            actual_end_msf := sectors_to_msf(end_lba+LBA_OFFSET)

            print("\tTrack %v, Mode: %v", i+1, track.mode)
            print("\t\tPregap: %v:%v.%v - %v:%v.%v, %v sectors, %v bytes, LBA: %v",
                pregap_start_msf.minutes, pregap_start_msf.seconds, pregap_start_msf.frames,
                pregap_end_msf.minutes, pregap_end_msf.seconds, pregap_end_msf.frames,
                pregap_count, track.number_of_pregap_bytes, start_pregap_lba) 
            print("\t\tActual: %v:%v.%v - %v:%v.%v, %v sectors, %v bytes, LBA: %v",
                actual_start_msf.minutes, actual_start_msf.seconds, actual_start_msf.frames,
                actual_end_msf.minutes, actual_end_msf.seconds, actual_end_msf.frames,
                sector_count, len(track.sectors), track.start_lba) 
            total_sector_count += pregap_count + sector_count
            total_byte_count += track.number_of_pregap_bytes + len(track.sectors)
        }
        msf := sectors_to_msf(total_sector_count)
        print("\tTotal %v:%v.%v, %v sectors, %v bytes, end LBA: %v",
            msf.minutes, msf.seconds, msf.frames, total_sector_count, 
            total_byte_count, end_lba)
    }
    {
        print("Data Session:")
        total_sector_count := 0
        total_byte_count := 0
        for track, i in disc.data_session.tracks {
            pregap_count, sector_count := sector_count_of_track(track)
            //Pregap starts before the actual track, pregap LBA is negative for the first track
            start_pregap_lba := track.start_lba - pregap_count
            pregap_start_msf := sectors_to_msf(start_pregap_lba+pregap_count)
            pregap_end_msf := sectors_to_msf(start_pregap_lba+pregap_count+pregap_count)

            end_lba = track.start_lba+sector_count
            actual_start_msf := sectors_to_msf(track.start_lba+LBA_OFFSET)
            actual_end_msf := sectors_to_msf(end_lba + LBA_OFFSET)

            print("\tTrack %v, Mode: %v", i+1, track.mode)
            print("\t\tPregap: %v:%v.%v - %v:%v.%v, %v sectors, %v bytes, LBA: %v",
                pregap_start_msf.minutes, pregap_start_msf.seconds, pregap_start_msf.frames,
                pregap_end_msf.minutes, pregap_end_msf.seconds, pregap_end_msf.frames,
                pregap_count, track.number_of_pregap_bytes, start_pregap_lba) 
            print("\t\tActual: %v:%v.%v - %v:%v.%v, %v sectors, %v bytes, LBA: %v",
                actual_start_msf.minutes, actual_start_msf.seconds, actual_start_msf.frames,
                actual_end_msf.minutes, actual_end_msf.seconds, actual_end_msf.frames,
                sector_count, len(track.sectors), track.start_lba) 
            total_sector_count += pregap_count + sector_count
            total_byte_count += track.number_of_pregap_bytes + len(track.sectors)
        }
        msf := sectors_to_msf(total_sector_count)
        print("\tTotal %v:%v.%v, %v sectors, %v bytes, end LBA: %v",
            msf.minutes, msf.seconds, msf.frames, total_sector_count, 
            total_byte_count, end_lba)
    }
    msf := sectors_to_msf(end_lba+LBA_OFFSET)
    print("Disc End %v:%v.%v, LBA: %v",
        msf.minutes, msf.seconds, msf.frames, end_lba)
}

//utilities
print :: proc(format: string, args: ..any) {
    fmt.printf(format, ..args)
    fmt.println()
}
print_verbose :: proc(format: string, args: ..any) {
    program_state := cast(^ProgramState)context.user_ptr
    if !program_state.is_verbose {
        return
    }
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
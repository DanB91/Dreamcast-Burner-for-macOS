package main

import "core:mem"
import "core:runtime"
import "core:fmt"
import NS "vendor:darwin/Foundation"

DiscBurningThreadContext :: struct {
    disc: DreamcastDisc,
    track_map: map[DRTrackRef]Track,
    percentage: f64,
    did_print_error: bool,
    ctx: runtime.Context,
    arena: mem.Arena,
}
burning_thread_context: DiscBurningThreadContext


init_burner :: proc() -> DRBurnRef {
    burner_devices := DRCopyDeviceArray()
    defer CFRelease(burner_devices)

    burner_devices_len := CFArrayGetCount(burner_devices)
    if (burner_devices_len == 0) {
        burn_session_error("No CD burners available!")
    }

    device := cast(DRDeviceRef)CFArrayGetValueAtIndex(burner_devices, 0)
    
    burner := DRBurnCreate(device)

    //lowest speed
    CD_8X :: 150*8
    burner_speed := cfnum(CD_8X)
    defer CFRelease(burner_speed)

    burner_properties := cfdictionary(
        kDRBurnRequestedSpeedKey, burner_speed,
        //kDRBurnTestingKey, kCFBooleanTrue,
        //kDRBurnStrategyKey, kDRBurnStrategyCDSAO,
        //kDRBurnStrategyIsRequiredKey, kCFBooleanTrue,
    )
    defer CFRelease(burner_properties)

    //DRBurnSetProperties(burner, burner_properties)

    return burner
}
burn_handle_notification :: proc "c" (center: DRNotificationCenterRef, 
    observer: rawptr, name: CFStringRef, object: rawptr, info: CFDictionaryRef) {
    context = burning_thread_context.ctx
    
    print_verbose("Burn notification name: %v, info %v", name, info)
    status_state := cast(CFStringRef)CFDictionaryGetValue(info, kDRStatusStateKey)
    progress_cfnum := 
        cast(CFNumberRef)CFDictionaryGetValue(info, kDRStatusPercentCompleteKey)
    if progress_cfnum != nil {
        progress: f64
        CFNumberGetValue(progress_cfnum, .kCFNumberFloat64Type, &progress)
        if progress >= 0 {
            fmt.printf("Progress: %.2f%%\r", progress * 100)
        }
    } else if error_status := cast(CFDictionaryRef)CFDictionaryGetValue(info, kDRErrorStatusKey); 
        error_status != nil && !burning_thread_context.did_print_error {

        defer burning_thread_context.did_print_error = true

        error_code_cfnum := cast(CFNumberRef)CFDictionaryGetValue(error_status, kDRErrorStatusErrorKey)
        error_code: OSStatus
        CFNumberGetValue(error_code_cfnum, .kCFNumberLongType, &error_code)

        error_string := cast(CFStringRef)CFDictionaryGetValue(error_status, kDRErrorStatusErrorStringKey)
        error_additional_string := cast(CFStringRef)CFDictionaryGetValue(error_status, kDRErrorStatusAdditionalSenseStringKey)

        print("\nError burning disc! Code: 0x%X", error_code)
        if error_additional_string != nil {
            print("\t%v -- %v", error_string, error_additional_string)
        } else {
            print("\t%v", error_string)
        }
        

    }

    if CFStringCompare(status_state, kDRStatusStateFailed, 0) == 0 {
        print("\nBurn failed!")
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
    if CFStringCompare(status_state, kDRStatusStateDone, 0) == 0 {
        fmt.printf("Progress: %.2f%%\r", 100.0)
        print("\nBurn success!")
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
}

//where all the magic happens
burn_callback :: proc "c" (drtrack: DRTrackRef, message: DRTrackMessage, io_param: rawptr) -> OSStatus {
    DISABLE_WRITING :: false 
    DRTrackProductionInfo :: struct {
        buffer: rawptr,	//In - The buffer to produce into.
        req_count: u32, //In - The number of bytes requested by the engine.
        act_count: u32, //Out - The number of bytes actually produced (between 0 and reqCount)
        flags: u32, //InOut - Miscellaneous flags.
        block_size: u32, //In - The block size the engine is expecting.
        requested_address: u64, //In - The byte address that the burn engine is requesting from the 
								//object (0-based). This increments when you send data, as one 
							    //would expect. 
    }
    write_data :: proc(prod_info: ^DRTrackProductionInfo, track_data: []byte) -> bool {
        when DISABLE_WRITING {
            return false
        }
        requested_address := cast(int)prod_info.requested_address
        req_count := cast(int)prod_info.req_count
        if requested_address+req_count > len(track_data) {
            print("Requested address %v with count %v is out of bounds for data of len %v",
                requested_address, req_count, len(track_data))
            return false
        }
        dst := (cast([^]byte)prod_info.buffer)[:req_count]
        src := track_data[requested_address:requested_address+req_count]
        copy(dst, src)
        prod_info.act_count = auto_cast req_count
        return true
    }
    write_pregap :: proc(prod_info: ^DRTrackProductionInfo) -> bool {
        when DISABLE_WRITING {
            return false
        }
        requested_address := cast(int)prod_info.requested_address
        req_count := cast(int)prod_info.req_count
        dst := (cast([^]byte)prod_info.buffer)[:req_count]
        mem.zero_slice(dst)
        prod_info.act_count = auto_cast req_count
        return true
    }
    verify_data :: proc(prod_info: ^DRTrackProductionInfo, track_data: []byte) -> bool {
        when DISABLE_WRITING {
            return false
        }
        requested_address := cast(int)prod_info.requested_address
        req_count := cast(int)prod_info.req_count
        if requested_address+req_count > len(track_data) {
            return false
        }
        disc_data := (cast([^]byte)prod_info.buffer)[:req_count]
        image_data := track_data[requested_address:requested_address+req_count]
        return mem.compare(disc_data, image_data) == 0
    }
    verify_pregap :: proc(prod_info: ^DRTrackProductionInfo) -> bool {
        when DISABLE_WRITING {
            return false
        }
        requested_address := cast(int)prod_info.requested_address
        req_count := cast(int)prod_info.req_count
        disc_data := (cast([^]byte)prod_info.buffer)[:req_count]
        for b in disc_data {
            if b != 0 {
                return false
            }
        }
        return true
    }
    noErr :: 0
    kDRFunctionNotSupportedErr :: 0x80020067
    kDRVerificationFailedErr :: 0x80020063
    kDRDataProductionErr :: 0x80020062

    context = burning_thread_context.ctx
    track := burning_thread_context.track_map[drtrack]

    switch message {
        case .kDRTrackMessagePreBurn:	
            return noErr
        case .kDRTrackMessageProduceData:
            prod_info := cast(^DRTrackProductionInfo)io_param
            if prod_info.flags != 0 {
                print("Non-zero flags detected for data production: %v", prod_info) 
                return kDRFunctionNotSupportedErr
            }
            {
                i := cast(int)prod_info.requested_address
                n := cast(int)prod_info.req_count
                drtrack_properties := DRTrackGetProperties(drtrack)
                print_verbose("Writing data bytes %v to %v for track %v", i, i + n, track.number)
                print_verbose("\tTrack properties: %v", drtrack_properties)
            }
            return write_data(prod_info, track.sectors) ? noErr : kDRDataProductionErr
        case .kDRTrackMessageVerificationStarting:
        case .kDRTrackMessageVerificationDone:
        case .kDRTrackMessageVerifyData:
            prod_info := cast(^DRTrackProductionInfo)io_param
            return verify_data(prod_info, track.sectors) ? noErr : kDRVerificationFailedErr
        case .kDRTrackMessagePostBurn:			
            return noErr
        case .kDRTrackMessageEstimateLength:
        case .kDRTrackMessageProducePreGap:
            if track.number_of_pregap_bytes == 0 {
                return kDRFunctionNotSupportedErr
            }
            prod_info := cast(^DRTrackProductionInfo)io_param
            if prod_info.flags != 0 {
                print("Non-zero flags detected for pregap production: %v", prod_info) 
                return kDRFunctionNotSupportedErr
            }
            {
                i := cast(int)prod_info.requested_address
                n := cast(int)prod_info.req_count
                print_verbose("Writing pregap bytes %v to %v for track %v", i, i + n, track.number)
                print_verbose("\tBlock size:%v, Start LBA: %v", prod_info.block_size, track.start_lba)
            }
            //return write_data(prod_info, track.pregap_sectors) ? noErr : kDRDataProductionErr
            return write_pregap(prod_info) ? noErr : kDRDataProductionErr

            // track_data := track.pregap_sectors
            // write_data(prod_info, track_data)
            // NSLog(NS.AT("Produce Pregap"))
        case .kDRTrackMessageVerifyPreGap:
            prod_info := cast(^DRTrackProductionInfo)io_param
            //return verify_data(prod_info, track.pregap_sectors) ? noErr : kDRVerificationFailedErr
            return verify_pregap(prod_info) ? noErr : kDRVerificationFailedErr
            // NSLog(NS.AT("Verify Pregap"))
    }
    print("Unsupported burn message: %v", message)
    return kDRFunctionNotSupportedErr
}
burn_dreamcast_disc :: proc(disc: DreamcastDisc) {
    scoped_temp_memory()

    burning_thread_context = {
        ctx = runtime.default_context(),
        disc = disc,
    }
    mem.arena_init(&burning_thread_context.arena, make([]byte, 4 * mem.Megabyte))
    burning_thread_context.ctx.allocator = mem.arena_allocator(&burning_thread_context.arena)
    burning_thread_context.ctx.user_ptr = context.user_ptr

    //package audio session into CFArray
    audio_session_layout: CFArrayRef 
    defer CFRelease(audio_session_layout)
    {
        session := disc.audio_session
        drtrack_slice := make([]DRTrackRef, len(session.tracks))
        for track, i in session.tracks {
            drtrack_slice[i] = create_drtrack(track)
            burning_thread_context.track_map[drtrack_slice[i]] = track
        }
        audio_session_layout = cfarray(drtrack_slice)
    }
    //package data session into CFArray
    data_session_layout: CFArrayRef
    defer CFRelease(data_session_layout)
    {
        session := disc.data_session
        drtrack_slice := make([]DRTrackRef, len(session.tracks))
        for track, i in session.tracks {
            drtrack_slice[i] = create_drtrack(track)
            burning_thread_context.track_map[drtrack_slice[i]] = track
        }
        data_session_layout = cfarray(drtrack_slice)
    }

    //package disc layout
    disc_layout: CFArrayRef
    defer CFRelease(disc_layout)
    {
        sessions := [2]CFArrayRef{audio_session_layout, data_session_layout}
        disc_layout = cfarray(sessions[:])
    }

    burner := init_burner() 
    defer CFRelease(burner)

    notification_center := DRNotificationCenterCreate()
    defer CFRelease(notification_center)
    source := DRNotificationCenterCreateRunLoopSource(notification_center)
    defer {
        CFRunLoopSourceInvalidate(source)
        CFRelease(source)
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes)

    DRNotificationCenterAddObserver(notification_center, nil, auto_cast burn_handle_notification, nil, burner)
    defer DRNotificationCenterRemoveObserver(notification_center, auto_cast burn_handle_notification, nil, burner)

    burn_result := DRBurnWriteLayout(burner, disc_layout)
    if burn_result != 0 {
        burn_session_error("Failed to start burning. Error code: 0x%X", burn_result)
    }
    print("Starting burn!")

    CFRunLoopRun();
}


create_drtrack :: proc(track: Track) -> DRTrackRef {
    pregap_length, track_length := sector_count_of_track(track)
    switch track.mode {
        case .Audio:
            return create_cdda_drtrack(pregap_length, track_length)
        case .XAMode2Form1:
            return create_mode2f1_drtrack(pregap_length, track_length)
        case .Mode2, .Mode1:
            burn_session_error("CDI contains unsupported track mode: %v", track.mode)
    }
    return nil
} 

create_cdda_drtrack :: proc (pregap_length, track_length: int) -> DRTrackRef {
    cfnum_track_length := cfnum(track_length)
    defer CFRelease(cfnum_track_length)
    cfnum_pregap_length := cfnum(pregap_length)
    defer CFRelease(cfnum_pregap_length)
    properties := cfdictionary(
        kDRTrackLengthKey, cfnum_track_length,
        kDRPreGapLengthKey, cfnum_pregap_length,
        kDRBlockSizeKey, kDRBlockSizeAudio,
        kDRBlockTypeKey, kDRBlockTypeAudio,
        kDRDataFormKey, kDRDataFormAudio,
        kDRSessionFormatKey, kDRSessionFormatAudio,
        kDRTrackModeKey, kDRTrackModeAudio,
        //kDRPreGapIsRequiredKey, kCFBooleanTrue,
    )
    defer CFRelease(properties)
    print_verbose("Audio track properties: %v", properties)
    return DRTrackCreate(properties, burn_callback)
}
create_mode2f1_drtrack :: proc (pregap_length, track_length: int) -> DRTrackRef {
    cfnum_track_length := cfnum(track_length)
    defer CFRelease(cfnum_track_length)
    cfnum_pregap_length := cfnum(pregap_length)
    defer CFRelease(cfnum_pregap_length)
    properties := cfdictionary(
        kDRTrackLengthKey, cfnum_track_length,
        kDRPreGapLengthKey, cfnum_pregap_length,
        kDRBlockSizeKey, kDRBlockSizeMode2Form1Data,
        kDRBlockTypeKey, kDRBlockTypeMode2Form1Data,
        kDRDataFormKey, kDRDataFormMode2Form1Data,
        kDRSessionFormatKey, kDRSessionFormatCDXA,
        kDRTrackModeKey, kDRTrackMode2Form1Data,
        //kDRPreGapIsRequiredKey, kCFBooleanTrue,
    )
    defer CFRelease(properties)
    print_verbose("Data track properties: %v", properties)
    return DRTrackCreate(properties, burn_callback)
}


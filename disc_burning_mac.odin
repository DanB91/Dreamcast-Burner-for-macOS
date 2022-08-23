package main

import "core:mem"
import "core:runtime"
import "core:time"
import NS "vendor:darwin/Foundation"

DiscBurningThreadContext :: struct {
    disc: DreamcastDisc,
    track_map: map[DRTrackRef]Track,
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
    if false {
        CD_1X :: 150
        burner_speed := cfnum(CD_1X)
        defer CFRelease(burner_speed)

        burner_properties := cfdictionary(kDRBurnRequestedSpeedKey, burner_speed)
        defer CFRelease(burner_properties)

        DRBurnSetProperties(burner, burner_properties)
    }

    return burner
}
burn_dreamcast_disc :: proc(disc: DreamcastDisc) {
    scoped_temp_memory()
    burner := init_burner() 
    defer CFRelease(burner)

    //TODO: add CFRunLoop code
    // notification_center := DRNotificationCenterCreate()
    // defer CFRelease(notification_center)
    // DRNotificationCenterAddObserver(notification_center, 
    //    auto_cast burn_handle_notification, burn_handle_notification, 
    //    kDRBurnStatusChangedNotification, burner)
    // defer DRNotificationCenterRemoveObserver(notification_center, 
    //    auto_cast burn_handle_notification, kDRBurnStatusChangedNotification, burner)
    burning_thread_context = {
        ctx = runtime.default_context(),
        disc = disc,
    }
    mem.arena_init(&burning_thread_context.arena, make([]byte, 4 * mem.Megabyte))
    burning_thread_context.ctx.allocator = mem.arena_allocator(&burning_thread_context.arena)

    
    //package audio session into CFArray
    audio_session_layout: CFArrayRef 
    defer CFRelease(audio_session_layout)
    {
        session := disc.audio_session
        drtrack_slice := make([]DRTrackRef, len(session.tracks))
        for track, i in session.tracks {
            pregap_length, track_length := sector_count_of_track(track)
            drtrack_slice[i] = create_audio_drtrack(pregap_length, 
                track_length, 
                track.start_lba)
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
            pregap_length, track_length := sector_count_of_track(track)
            drtrack_slice[i] = create_data_drtrack(pregap_length, 
                track_length, 
                track.start_lba)
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

    burn_result := DRBurnWriteLayout(burner, disc_layout)
    if burn_result != 0 {
        burn_session_error("Failed to start burning. Error code: 0x%X", burn_result)
    }
    print("Starting burn!")

    for {
        status := DRBurnCopyStatus(burner)
        defer CFRelease(status)

        status_state := cast(CFStringRef)CFDictionaryGetValue(status, kDRStatusStateKey)
        if CFStringCompare(status_state, kDRStatusStateFailed, 0) == 0 {
            NSLog(NS.AT("Burn failed status: %@"), status)
            print("Burn failed!")
            break
        }
        if CFStringCompare(status_state, kDRStatusStateDone, 0) == 0 {
            NSLog(NS.AT("Burn success status: %@"), status)
            print("Burn done!")
            break
        }

        if true {
            time.sleep(100 * time.Millisecond)
        } else {
            NSLog(NS.AT("Burn status: %@"), status)
            time.sleep(10 * time.Second)

        }

    }
}

//TODO: CFRunLoop code
// burn_handle_notification :: proc "c" (center: DRNotificationCenterRef, 
//     observer: rawptr, name: CFStringRef, object: rawptr, info: CFDictionaryRef) {
    

//     NSLog(NS.AT("Burn notification %@"), info)

// }

create_audio_drtrack :: proc (pregap_length, track_length, start_lba: int) -> DRTrackRef {
    cfnum_track_length := cfnum(track_length)
    defer CFRelease(cfnum_track_length)
    cfnum_pregap_length := cfnum(pregap_length)
    defer CFRelease(cfnum_pregap_length)
    cfnum_start_lba := cfnum(start_lba)
    defer CFRelease(cfnum_start_lba)
    properties := cfdictionary(
        kDRTrackLengthKey, cfnum_track_length,
        kDRPreGapLengthKey, cfnum_pregap_length,
        kDRTrackStartAddressKey, cfnum_start_lba,
        kDRBlockSizeKey, kDRBlockSizeAudio,
        kDRBlockTypeKey, kDRBlockTypeAudio,
        kDRDataFormKey, kDRDataFormAudio,
        kDRSessionFormatKey, kDRSessionFormatAudio,
        kDRTrackModeKey, kDRTrackModeAudio,
        kDRPreGapIsRequiredKey, kCFBooleanTrue,
    )
    defer CFRelease(properties)
    return DRTrackCreate(properties, burn_callback)
}
MODE2_BLOCK_SIZE := cfnum(2336)
MODE2_BLOCK_TYPE := cfnum(9)
MODE2_DATA_FORM := cfnum(0x30)
MODE2_SESSION_FORMAT := cfnum(0) //or is it cfnum(0x10) for CD-I??
MODE2_TRACK_MODE := cfnum(4)
create_data_drtrack :: proc (pregap_length, track_length, start_lba: int) -> DRTrackRef {
    cfnum_track_length := cfnum(track_length)
    defer CFRelease(cfnum_track_length)
    cfnum_pregap_length := cfnum(pregap_length)
    defer CFRelease(cfnum_pregap_length)
    cfnum_start_lba := cfnum(start_lba)
    defer CFRelease(cfnum_start_lba)
    properties := cfdictionary(
        kDRTrackLengthKey, cfnum_track_length,
        kDRPreGapLengthKey, cfnum_pregap_length,
        kDRTrackStartAddressKey, cfnum_start_lba,
        kDRBlockSizeKey, kDRBlockSizeMode2Form1Data,
        kDRBlockTypeKey, kDRBlockTypeMode2Form1Data,
        kDRDataFormKey, kDRDataFormMode2Form1Data,
        kDRSessionFormatKey, kDRSessionFormatCDXA,
        kDRTrackModeKey, kDRTrackMode2Form1Data,
        kDRPreGapIsRequiredKey, kCFBooleanTrue,
    )
    // properties := cfdictionary(
    //     kDRTrackLengthKey, cfnum_track_length,
    //     kDRPreGapLengthKey, cfnum_pregap_length,
    //     kDRTrackStartAddressKey, cfnum_start_lba,
    //     kDRBlockSizeKey, MODE2_BLOCK_SIZE,
    //     kDRBlockTypeKey, MODE2_BLOCK_TYPE,
    //     kDRDataFormKey, MODE2_DATA_FORM,
    //     kDRSessionFormatKey, MODE2_SESSION_FORMAT,
    //     kDRTrackModeKey, MODE2_TRACK_MODE,
    // )
    defer CFRelease(properties)
    return DRTrackCreate(properties, burn_callback)
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
            //NSLog(NS.AT("Pre Burn, %@"), io_param)
        case .kDRTrackMessageProduceData:
            prod_info := cast(^DRTrackProductionInfo)io_param
            if prod_info.flags != 0 {
                print("Non-zero flags detected for data production: %v", prod_info) 
                return kDRFunctionNotSupportedErr
            }
            {
                i := cast(int)prod_info.requested_address
                n := cast(int)prod_info.req_count
                print("Writing data bytes %v to %v for track %v", i, i + n, track.number)
                print("\tBlock size:%v, Start LBA: %v", prod_info.block_size, track.start_lba)
            }
            return write_data(prod_info, track.sectors) ? noErr : kDRDataProductionErr
        case .kDRTrackMessageVerificationStarting:
            // NSLog(NS.AT("Verification Starting"))
        case .kDRTrackMessageVerificationDone:
            // NSLog(NS.AT("Verification Done"))
        case .kDRTrackMessageVerifyData:
            prod_info := cast(^DRTrackProductionInfo)io_param
            return verify_data(prod_info, track.sectors) ? noErr : kDRVerificationFailedErr
            // NSLog(NS.AT("Verify Data"))
        case .kDRTrackMessagePostBurn:			
            // NSLog(NS.AT("Post Burn, %@"), io_param)
        case .kDRTrackMessageEstimateLength:
            // NSLog(NS.AT("Estimate Length"))
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
                print("Writing pregap bytes %v to %v for track %v", i, i + n, track.number)
                print("\tBlock size:%v, Start LBA: %v", prod_info.block_size, track.start_lba)
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

    return kDRFunctionNotSupportedErr
}

//test functions
test_disc_eject :: proc() {
    burner_devices: CFArrayRef
    {
        burner_devices = DRCopyDeviceArray()
        defer CFRelease(burner_devices)

        burner_devices_len := CFArrayGetCount(burner_devices)
        for i in 0..<burner_devices_len {
            device := cast(DRDeviceRef)CFArrayGetValueAtIndex(burner_devices, i)
            DRDeviceEjectMedia(device)
        }
    }

    {
        track := create_audio_drtrack(2345, 123456, 43)
        NSLog(NS.AT("DRTrack: %@"), DRTrackGetProperties(track))
    }
}

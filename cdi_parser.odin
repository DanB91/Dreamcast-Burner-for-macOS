package main
import "core:mem"
/*
 Sector Data (sector 00:00:00 and up)          ;-body
  Number of Sessions (1 byte)     <--- located at "Filesize-Footersize"
  DiscSession Block for 1st session (15 bytes)      ;\
  nnn-byte info for 1st track                   ; 1st session
  nnn-byte info for 2nd track (if any)          ;
  etc.                                          ;/
  DiscSession Block for 2nd session (15 bytes)      ;\
  nnn-byte info for 1st track                   ; 2nd session (if any)
  nnn-byte info for 2nd track (if any)          ;
  etc.                                          ;/
  etc.                                          ;-further sessions (if any)
  DiscSession Block for no-more-sessions (15 bytes) ;-end marker
  nnn-byte Disc Info Block                      ;-general disc info
  Entrypoint (4 bytes)            <--- located at "Filesize-4"
 */

CDISession :: struct #packed {
    padding: u8,
    track_count: u16,
    unknown: u32,
}
CDITrackPart1 :: struct #packed {
    marker0: [10]u8,
    marker1: [10]u8,
    settings: [3]u8,
    total_tracks: u8,
    filename_length: u8,
    /* 
    filename: [32]u8,
    unknown0: [11]u8,
    unknown1: u32,
    unknown2: u32,
    unknown3: u32,
    max_cd_length: u32,
    unknown4: u32,
    */
}
CDITrackPart2 :: struct #packed {
    using _: CDITrackHeader,
    // unknown0: [11]u8,
    // unknown1: u32,
    // unknown2: u32,
    // unknown3: u32,
    // max_cd_length: u32,
    // unknown4: u32,

    index_count: u16,
    pregap_sector_count: u32,
    sector_count: u32,
    unknown5: [6]u8,
    track_mode: u32,
    unknown6: u32,
    session_number: u32,
    track_number: u32,
    start_lba: u32,
    total_length: u32,  /* Including pregap (+postgap?) */
    unknown7: [16]u8,
     /*
        |Mode            |Sector Size|
        ----------------------------                  
        0: Mode1,        800h, 2048
        1: Mode2,        920h, 2336
        2: Audio,        930h, 2352
        3: Raw+PQ,       940h, 2352+16 non-interleaved (P=only 1bit)
        4: Raw+PQRSTUVW, 990h, 2352+96 interleaved 
    */
    read_mode: u32, 

    control: u32, 
    unknown8: u8,
    total_length2: u32, /* ??? */
    unknown9: u32,
    isrc_code: [12]u8,
    isrc_valid: u32,
    unknown10: [1 + 8 + 4*4]u8,
    audio_frequency: u32,
    unknown11: [42 + 4 + 12 + 4]u8,

}
CDITrackHeader :: struct #packed {
    unknown0: [11]u8,
    unknown1: u32,
    unknown2: u32,
    unknown3: u32,
    max_cd_length: u32,
    unknown4: u32,
}



CDIDiscInfo :: struct #packed {
    total_sectors: u32,
    vol_id_length: u8,
    // vol_id: [32]u8,
    // unknown0: u8,
    // unknown1: u32,
    // unknown2: u32,
    // ean_13_code: [13]u8,
    // ean_code_valid: u32,
    // cd_text_length: u8,
    // unknown3: u32,
    // unknown4: u32,
    // unknown5: [3]u8,
    // image_version: u32,
}

ParseState :: struct {
    header_cursor, data_cursor: int,
    data: []byte,
}

parse_dreamcast_cdi_data :: proc(data: []byte) -> DreamcastDisc {
    parse_state := ParseState{data = data}
    header_start_offset := cast(int)read_value(u32, len(data) - 4, data)
    parse_state.header_cursor = len(data) - header_start_offset
    if parse_state.header_cursor < 0 || parse_state.header_cursor >= len(data) {
        burn_session_error("This is either not a CDI file or CDI version is not supported")
    }
    number_of_sessions := data[parse_state.header_cursor]
    if number_of_sessions != 2 {
        burn_session_error("Not a valid Dreamcast CDI file")
    }
    parse_state.header_cursor += 1;

    audio_session := parse_session(&parse_state)
    // {
    // scoped_temp_memory()
    //     track := &audio_session.tracks[0]
    //     track_data := make([]byte, len(track.pregap_sectors) + len(track.sectors))
    //     n := copy(track_data, track.pregap_sectors)
    //     copy(track_data[n:], track.sectors)

    //     //os.write_entire_file("track 1.aiff", track_data)
    //     os.write_entire_file("track 1.aiff", track.sectors)
    // }


    //SEGA SEGAKATANA magic bytes
    // SEGA_MAGIC := [15]byte{0x53,0x45,0x47,0x41,0x20,0x53,0x45,0x47,0x41,0x4B,0x41,0x54,0x41,0x4E,0x41}
    EXPECTED_PREGAP_BYTES :: 150*2336
    // for i := parse_state.data_cursor; i < len(data); i += 1 {
    //     data_slice := data[i:i+len(SEGA_MAGIC)]
    //     assert(len(data_slice) == len(SEGA_MAGIC));
    //     if mem.compare(data_slice, SEGA_MAGIC[:]) == 0 {
    //         parse_state.data_cursor = i - EXPECTED_PREGAP_BYTES
    //         break
    //     }
    // }

    data_session := parse_session(&parse_state)
    if len(data_session.tracks) != 1 {
        burn_session_error("Unexpected number of tracks in data session. Should be 1 but was %v", 
            len(data_session.tracks))
    }

    data_track := &data_session.tracks[0]

    if data_track.number_of_pregap_bytes != EXPECTED_PREGAP_BYTES {
        burn_session_error("Unexpected number of pregap sectors in data session. Should be %v but was %v", 
            EXPECTED_PREGAP_BYTES, data_session.tracks[0].number_of_pregap_bytes)
    }
    if data_track.mode != .Mode2 {
        burn_session_error("Unexpected mode in data session. Should be %v but was %v", 
            TrackMode.Mode2, data_session.tracks[0].mode)
    }

    // {
    //     using parse_state
    //     session_header := read_value(CDISession, header_cursor, data)
    //     header_cursor += size_of(CDISession)
    //     track_part1 := read_value(CDITrackPart1, header_cursor, data)
    //     header_cursor += size_of(CDITrackPart1) + auto_cast track_part1.filename_length
    //     track_header := read_value(CDITrackHeader, header_cursor, data)
    //     header_cursor += size_of(track_header)
    //     disc_info := read_value(CDIDiscInfo, header_cursor, data)
    //     header_cursor += size_of(CDIDiscInfo)
    //     print("disc info: %v", disc_info)

    // }

    //Convert Mode 2 source image to XA Mode2 Form 1 data
    {
        mode2_block_size := sector_size_for_mode(data_track.mode)
        mode2f1_block_size := sector_size_for_mode(.XAMode2Form1)
        _, sector_count := sector_count_of_track(data_track^)
        src_data := data_track.sectors
        dst_data := make([]byte, sector_count * mode2f1_block_size)
        mem.zero_slice(dst_data)
        src_cursor, dst_cursor: int
        for src_cursor < len(src_data)  {
            d := dst_data[dst_cursor:dst_cursor+mode2f1_block_size]
            s := src_data[src_cursor+8:src_cursor+8+mode2f1_block_size]
            copy(d, s)
            dst_cursor += mode2f1_block_size
            src_cursor += mode2_block_size
        }
        data_track.sectors = dst_data
        data_track.mode = .XAMode2Form1
        data_track.number_of_pregap_bytes = 
            data_track.number_of_pregap_bytes/mode2_block_size * mode2f1_block_size
    }
    return DreamcastDisc{
        audio_session = audio_session,
        data_session = data_session
    }
}

parse_session :: proc(parse_state: ^ParseState) -> DiscSession {
    cdi_session := read_value(CDISession, parse_state.header_cursor, parse_state.data)
    if cdi_session.track_count == 0 {
        burn_session_error("This CDI version is not supported")
    }

    parse_state.header_cursor += size_of(CDISession)
    session := DiscSession{tracks = make([]Track, cdi_session.track_count)}
    for i in 0..<len(session.tracks) {
        session.tracks[i] = parse_track(parse_state, &session, i+1)
    }

    return session
}

parse_track :: proc(parse_state: ^ParseState, session: ^DiscSession, track_number: int) -> Track {
    TRACK_MARKER :: [?]u8{0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF}
    track_part1 := read_value(CDITrackPart1, parse_state.header_cursor, parse_state.data)
    if track_part1.marker0 != TRACK_MARKER || track_part1.marker1 != TRACK_MARKER {
        burn_session_error("Track marker not detected. This CDI version is not supported")
    }
    parse_state.header_cursor += size_of(CDITrackPart1)

    cdi_filename_length := cast(int)track_part1.filename_length
    cdi_filename := string(parse_state.data[
            parse_state.header_cursor:
            parse_state.header_cursor+cdi_filename_length
            ])

    parse_state.header_cursor += cdi_filename_length
    track_part2 := read_value(CDITrackPart2, parse_state.header_cursor, parse_state.data)
    assert(track_part2.max_cd_length == 360000)
    assert(track_part2.unknown3 == 0x80000000)
    assert(track_part2.unknown4 == 0x980000)

    parse_state.header_cursor += size_of(CDITrackPart2)

    if cast(int)track_part2.track_number == len(session.tracks) - 1 {
        parse_state.header_cursor += 8
    }
    
    track_mode: TrackMode
    switch track_part2.read_mode {
        case 0: track_mode = .Mode1
        case 1: track_mode = .Mode2
        case 2: track_mode = .Audio
        case: burn_session_error("Unsupported mode for track. This CDI version is not supported.")
    }
    sector_size := sector_size_for_mode(track_mode)

    // start_pregap_lba := cast(int)track_part2.start_lba
    // end_pregap_lba := cast(int)track_part2.pregap_sector_count + start_pregap_lba
    // start_lba := end_pregap_lba
    // end_lba := start_lba + cast(int)track_part2.sector_count
    //pregap_sector_byte_start := start_lba*sector_size
    pregap_sector_byte_start := parse_state.data_cursor
    pregap_sector_byte_end := pregap_sector_byte_start+cast(int)track_part2.pregap_sector_count*sector_size
    sector_byte_start := pregap_sector_byte_end
    sector_byte_end := pregap_sector_byte_end+cast(int)track_part2.sector_count*sector_size

    num_pregap := pregap_sector_byte_end-pregap_sector_byte_start

    track :=  Track{
        number_of_pregap_bytes = num_pregap,
        sectors = parse_state.data[sector_byte_start:sector_byte_end],
        session = session,
        mode = track_mode,
        number = track_number,
        start_lba = auto_cast track_part2.start_lba,
    }
    parse_state.data_cursor += num_pregap + len(track.sectors)

    return track
}

read_value :: proc($T: typeid, position: int, bytes: []byte) -> T {
    if position < 0 || position+size_of(T) > len(bytes) {
        burn_session_error("Position out of bounts of data")
    }
    return (cast(^T)raw_data(bytes[position:]))^
}
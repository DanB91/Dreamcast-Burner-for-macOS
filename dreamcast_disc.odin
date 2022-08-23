package main

DreamcastDisc :: struct {
    audio_session: DiscSession,
    data_session: DiscSession,
}
DiscSession :: struct {
    tracks: []Track,
}
Track :: struct {
    number_of_pregap_bytes: int,
    start_lba: int,
    sectors: []byte,
    session: ^DiscSession,
    mode: TrackMode,
    number: int,
}
TrackMode :: enum {
    Mode1,
    Mode2,
    Audio,
    XAMode2Form1,
}
MSF :: struct {
    minutes: int,
    seconds: int,
    frames: int,
}

sector_size_for_mode :: proc(mode: TrackMode) -> int {
    switch mode {
        case .Mode1, .XAMode2Form1: return 2048;
        case .Mode2: return 2336;
        case .Audio: return 2352;
    }
    panic("Bad TrackMode")
}
msf_of_track :: proc (track: Track) -> (pregap: MSF, actual: MSF) {
    msf :: proc(number_of_bytes: int, mode: TrackMode) -> MSF {
        sector_size := sector_size_for_mode(mode)
        number_of_sectors := number_of_bytes/sector_size
        
        frames := number_of_sectors % 75
        total_seconds := number_of_sectors / 75
        seconds := total_seconds % 60
        minutes := total_seconds / 60

        return {minutes, seconds, frames}
    }

    return msf(track.number_of_pregap_bytes, track.mode), 
        msf(len(track.sectors), track.mode) 
}
sector_of_track :: proc(sector: int, track: Track,) -> []byte {
    sector_size := sector_size_for_mode(track.mode)
    return track.sectors[sector*sector_size:sector*sector_size+sector_size]
}
total_sector_count_of_session :: proc(session: DiscSession) -> int {
    ret: int
    for track in session.tracks {
        pregap, actual := sector_count_of_track(track)
        ret += pregap + actual
    }
    return ret
}
sector_count_of_track :: proc(track: Track) -> (pregap_count: int, count: int) {
    sector_size := sector_size_for_mode(track.mode)
    pregap_count = track.number_of_pregap_bytes/sector_size
    count = len(track.sectors)/sector_size
    return
}
total_sector_count_of_track :: proc(track: Track) -> int {
    pregap, actual := sector_count_of_track(track)
    return actual + pregap
}

// session_length_in_sectors :: proc(session: DiscSession) int {
//     bool is_first_session = session->image->first_session == session;
//     const size_t LEAD_IN_SIZE = 4500;
//     const size_t LEAD_OUT_SIZE = (is_first_session) ? 6750 : 2250;

//     size_t total = LEAD_IN_SIZE + LEAD_OUT_SIZE;

//     cd_track_t* t = session->first_track;
//     while(t) {
//         size_t track_sectors = cd_track_data_size_in_sectors(t);

//         total += t->pregap_sectors;
//         total += track_sectors;
//         total += t->postgap_sectors;

//         t = t->next_track;
//     }

//     return total;
// }


// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Foundation
import AudioToolbox

public class MIDIFile {

    var sequence = MusicSequence()
    var tracks = [MusicTrack]()
    var chords = [Chord]()
    var beatsPerMiliSecond = Double()
    
    struct Chord {
        var timeStamp: MusicTimeStamp
        var notes = [MIDINoteMessage]()
        
        init(timeStamp: MusicTimeStamp) {
            self.timeStamp = timeStamp
        }
    }

    public init?(filePath: String) {
        let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, .CFURLPOSIXPathStyle, false)
        
        guard NewMusicSequence(&sequence) == noErr else {
            fatalError("Could not create Music Sequence.")
        }
        
        guard MusicSequenceFileLoad(sequence, url, MusicSequenceFileTypeID.MIDIType, MusicSequenceLoadFlags.SMF_PreserveTracks) == noErr else {
            return nil
        }
        
        setTempo()
        compileTracks()
        compileChords()
    }
    
    private func setTempo() {
        var tempoTrack = MusicTrack()
        guard MusicSequenceGetTempoTrack(sequence, &tempoTrack) == noErr else {
            beatsPerMiliSecond = 1.0 / 1000.0
            return
        }
        
        for event in getEventsForTrack(tempoTrack) {
            if event.type == kMusicEventType_ExtendedTempo {
                let tempoPointer = UnsafePointer<ExtendedTempoEvent>(event.data)
                beatsPerMiliSecond = tempoPointer.memory.bpm / 60000
            }
        }
    }
    
    private func compileTracks() {
        var trackCount = UInt32()
        guard MusicSequenceGetTrackCount(sequence, &trackCount) == noErr else {
            fatalError("Could not get track count from midi file.")
        }
        
        for trackIndex in 0..<trackCount {
            var track = MusicTrack()
            guard MusicSequenceGetIndTrack(sequence, trackIndex, &track) == noErr else {
                fatalError("Could not retrieve track \(trackIndex) from midi file.")
            }
            tracks.append(track)
        }
    }
    
    private func compileChords() {
        for track in tracks {
            let events = getEventsForTrack(track)
            let notes = extractNotesFromEvents(events)
            
            for (timeStamp, noteMessage) in notes {
                if let chordIndex = chords.indexOf({ return $0.timeStamp == timeStamp }) {
                    chords[chordIndex].notes.append(noteMessage)
                } else {
                    var chord = Chord(timeStamp: timeStamp)
                    chord.notes.append(noteMessage)
                    chords.append(chord)
                }
            }
        }
    }
    
    private func getEventsForTrack(track: MusicTrack) -> [MIDIEvent] {
        var events = [MIDIEvent]()
        for e in track {
            events.append(e)
        }
        return events
    }
    
    private func extractNotesFromEvents(events: [MIDIEvent]) -> [(timeStamp: MusicTimeStamp, noteMessage: MIDINoteMessage)] {
        var notes = [(timeStamp: MusicTimeStamp, noteMessage: MIDINoteMessage)]()
        for event in events {
            if event.type == kMusicEventType_MIDINoteMessage {
                let noteMessagePointer = UnsafeMutablePointer<MIDINoteMessage>(event.data)
                noteMessagePointer.memory.duration /= Float32(beatsPerMiliSecond)
                
                let timeStampInMiliSeconds = event.timeStamp / beatsPerMiliSecond
                notes.append((timeStampInMiliSeconds, noteMessagePointer.memory))
            }
        }
        return notes
    }

}

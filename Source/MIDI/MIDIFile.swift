// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Foundation
import AudioToolbox

open class MIDIFile {
    open fileprivate(set) var sequence: MusicSequence? = nil
    open fileprivate(set) var tracks = [MusicTrack]()

    open static func create(_ outFilePath: String, sequence: MusicSequence) -> MIDIFile? {
        let url = URL(fileURLWithPath: outFilePath)
        guard MusicSequenceFileCreate(sequence, url as CFURL, .midiType, .eraseFile, 0) == noErr else {
            return nil
        }

        return MIDIFile(filePath: outFilePath)
    }

    public init?(filePath: String) {
        guard NewMusicSequence(&sequence) == noErr else {
            print("Could not create Music Sequence.")
            return nil
        }

        let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath as CFString!, .cfurlposixPathStyle, false)
        guard MusicSequenceFileLoad(sequence!, url!, .midiType, MusicSequenceLoadFlags()) == noErr else {
            return nil
        }

        compileTracks()
    }

    deinit {
        DisposeMusicSequence(sequence!)
    }

    fileprivate func compileTracks() {
        var trackCount = UInt32()
        guard MusicSequenceGetTrackCount(sequence!, &trackCount) == noErr else {
            fatalError("Could not get track count from midi file.")
        }
        
        for trackIndex in 0..<trackCount {
            var track: MusicTrack? = nil
            guard MusicSequenceGetIndTrack(sequence!, trackIndex, &track) == noErr else {
                fatalError("Could not retrieve track \(trackIndex) from midi file.")
            }
            tracks.append(track!)
        }
    }

    /// Convert from a beats time stamp value to a time in seconds
    open func secondsForBeats(_ beats: MusicTimeStamp) -> Double {
        var seconds = Float64()
        MusicSequenceGetSecondsForBeats(sequence!, beats, &seconds)
        return Double(seconds)
    }

    /// Convert from a time in seconds to a beats time stamp
    open func beatsForSeconds(_ seconds: Double) -> MusicTimeStamp {
        var beats = MusicTimeStamp()
        MusicSequenceGetBeatsForSeconds(sequence!, seconds, &beats)
        return beats
    }

    /// The collection of tempo events
    open var tempoEvents: [MIDITempoEvent] {
        var track: MusicTrack? = nil
        guard MusicSequenceGetTempoTrack(sequence!, &track) == noErr else {
            return []
        }

        var tempoEvents = [MIDITempoEvent]()
        for event in track! {
            guard
                event.type == kMusicEventType_ExtendedTempo,
                let message = event.data?.assumingMemoryBound(to: ExtendedTempoEvent.self)
            else {
                continue
            }

            let event = MIDITempoEvent(
                timeStamp: event.timeStamp,
                bpm: message.pointee.bpm
            )
            tempoEvents.append(event)
        }
        return tempoEvents
    }

    /// The collection of all note events in the file sorted by timestamp
    open var noteEvents: [MIDINoteEvent] {
        var events = [MIDINoteEvent]()
        for track in tracks {
            events.append(contentsOf: noteEventsInTrack(track))
        }
        events.sort{ $0.timeStamp < $1.timeStamp }
        return events
    }

    /// The collection of note events in a particular track
    open func noteEventsInTrack(_ track: MusicTrack) -> [MIDINoteEvent] {
        var noteEvents = [MIDINoteEvent]()
        for event in track {
            guard
                event.type == kMusicEventType_MIDINoteMessage,
                let message = event.data?.assumingMemoryBound(to: MIDINoteMessage.self)
            else {
                continue
            }

            let event = MIDINoteEvent(
                timeStamp: event.timeStamp,
                duration: message.pointee.duration,
                channel: message.pointee.channel,
                note: message.pointee.note,
                velocity: message.pointee.velocity
            )
            noteEvents.append(event)
        }
        return noteEvents
    }
}

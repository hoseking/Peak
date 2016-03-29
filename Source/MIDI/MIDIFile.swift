// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Foundation
import AudioToolbox

public class MIDIFile {
    public private(set) var sequence: MusicSequence = nil
    public private(set) var tracks = [MusicTrack]()

    public static func create(outFilePath: String, sequence: MusicSequence) -> MIDIFile? {
        let url = NSURL.fileURLWithPath(outFilePath)
        guard MusicSequenceFileCreate(sequence, url, MusicSequenceFileTypeID.MIDIType, MusicSequenceFileFlags.EraseFile, 0) == noErr else {
            return nil
        }

        return MIDIFile(filePath: outFilePath)
    }

    public init?(filePath: String) {
        guard NewMusicSequence(&sequence) == noErr else {
            print("Could not create Music Sequence.")
            return nil
        }

        let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, .CFURLPOSIXPathStyle, false)
        guard MusicSequenceFileLoad(sequence, url, MusicSequenceFileTypeID.MIDIType, MusicSequenceLoadFlags.SMF_PreserveTracks) == noErr else {
            return nil
        }

        compileTracks()
    }

    deinit {
        DisposeMusicSequence(sequence)
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

    /// Convert from a beats time stamp value to a time in seconds
    public func secondsForBeats(beats: MusicTimeStamp) -> Double {
        var seconds = Float64()
        MusicSequenceGetSecondsForBeats(sequence, beats, &seconds)
        return Double(seconds)
    }

    /// Convert from a time in seconds to a beats time stamp
    public func beatsForSeconds(seconds: Double) -> MusicTimeStamp {
        var beats = MusicTimeStamp()
        MusicSequenceGetBeatsForSeconds(sequence, seconds, &beats)
        return beats
    }

    /// The collection of tempo events
    public var tempoEvents: [MIDITempoEvent] {
        var track = MusicTrack()
        guard MusicSequenceGetTempoTrack(sequence, &track) == noErr else {
            return []
        }

        var tempoEvents = [MIDITempoEvent]()
        for event in track {
            guard event.type == kMusicEventType_ExtendedTempo else {
                continue
            }

            let message = UnsafeMutablePointer<ExtendedTempoEvent>(event.data)
            let event = MIDITempoEvent(
                timeStamp: event.timeStamp,
                bpm: message.memory.bpm
            )
            tempoEvents.append(event)
        }
        return tempoEvents
    }

    /// The collection of all note events in the file sorted by timestamp
    public var noteEvents: [MIDINoteEvent] {
        var events = [MIDINoteEvent]()
        for track in tracks {
            events.appendContentsOf(noteEventsInTrack(track))
        }
        events.sortInPlace{ $0.timeStamp < $1.timeStamp }
        return events
    }

    /// The collection of note events in a particular track
    public func noteEventsInTrack(track: MusicTrack) -> [MIDINoteEvent] {
        var noteEvents = [MIDINoteEvent]()
        for event in track {
            guard event.type == kMusicEventType_MIDINoteMessage else {
                continue
            }

            let message = UnsafeMutablePointer<MIDINoteMessage>(event.data)
            let event = MIDINoteEvent(
                timeStamp: event.timeStamp,
                duration: message.memory.duration,
                channel: message.memory.channel,
                note: message.memory.note,
                velocity: message.memory.velocity
            )
            noteEvents.append(event)
        }
        return noteEvents
    }
}

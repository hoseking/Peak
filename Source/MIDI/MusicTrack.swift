// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Foundation
import AudioToolbox

extension MusicTrack : SequenceType {
    public typealias Generator = MusicTrackGenerator
    
    public func generate() -> MusicTrackGenerator {
        return MusicTrackGenerator(track: self)
    }
}

public class MusicTrackGenerator : GeneratorType {
    public typealias Element = MIDIEvent
    
    var iterator: MusicEventIterator = nil
    
    init(track: MusicTrack) {
        guard NewMusicEventIterator(track, &iterator) == noErr else {
            fatalError("Failed to create an music event iterator")
        }
    }

    deinit {
        DisposeMusicEventIterator(iterator)
    }
    
    var hasEvent: Bool {
        var hasEvent = DarwinBoolean(false)
        guard MusicEventIteratorHasCurrentEvent(iterator, &hasEvent) == noErr else {
            return false
        }
        return Bool(hasEvent)
    }
    
    public func next() -> MIDIEvent? {
        guard hasEvent else {
            return nil
        }
        
        var event = MIDIEvent()
        guard MusicEventIteratorGetEventInfo(iterator, &event.timeStamp, &event.type, &event.data, &event.dataSize) == noErr else {
            return nil
        }
        
        MusicEventIteratorNextEvent(iterator)
        return event
    }
}

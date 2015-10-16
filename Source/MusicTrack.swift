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
    
    var it = MusicEventIterator()
    
    init(track: MusicTrack) {
        guard NewMusicEventIterator(track, &it) == noErr else {
            fatalError("Failed to create an music event iterator")
        }
    }
    
    var hasEvent: Bool {
        var hasEvent = DarwinBoolean(false)
        guard MusicEventIteratorHasCurrentEvent(it, &hasEvent) == noErr else {
            return false
        }
        return Bool(hasEvent)
    }
    
    public func next() -> MIDIEvent? {
        guard hasEvent else {
            return nil
        }
        
        var event = MIDIEvent()
        guard MusicEventIteratorGetEventInfo(it, &event.timeStamp, &event.type, &event.data, &event.dataSize) == noErr else {
            return nil
        }
        
        MusicEventIteratorNextEvent(it)
        return event
    }

}

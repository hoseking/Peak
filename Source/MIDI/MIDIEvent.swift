// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Foundation
import AudioToolbox

/// A generic MIDI event
public struct MIDIEvent {
    /// Timestamp of the event in beats
    public var timeStamp = MusicTimeStamp()

    /// MIDI event type
    public var type = MusicEventType()

    /// Pointer to event data
    public var data: UnsafePointer<Void> = nil
    
    /// Size of event data
    public var dataSize = UInt32()
}

/// A note MIDI event
public struct MIDINoteEvent {
    /// Timestamp of the event in beats
    public var timeStamp: MusicTimeStamp

    /// Duration of the event in beats
    public var duration: Float32

    /// MIDI channel
    public var channel: UInt8

    /// MIDI note number
    public var note: UInt8

    /// Key-press velocity
    public var velocity: UInt8
}

/// A tempo MIDI event
public struct MIDITempoEvent {
    /// Timestamp of the event in beats
    public var timeStamp: MusicTimeStamp

    /// Beats per minute
    public var bpm: Float64
}

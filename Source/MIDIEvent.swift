// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Foundation
import AudioToolbox

public struct MIDIEvent {
    var timeStamp = MusicTimeStamp()
    var type = MusicEventType()
    var data = UnsafePointer<Void>()
    var dataSize = UInt32()
}

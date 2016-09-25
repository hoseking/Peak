// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

open class IONode: Node {
    open var audioUnit: AudioUnit? = nil
    open var audioNode: AUNode = 0
    open var cd: AudioComponentDescription

    public init() {
    #if os(iOS)
        let audioUnitSubType = kAudioUnitSubType_RemoteIO
    #else
        let audioUnitSubType = kAudioUnitSubType_VoiceProcessingIO
    #endif
        cd = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_Output, subType: audioUnitSubType)
    }
}

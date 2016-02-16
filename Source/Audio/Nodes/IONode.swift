// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

public class IONode: Node {
    public var audioUnit: AudioUnit = nil
    public var audioNode: AUNode = 0
    public var cd: AudioComponentDescription

    public init() {
    #if os(iOS)
        let audioUnitSubType = kAudioUnitSubType_RemoteIO
    #else
        let audioUnitSubType = kAudioUnitSubType_VoiceProcessingIO
    #endif

        cd = AudioComponentDescription(
            componentType:         kAudioUnitType_Output,
            componentSubType:      audioUnitSubType,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags:        0,
            componentFlagsMask:    0)
    }
}

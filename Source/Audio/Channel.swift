// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

open class Channel {
    public enum Param: AudioUnitParameterID {
        case level
        case enabled

        func value() -> AudioUnitParameterID {
            switch self {
            case .level: return kMultiChannelMixerParam_Volume
            case .enabled: return kMultiChannelMixerParam_Enable
            }
        }
    }

    var nodes = [Node]()
    let mixer = MixerNode()

    open var audioUnit: AudioUnit? {
        return nodes.first?.audioUnit
    }

    public init(nodes: [Node]) {
        nodes.forEach { self.nodes.append($0) }
        self.nodes.append(mixer)
    }

    open func setParam(_ param: Param, value: AudioUnitParameterValue) {
        checkStatus(AudioUnitSetParameter(mixer.audioUnit!, param.value(), kAudioUnitScope_Input, 0, value, 0))
    }

    open func getParam(_ param: Param) -> AudioUnitParameterValue {
        var value: AudioUnitParameterValue = 0
        checkStatus(AudioUnitGetParameter(mixer.audioUnit!, param.value(), kAudioUnitScope_Input, 0, &value))
        return value
    }
}

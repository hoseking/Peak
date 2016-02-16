// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

public class Channel {
    public enum Param: AudioUnitParameterID {
        case Level
        case Enabled

        func value() -> AudioUnitParameterID {
            switch self {
            case .Level: return kMultiChannelMixerParam_Volume
            case .Enabled: return kMultiChannelMixerParam_Enable
            }
        }
    }

    var nodes = [Node]()
    let mixer = MixerNode()

    public var audioUnit: AudioUnit? {
        return nodes.first?.audioUnit
    }

    public init(nodes: [Node]) {
        nodes.forEach { self.nodes.append($0) }
        self.nodes.append(mixer)
    }

    public func setParam(param: Param, value: AudioUnitParameterValue) {
        checkStatus(AudioUnitSetParameter(mixer.audioUnit, param.value(), kAudioUnitScope_Input, 0, value, 0))
    }

    public func getParam(param: Param) -> AudioUnitParameterValue {
        var value: AudioUnitParameterValue = 0
        checkStatus(AudioUnitGetParameter(mixer.audioUnit, param.value(), kAudioUnitScope_Input, 0, &value))
        return value
    }
}

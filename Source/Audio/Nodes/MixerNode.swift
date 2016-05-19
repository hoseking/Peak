// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

public class MixerNode: Node {
    public var audioUnit: AudioUnit = nil {
        didSet {
            setup()
        }
    }
    public var audioNode: AUNode = 0
    public var cd: AudioComponentDescription

    var maxInputs = 0
    var inputs = [Node?]()

    public init() {
        cd = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_Mixer, subType: kAudioUnitSubType_MultiChannelMixer)
    }

    public func addInput(node: Node) -> UInt32 {
        let bus = nextInputBus()
        precondition(inputs[bus] == nil)
        inputs[bus] = node

        return UInt32(bus)
    }

    public func removeInput(node: Node) {
        guard let index = inputs.indexOf({ $0?.audioNode == node.audioNode }) else { return }
        inputs[index] = nil
    }

    func nextInputBus() -> Int {
        for i in 0..<maxInputs {
            if inputs[i] == nil {
                return i
            }
        }
        fatalError("Could not get next input bus")
    }

    func setup() {
        guard audioUnit != nil else { return }

        var numInputs: UInt32 = 0
        var numInputsSize = UInt32(sizeof(numInputs.dynamicType))
        checkStatus(AudioUnitGetProperty(audioUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numInputs, &numInputsSize))
        maxInputs = Int(numInputs)
        for _ in 0..<numInputs {
            inputs.append(nil)
        }
    }
}

// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

public class SamplerNode: Node {
    public var audioUnit: AudioUnit = nil {
        didSet {
            guard audioUnit != nil else { return }
            setup()
        }
    }
    public var audioNode: AUNode = 0
    public var cd: AudioComponentDescription
    public var target: (bus: UInt32, node: Node)?

    var instrumentPath: String?
    var instrumentType: Int?

    public init() {
        cd = AudioComponentDescription(
            componentType:         kAudioUnitType_MusicDevice,
            componentSubType:      kAudioUnitSubType_Sampler,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags:        0,
            componentFlagsMask:    0)
    }

    public convenience init(instrumentPath: String, instrumentType: Int) {
        self.init()
        self.instrumentPath = instrumentPath
        self.instrumentType = instrumentType
    }

    func setup() {
        guard let instrumentPath = instrumentPath, let instrumentType = instrumentType else { return }

        let instrumentURL = NSURL.fileURLWithPath(instrumentPath)
        var instrumentData = AUSamplerInstrumentData(
            fileURL:        Unmanaged.passUnretained(instrumentURL),
            instrumentType: UInt8(instrumentType),
            bankMSB:        UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB:        UInt8(kAUSampler_DefaultBankLSB),
            presetID:       0)

        let status = AudioUnitSetProperty(
            audioUnit,
            kAUSamplerProperty_LoadInstrument,
            kAudioUnitScope_Global,
            0,
            &instrumentData,
            UInt32(sizeof(instrumentData.dynamicType)))

        checkStatus(status)
    }
}

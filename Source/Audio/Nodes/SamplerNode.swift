// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

open class SamplerNode: Node {
    open var audioUnit: AudioUnit? = nil {
        didSet {
            setup()
        }
    }
    open var audioNode: AUNode = 0
    open var cd: AudioComponentDescription

    var instrumentPath: String?
    var instrumentType: Int?

    public init() {
        cd = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_MusicDevice, subType: kAudioUnitSubType_Sampler)
    }

    public convenience init(instrumentPath: String, instrumentType: Int) {
        self.init()
        self.instrumentPath = instrumentPath
        self.instrumentType = instrumentType
    }

    func setup() {
        guard audioUnit != nil else { return }
        guard let instrumentPath = instrumentPath, let instrumentType = instrumentType else { return }

        let instrumentURL = URL(fileURLWithPath: instrumentPath)
        var instrumentData = AUSamplerInstrumentData(
            fileURL:        Unmanaged.passUnretained(instrumentURL as CFURL),
            instrumentType: UInt8(instrumentType),
            bankMSB:        UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB:        UInt8(kAUSampler_DefaultBankLSB),
            presetID:       0)
        checkStatus(AudioUnitSetProperty(audioUnit!, kAUSamplerProperty_LoadInstrument, kAudioUnitScope_Global, 0, &instrumentData, UInt32(MemoryLayout<AUSamplerInstrumentData>.size)))
    }
}

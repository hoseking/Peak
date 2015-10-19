// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox
import Foundation

public class Microphone {

    private let channels = 1
    private var inputUnit: AudioUnit = nil
    private var sampleRate = 44100
    private var buffer: Array<Double>!
    private var bufferSize = 512
    private var context: Microphone!

    private var running = false
    private var stopping = false

    public var dataAvailable: (Int -> ())?

    private let inputCallback: AURenderCallback = {(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
        let microphone = UnsafePointer<Microphone>(inRefCon).memory
        if !microphone.stopping {
            microphone.preload(Int(inNumberFrames), timeStamp: inTimeStamp)
        }
        return noErr
    }

    public init(sampleRate: Int, bufferSize: Int) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.buffer = Array(count: bufferSize, repeatedValue: 0)
        self.context = self
        create()
    }

    deinit {
        stopping = true
        stop()
        checkStatus(AudioComponentInstanceDispose(inputUnit), "AudioComponentInstanceDispose")
    }

    public func start() {
        if running { return }
        checkStatus(AudioOutputUnitStart(inputUnit), "AudioOutputUnitStart")
        running = true
    }

    public func stop() {
        if !running { return }
        checkStatus(AudioOutputUnitStop(inputUnit), "AudioOutputUnitStop")
        running = false
    }

    public func availableSize() -> Int {
        return buffer.count
    }

    public func render(inout data: [Double]) -> Int {
        let size = min(buffer.count, data.count)
        data.replaceRange(0..<size, with: buffer[0..<size])
        buffer.removeRange(0..<size)
        return size
    }

    private func create() {
        var description = AudioComponentDescription()
        description.componentType          = kAudioUnitType_Output
    #if os(iOS)
        description.componentSubType       = kAudioUnitSubType_RemoteIO
    #else
        description.componentSubType       = kAudioUnitSubType_VoiceProcessingIO
    #endif
        description.componentManufacturer  = kAudioUnitManufacturer_Apple
        description.componentFlags         = 0
        description.componentFlagsMask     = 0

        // Try and find the component
        let component = AudioComponentFindNext(nil, &description)
        checkStatus(AudioComponentInstanceNew(component, &inputUnit), "AudioComponentInstanceNew")

        var disableFlag: UInt32 = 0
        var enableFlag: UInt32 = 1
        let inputBus: AudioUnitScope = 1
        let outputBus: AudioUnitScope = 0
        
        // Enable I/O on microphone input unit
        checkStatus(AudioUnitSetProperty(inputUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, inputBus, &enableFlag, UInt32(sizeof(enableFlag.dynamicType))), "AudioUnitSetProperty io input")

        // Could set the output if we wanted to play out the mic's buffer
        checkStatus(AudioUnitSetProperty(inputUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, outputBus, &disableFlag, UInt32(sizeof(disableFlag.dynamicType))), "AudioUnitSetProperty io output")

        // Set the stream format
        var streamFormat = AudioStreamBasicDescription()
        streamFormat.mBitsPerChannel   = UInt32(8 * sizeof(Double))
        streamFormat.mBytesPerFrame    = UInt32(sizeof(Double))
        streamFormat.mBytesPerPacket   = UInt32(sizeof(Double))
        streamFormat.mChannelsPerFrame = UInt32(channels)
        streamFormat.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved
        streamFormat.mFormatID         = kAudioFormatLinearPCM
        streamFormat.mFramesPerPacket  = 1
        streamFormat.mSampleRate       = Double(sampleRate)

        // Set the stream format for output on the microphone's input scope
        checkStatus(AudioUnitSetProperty(inputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, outputBus, &streamFormat, UInt32(sizeof(streamFormat.dynamicType))), "AudioUnitSetProperty stream input")

        // Setup input callback
        var callbackStruct = AURenderCallbackStruct(inputProc: inputCallback, inputProcRefCon: &context)
        checkStatus(AudioUnitSetProperty(inputUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, inputBus, &callbackStruct, UInt32(sizeof(callbackStruct.dynamicType))), "AudioUnitSetProperty callback")

        // Disable buffer allocation for the recorder
        checkStatus(AudioUnitSetProperty(inputUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, inputBus, &disableFlag, UInt32(sizeof(disableFlag.dynamicType))), "AudioUnitSetProperty buffer output")

        // Initialize the audio unit
        checkStatus(AudioUnitInitialize(inputUnit), "AudioUnitInitialize")

        // Set buffer size
        var maxFrames = UInt32(bufferSize)
        checkStatus(AudioUnitSetProperty(inputUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, outputBus, &maxFrames, UInt32(sizeof(maxFrames.dynamicType))), "AudioUnitSetProperty buffer size")
    }

    private func preload(frameCount: Int, timeStamp: UnsafePointer<AudioTimeStamp>) {
        assert(frameCount <= bufferSize)

        // Discard old data if there is no room
        if (buffer.count + frameCount > bufferSize) {
            buffer.removeRange(0..<(buffer.count + frameCount - bufferSize))
        }

        // Get new data
        var bufferList = AudioBufferList()
        bufferList.mNumberBuffers = 1
        bufferList.mBuffers.mNumberChannels = 1
        bufferList.mBuffers.mDataByteSize = UInt32(frameCount * sizeof(Double))
        bufferList.mBuffers.mData = UnsafeMutablePointer<Void>(UnsafeMutablePointer<Double>(buffer) + buffer.count)

        var actionFlags = AudioUnitRenderActionFlags(rawValue: 0)
        checkStatus(AudioUnitRender(inputUnit, &actionFlags, timeStamp, 1, UInt32(frameCount), &bufferList), "AudioUnitRender")

        // Notify new data
        dataAvailable?(buffer.count)
    }

    private func checkStatus(status: OSStatus, _ message: String) {
        if status == noErr { return }
        fatalError(message)
    }

}

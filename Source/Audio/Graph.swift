// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

func checkStatus(status: OSStatus) {
    guard status == noErr else { fatalError("Status: \(status)") }
}

public class Graph {
    enum Bus: AudioUnitScope {
        case Input = 1  // 1 = I = Input
        case Output = 0 // 0 = O = Output
    }

    var graph: AUGraph = nil
    var ioNode = IONode()
    var mixerNode = MixerNode()
    var channels = [Channel]()

    private let sampleSize = UInt32(sizeof(Buffer.Element.self))
    private let inputCallback: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
        let controller = UnsafePointer<Graph>(inRefCon).memory
        if !controller.deiniting {
            controller.preloadInput(ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames)
        }
        return noErr
    }

    private var buffer: Buffer!
    private var context: Graph!
    private var deiniting = false

    public var running: Bool {
        var isRunning = DarwinBoolean(false)
        checkStatus(AUGraphIsRunning(graph, &isRunning))
        return isRunning.boolValue
    }

    public var initialized: Bool {
        var isInitialized = DarwinBoolean(false)
        checkStatus(AUGraphIsInitialized(graph, &isInitialized))
        return isInitialized.boolValue
    }

    public var open: Bool {
        var isOpen = DarwinBoolean(false)
        checkStatus(AUGraphIsOpen(graph, &isOpen))
        return isOpen.boolValue
    }

    public var sampleRate = 44100 {
        didSet {
            performUpdate(setup)
        }
    }

    public var inputEnabled = true {
        didSet {
            performUpdate(setup)
        }
    }

    public var inputAvailable: (Int -> ())?

    public init() {
        buffer = Buffer(capacity: 8192)
        context = self

        checkStatus(NewAUGraph(&graph))
        checkStatus(AUGraphOpen(graph))

        checkStatus(AUGraphAddNode(graph, &mixerNode.cd, &mixerNode.audioNode))
        checkStatus(AUGraphNodeInfo(graph, mixerNode.audioNode, nil, &mixerNode.audioUnit))

        performUpdate(setup)
        
        checkStatus(AUGraphInitialize(graph))
    }

    deinit {
        deiniting = true
        stop()
        for i in 0..<channels.count {
            guard let channel = channels.at(i) else { fatalError("Could not deinit channel") }
            remove(channel)
        }
        checkStatus(DisposeAUGraph(graph))
    }

    func setup() {
        checkStatus(AUGraphStop(graph))

        // Remove and add io node
        if ioNode.audioNode != 0 {
            checkStatus(AUGraphRemoveNode(graph, ioNode.audioNode))
        }
        checkStatus(AUGraphAddNode(graph, &ioNode.cd, &ioNode.audioNode))
        checkStatus(AUGraphNodeInfo(graph, ioNode.audioNode, nil, &ioNode.audioUnit))

        var enableFlag: UInt32 = 1
        var disableFlag: UInt32 = 0

        // Enable output on io node
        checkStatus(AudioUnitSetProperty(ioNode.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, Bus.Output.rawValue, &enableFlag, UInt32(sizeof(enableFlag.dynamicType))))

        // Set the stream format
        var streamFormat = AudioStreamBasicDescription()
        streamFormat.mBitsPerChannel   = 8 * sampleSize
        streamFormat.mBytesPerFrame    = sampleSize
        streamFormat.mBytesPerPacket   = sampleSize
        streamFormat.mChannelsPerFrame = 1
        streamFormat.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved
        streamFormat.mFormatID         = kAudioFormatLinearPCM
        streamFormat.mFramesPerPacket  = 1
        streamFormat.mSampleRate       = Float64(sampleRate)

        // Set the stream format for input of the audio output bus
        checkStatus(AudioUnitSetProperty(ioNode.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, Bus.Output.rawValue, &streamFormat, UInt32(sizeof(streamFormat.dynamicType))))

        // Set buffer size
        var maxFrames = UInt32(buffer.capacity)
        checkStatus(AudioUnitSetProperty(ioNode.audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, UInt32(sizeof(maxFrames.dynamicType))))

        if inputEnabled {
            // Enable input on io node
            checkStatus(AudioUnitSetProperty(ioNode.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, Bus.Input.rawValue, &enableFlag, UInt32(sizeof(enableFlag.dynamicType))))

            // Set the stream format for output of the audio input bus
            checkStatus(AudioUnitSetProperty(ioNode.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, Bus.Input.rawValue, &streamFormat, UInt32(sizeof(streamFormat.dynamicType))))

            // Disable buffer allocation for the recorder
            checkStatus(AudioUnitSetProperty(ioNode.audioUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, Bus.Input.rawValue, &disableFlag, UInt32(sizeof(disableFlag.dynamicType))))

            // Setup input callback
            var callbackStruct = AURenderCallbackStruct(inputProc: inputCallback, inputProcRefCon: &context)
            checkStatus(AudioUnitSetProperty(ioNode.audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, UInt32(sizeof(callbackStruct.dynamicType))))
        }

        // Connect the io node
        checkStatus(AUGraphConnectNodeInput(graph, mixerNode.audioNode, 0, ioNode.audioNode, 0))
    }

    public func start() {
        guard !running else { return }
        checkStatus(AUGraphStart(graph))
    }

    public func stop() {
        guard running else { return }
        checkStatus(AUGraphStop(graph))
    }

    func performUpdate(@noescape block: () -> ()) {
        let wasRunning = running
        stop()
        block()
        if wasRunning {
            start()
        }
    }
}


// MARK: Connections

extension Graph {
    public func add(channel: Channel) {
        guard !channels.contains({ $0.mixer.audioNode == channel.mixer.audioNode }) else { return }
        performUpdate { addFromBlock(channel) }
    }

    func addFromBlock(channel: Channel) {
        // Add nodes
        for i in 0..<channel.nodes.count {
            guard var node = channel.nodes.at(i) else { fatalError("Could not create channel node") }
            checkStatus(AUGraphAddNode(graph, &node.cd, &node.audioNode))
            checkStatus(AUGraphNodeInfo(graph, node.audioNode, nil, &node.audioUnit))
        }

        // Connect nodes
        for i in 0..<channel.nodes.count {
            guard let sourceNode = channel.nodes.at(i) else { fatalError("Could not create connect node") }

            if var targetNode = channel.nodes.at(i+1) {
                checkStatus(AUGraphConnectNodeInput(graph, sourceNode.audioNode, 0, targetNode.audioNode, 0))
            } else {
                let bus: UInt32 = mixerNode.addInput(sourceNode)
                checkStatus(AUGraphConnectNodeInput(graph, sourceNode.audioNode, 0, mixerNode.audioNode, bus))
            }
        }

        channels.append(channel)
    }

    public func remove(channel: Channel) {
        guard channels.contains({ $0.mixer.audioNode == channel.mixer.audioNode }) else { return }
        performUpdate { removeFromBlock(channel) }
    }

    func removeFromBlock(channel: Channel) {
        // Remove nodes
        for i in 0..<channel.nodes.count {
            guard var node = channel.nodes.at(i) else { fatalError("Could not remove channel node") }
            mixerNode.removeInput(node)
            checkStatus(AUGraphRemoveNode(graph, node.audioNode))
            node.audioNode = 0
            node.audioUnit = nil
        }

        guard let index = channels.indexOf({ $0.mixer.audioNode == channel.mixer.audioNode }) else { fatalError("Could not remove channel") }
        channels.removeAtIndex(index)
    }
}


// MARK: Input

extension Graph {
    private func preloadInput(ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, _ inTimeStamp: UnsafePointer<AudioTimeStamp>, _ inOutputBusNumber: UInt32, _ inNumberFrames: UInt32) {
        let numSamples = Int(inNumberFrames)
        assert(numSamples <= buffer.capacity)

        // Discard old data if there is no room
        if (buffer.count + numSamples > buffer.capacity) {
            buffer.removeRange(0..<(buffer.count + numSamples - buffer.capacity))
        }

        // Get new data
        var bufferList = AudioBufferList()
        bufferList.mNumberBuffers = 1
        bufferList.mBuffers.mNumberChannels = 1
        bufferList.mBuffers.mDataByteSize = inNumberFrames * sampleSize
        bufferList.mBuffers.mData = UnsafeMutablePointer<Void>(buffer.pointer + buffer.count)

        checkStatus(AudioUnitRender(ioNode.audioUnit, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, &bufferList))

        let numSamplesRendered = Int(bufferList.mBuffers.mDataByteSize / sampleSize)
        buffer.count += numSamplesRendered;

        // Notify new data
        inputAvailable?(buffer.count)
    }

    public func renderInput(data: UnsafeMutablePointer<Double>, count: Int) -> Int {
        let renderCount = min(count, buffer.count)
        guard renderCount > 0 else { return 0 }
        data.assignFrom(buffer.pointer, count: renderCount)
        buffer.removeRange(0..<renderCount)
        return renderCount
    }
}


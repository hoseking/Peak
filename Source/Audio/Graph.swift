// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

func checkStatus(_ status: OSStatus) {
    guard status == noErr else { fatalError("Status: \(status)") }
}

open class Graph {
    enum Bus: AudioUnitScope {
        case input = 1  // 1 = I = Input
        case output = 0 // 0 = O = Output
    }

    var graph: AUGraph? = nil
    var ioNode = IONode()
    var mixerNode = MixerNode()
    var channels = [Channel]()

    fileprivate let queue = DispatchQueue(label: "Peak.Graph", attributes: [])
    fileprivate let sampleSize = UInt32(MemoryLayout<Buffer.Element>.size)
    fileprivate let inputCallback: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
        let controller = unsafeBitCast(inRefCon, to: Graph.self)
        if !controller.deiniting {
            controller.queue.sync {
                controller.preloadInput(ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames)
            }
        }
        return noErr
    }

    fileprivate var buffer: Buffer!
    fileprivate var deiniting = false

    open var running: Bool {
        var isRunning = DarwinBoolean(false)
        checkStatus(AUGraphIsRunning(graph!, &isRunning))
        return isRunning.boolValue
    }

    open var initialized: Bool {
        var isInitialized = DarwinBoolean(false)
        checkStatus(AUGraphIsInitialized(graph!, &isInitialized))
        return isInitialized.boolValue
    }

    open var open: Bool {
        var isOpen = DarwinBoolean(false)
        checkStatus(AUGraphIsOpen(graph!, &isOpen))
        return isOpen.boolValue
    }

    open var sampleRate = 44100 {
        didSet {
            performUpdate(setup)
        }
    }

    open var inputEnabled: Bool {
        didSet {
            performUpdate(setup)
        }
    }

    open var inputAvailable: ((Int) -> ())?

    public init(inputEnabled: Bool) {
        self.inputEnabled = inputEnabled
        self.buffer = Buffer(capacity: 8192)

        checkStatus(NewAUGraph(&graph))
        checkStatus(AUGraphOpen(graph!))

        checkStatus(AUGraphAddNode(graph!, &mixerNode.cd, &mixerNode.audioNode))
        checkStatus(AUGraphNodeInfo(graph!, mixerNode.audioNode, nil, &mixerNode.audioUnit))

        performUpdate(setup)
        
        checkStatus(AUGraphInitialize(graph!))
    }

    deinit {
        deiniting = true
        stop()
        checkStatus(DisposeAUGraph(graph!))
    }

    func setup() {
        checkStatus(AUGraphStop(graph!))

        // Remove and add io node
        if ioNode.audioNode != 0 {
            checkStatus(AUGraphRemoveNode(graph!, ioNode.audioNode))
        }
        checkStatus(AUGraphAddNode(graph!, &ioNode.cd, &ioNode.audioNode))
        checkStatus(AUGraphNodeInfo(graph!, ioNode.audioNode, nil, &ioNode.audioUnit))

        var enableFlag: UInt32 = 1
        var disableFlag: UInt32 = 0

        // Enable output on io node
        checkStatus(AudioUnitSetProperty(ioNode.audioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, Bus.output.rawValue, &enableFlag, UInt32(MemoryLayout<UInt32>.size)))

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
        checkStatus(AudioUnitSetProperty(ioNode.audioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, Bus.output.rawValue, &streamFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)))

        // Set buffer size
        var maxFrames = UInt32(buffer.capacity)
        checkStatus(AudioUnitSetProperty(ioNode.audioUnit!, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, UInt32(MemoryLayout<UInt32>.size)))

        if inputEnabled {
            // Enable input on io node
            checkStatus(AudioUnitSetProperty(ioNode.audioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, Bus.input.rawValue, &enableFlag, UInt32(MemoryLayout<UInt32>.size)))

            // Set the stream format for output of the audio input bus
            checkStatus(AudioUnitSetProperty(ioNode.audioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, Bus.input.rawValue, &streamFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)))

            // Disable buffer allocation for the recorder
            checkStatus(AudioUnitSetProperty(ioNode.audioUnit!, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, Bus.input.rawValue, &disableFlag, UInt32(MemoryLayout<UInt32>.size)))

            // Setup input callback
            let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            var callbackStruct = AURenderCallbackStruct(inputProc: inputCallback, inputProcRefCon: context)
            checkStatus(AudioUnitSetProperty(ioNode.audioUnit!, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size)))
        }

        // Connect the io node
        checkStatus(AUGraphConnectNodeInput(graph!, mixerNode.audioNode, 0, ioNode.audioNode, 0))
    }

    open func start() {
        guard !running else { return }
        checkStatus(AUGraphStart(graph!))
    }

    open func stop() {
        guard running else { return }
        checkStatus(AUGraphStop(graph!))
    }

    func performUpdate(_ block: () -> ()) {
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
    public func add(_ channel: Channel) {
        guard !channels.contains(where: { $0.mixer.audioNode == channel.mixer.audioNode }) else { return }
        performUpdate { addFromBlock(channel) }
    }

    func addFromBlock(_ channel: Channel) {
        // Add nodes
        for i in 0..<channel.nodes.count {
            guard var node = channel.nodes.at(i) else { fatalError("Could not create channel node") }
            checkStatus(AUGraphAddNode(graph!, &node.cd, &node.audioNode))
            checkStatus(AUGraphNodeInfo(graph!, node.audioNode, nil, &node.audioUnit))
        }

        // Connect nodes
        for i in 0..<channel.nodes.count {
            guard let sourceNode = channel.nodes.at(i) else { fatalError("Could not create connect node") }

            if var targetNode = channel.nodes.at(i+1) {
                checkStatus(AUGraphConnectNodeInput(graph!, sourceNode.audioNode, 0, targetNode.audioNode, 0))
            } else {
                let bus: UInt32 = mixerNode.addInput(sourceNode)
                checkStatus(AUGraphConnectNodeInput(graph!, sourceNode.audioNode, 0, mixerNode.audioNode, bus))
            }
        }

        channels.append(channel)
    }

    public func remove(_ channel: Channel) {
        guard channels.contains(where: { $0.mixer.audioNode == channel.mixer.audioNode }) else { return }
        performUpdate { removeFromBlock(channel) }
    }

    func removeFromBlock(_ channel: Channel) {
        // Remove nodes
        for i in 0..<channel.nodes.count {
            guard var node = channel.nodes.at(i) else { fatalError("Could not remove channel node") }
            mixerNode.removeInput(node)
            checkStatus(AUGraphRemoveNode(graph!, node.audioNode))
            node.audioNode = 0
            node.audioUnit = nil
        }

        guard let index = channels.index(where: { $0.mixer.audioNode == channel.mixer.audioNode }) else { fatalError("Could not remove channel") }
        channels.remove(at: index)
    }
}


// MARK: Input

extension Graph {
    fileprivate func preloadInput(_ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, _ inTimeStamp: UnsafePointer<AudioTimeStamp>, _ inOutputBusNumber: UInt32, _ inNumberFrames: UInt32) {
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
        bufferList.mBuffers.mData = UnsafeMutableRawPointer(buffer.pointer + buffer.count)

        checkStatus(AudioUnitRender(ioNode.audioUnit!, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, &bufferList))

        let numSamplesRendered = Int(bufferList.mBuffers.mDataByteSize / sampleSize)
        buffer.count += numSamplesRendered;

        // Notify new data
        DispatchQueue.main.async {
            self.inputAvailable?(self.buffer.count)
        }
    }

    public func renderInput(_ data: UnsafeMutablePointer<Double>, count: Int) -> Int {
        var renderCount = 0
        queue.sync {
            renderCount = self.renderInQueue(data, count: count)
        }
        return renderCount
    }

    fileprivate func renderInQueue(_ data: UnsafeMutablePointer<Double>, count: Int) -> Int {
        let renderCount = min(count, self.buffer.count)
        guard renderCount > 0 else { return 0 }
        data.assign(from: buffer.pointer, count: renderCount)
        buffer.removeRange(0..<renderCount)
        return renderCount
    }
}


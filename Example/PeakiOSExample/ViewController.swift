// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioUnit
import Peak
import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var waveformView: WaveformView!
    @IBOutlet var channelControlViews: [UIView]!

    fileprivate var inputBuffer: Buffer!
    fileprivate var waveformBuffer: Buffer!
    fileprivate let waveformDuration: TimeInterval = 5

    var graph: Graph!
    var mixer: MixerNode!
    var channels: [Channel]!

    override func viewDidLoad() {
        super.viewDidLoad()

        channels = [
            Channel(nodes: [SamplerNode()]),
            Channel(nodes: [SamplerNode()])
        ]

        graph = Graph(inputEnabled: true)
        graph.add(channels[0])
        graph.add(channels[1])
        graph.start()
        graph.inputAvailable = { count in
            self.step(count)
        }

        waveformView.mark(time: waveformDuration - 1)
        inputBuffer = Buffer(capacity: Int(Double(graph.sampleRate) * waveformDuration))
    }

    fileprivate func step(_ availableCount: Int) {
        precondition(availableCount <= inputBuffer.capacity)

        // Rotate the buffer
        if inputBuffer.count + availableCount > inputBuffer.capacity {
            let neededSpace = availableCount - (inputBuffer.capacity - inputBuffer.count)
            let reusedSpace = max(0, inputBuffer.count - neededSpace)
            inputBuffer.withUnsafeMutableBufferPointer { pointer in
                pointer.baseAddress?.assign(from: pointer.baseAddress! + neededSpace, count: reusedSpace)
            }
            inputBuffer.count = reusedSpace
        }

        // Fill buffer with data
        inputBuffer.withUnsafeMutableBufferPointer { pointer in
            inputBuffer.count += graph.renderInput(pointer.baseAddress! + inputBuffer.count, count: availableCount)
        }
        assert(inputBuffer.count <= inputBuffer.capacity)

        // Update waveform view
        waveformBuffer = inputBuffer.copy()
        DispatchQueue.main.async {
            self.waveformView.setSamples(self.waveformBuffer)
        }
    }


    // MARK: Channel Config

    @IBAction func addChannel(_ sender: UIButton) {
        let channel = channels[sender.tag]
        graph.add(channel)

        let controlView = channelControlViews[sender.tag]
        controlView.alpha = 1.0
        controlView.isUserInteractionEnabled = true
    }

    @IBAction func removeChannel(_ sender: UIButton) {
        let channel = channels[sender.tag]
        graph.remove(channel)

        let controlView = channelControlViews[sender.tag]
        controlView.alpha = 0.2
        controlView.isUserInteractionEnabled = false
    }


    // MARK: Channel Controls

    @IBAction func channelStart(_ sender: UIButton) {
        let channel = channels[sender.tag]
        let note = 0x30 + UInt32(sender.tag) * 0x10
        MusicDeviceMIDIEvent(channel.audioUnit!, 0x90, note, 0x7f, 0);
    }

    @IBAction func channelStop(_ sender: UIButton) {
        let channel = channels[sender.tag]
        let note = 0x30 + UInt32(sender.tag) * 0x10
        MusicDeviceMIDIEvent(channel.audioUnit!, 0x80, note, 0x00, 0);
    }

    @IBAction func channelLevel(_ sender: UISlider) {
        let channel = channels[sender.tag]
        let value = AudioUnitParameterValue(sender.value)
        channel.setParam(.level, value: value)
    }

    @IBAction func channelEnabled(_ sender: UISwitch) {
        let channel = channels[sender.tag]
        let value = AudioUnitParameterValue(sender.isOn ? 1 : 0)
        channel.setParam(.enabled, value: value)
    }


    // MARK: IO Node

    @IBAction func inputEnabled(_ sender: UISwitch) {
        graph.inputEnabled = sender.isOn
    }
}


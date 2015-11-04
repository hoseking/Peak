// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import XCTest
@testable import Peak

class PeakTests: XCTestCase {

    func testLoadWave() {
        let bundlePath = NSBundle(forClass: PeakTests.self).pathForResource("sin_1000Hz_-3dBFS_1s", ofType: "wav")
        guard let path = bundlePath else {
            XCTFail("Could not find wave file")
            return
        }

        guard let audioFile = AudioFile.open(path) else {
            XCTFail("Failed to open wave file")
            return
        }

        XCTAssertEqual(audioFile.sampleRate, 44100)

        let audioLengthInSeconds = 1.0
        let expextedFrameCount = Int64(audioLengthInSeconds * audioFile.sampleRate)
        XCTAssert(abs(audioFile.frameCount - expextedFrameCount) < 5)

        XCTAssertEqual(audioFile.currentFrame, 0)

        let readLength = 1024
        var data = [Double](count: readLength, repeatedValue: 0.0)
        let actualLength = audioFile.readFrames(&data, count: readLength)
        XCTAssertEqual(actualLength, readLength)
        XCTAssertEqual(audioFile.currentFrame, readLength)
    }

    func testCreateLossless() {
        let fileName = NSProcessInfo.processInfo().globallyUniqueString + ".m4a"
        let path = NSTemporaryDirectory() + "/" + fileName

        guard let audioFile = AudioFile.createLossless(path, sampleRate: 44100, overwrite: true) else {
            XCTFail("Failed to create lossless audio file")
            return
        }

        XCTAssertEqual(audioFile.sampleRate, 44100)

        let data = [Double](count: 1024, repeatedValue: 0.0)
        XCTAssert(audioFile.writeFrames(data, count: 1024))
    }

    func testReadMIDI() {
        let bundlePath = NSBundle(forClass: PeakTests.self).pathForResource("alb_esp1", ofType: "mid")
        guard let path = bundlePath else {
            XCTFail("Could not find midi file")
            return
        }

        guard let midi = MIDIFile(filePath: path) else {
            XCTFail("Could not open midi file")
            return
        }

        let events = midi.noteEvents
        XCTAssertEqual(events.count, 634)
        XCTAssertEqual(events[0].timeStamp, 0.5)
        XCTAssertEqual(events[0].note, 81)
        XCTAssertEqual(events[1].timeStamp, 0.5)
        XCTAssertEqual(events[1].note, 57)
        XCTAssertEqual(events[2].timeStamp, 1.0)
        XCTAssertEqual(events[2].note, 88)
        XCTAssertEqual(events[3].timeStamp, 1.0)
        XCTAssertEqual(events[3].note, 64)

        let tempoEvents = midi.tempoEvents
        XCTAssertEqual(tempoEvents.count, 556)
    }
    
}

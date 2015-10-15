// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox
import Foundation

public class AudioFile {

    private var audioFileRef: ExtAudioFileRef = nil
    private var fileDataFormat = AudioStreamBasicDescription()
    private var outputDataFormat = AudioStreamBasicDescription()

    public init?(filePath: String) {
        let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, .CFURLPOSIXPathStyle, false)
        let openStatus = ExtAudioFileOpenURL(fileURL, &audioFileRef)
        guard openStatus == noErr else {
            print("Failed to open audio file '\(filePath)' with error \(openStatus)")
            return nil
        }

        var descriptionSize = UInt32(sizeof(AudioStreamBasicDescription))
        let getPropertyStatus = ExtAudioFileGetProperty(audioFileRef, kExtAudioFileProperty_FileDataFormat, &descriptionSize, &fileDataFormat);
        guard getPropertyStatus == noErr else {
            print("Failed to get audio file data format with error \(getPropertyStatus)")
            return nil
        }

        let bytesPerFrame = UInt32(sizeof(Double))
        outputDataFormat = AudioStreamBasicDescription(
            mSampleRate: fileDataFormat.mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 8 * bytesPerFrame,
            mReserved: 0)

        let setPropertyStatus = ExtAudioFileSetProperty(audioFileRef, kExtAudioFileProperty_ClientDataFormat, descriptionSize, &outputDataFormat);
        guard setPropertyStatus == noErr else {
            print("Failed to set audio file output data format with error \(setPropertyStatus)")
            return nil
        }
    }

    deinit {
        ExtAudioFileDispose(audioFileRef)
    }

    public var sampleRate: Double {
        return fileDataFormat.mSampleRate
    }

    public var frameCount: Int64 {
        var numberOfFrames: Int64 = 0
        var numberOfFramesSize = UInt32(sizeof(Int64))
        let status = ExtAudioFileGetProperty(audioFileRef, kExtAudioFileProperty_FileLengthFrames, &numberOfFramesSize, &numberOfFrames)
        if status != noErr {
            print("Failed to query audio file frame count with error \(status)")
            return 0
        }

        return numberOfFrames
    }

    public var currentFrame: Int {
        get {
            var frame: Int64 = 0
            guard ExtAudioFileTell(audioFileRef, &frame) == noErr else {
                fatalError("Failed to get current read location")
            }
            return Int(frame)
        }
        set {
            let frame = Int64(newValue)
            guard ExtAudioFileSeek(audioFileRef, frame) == noErr else {
                fatalError("Failed to set current read location")
            }
        }
    }

    public func readFrames(inout data: [Double], count: Int) -> Int? {
        if data.capacity < count {
            data.reserveCapacity(count)
        }
        for _ in data.count..<count {
            data.append(0.0)
        }

        var bufferList = AudioBufferList()
        bufferList.mNumberBuffers = 1
        bufferList.mBuffers.mNumberChannels = 1
        bufferList.mBuffers.mDataByteSize = UInt32(count * sizeof(Double))
        bufferList.mBuffers.mData = UnsafeMutablePointer(data)

        var numberOfFrames = UInt32(count)
        let status = ExtAudioFileRead(audioFileRef, &numberOfFrames, &bufferList);
        guard status == noErr else {
            print("Failed to read data from audio file with error \(status)")
            return nil
        }

        return Int(numberOfFrames)
    }
    
}

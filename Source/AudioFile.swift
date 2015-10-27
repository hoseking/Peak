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

    /**
      Open an existing audio file.

      - parameter filePath: The file path.
      - returns: The AudioFile or nil if the file doesn't exist or can't be opened.
     */
    public class func open(filePath: String) -> AudioFile? {
        var audioFileRef: ExtAudioFileRef = nil
        let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, .CFURLPOSIXPathStyle, false)
        let openStatus = ExtAudioFileOpenURL(fileURL, &audioFileRef)
        guard openStatus == noErr else {
            print("Failed to open audio file '\(filePath)' with error \(openStatus)")
            return nil
        }

        var fileDataFormat = AudioStreamBasicDescription()
        var descriptionSize = UInt32(sizeof(AudioStreamBasicDescription))
        let getPropertyStatus = ExtAudioFileGetProperty(audioFileRef, kExtAudioFileProperty_FileDataFormat, &descriptionSize, &fileDataFormat);
        guard getPropertyStatus == noErr else {
            print("Failed to get audio file data format with error \(getPropertyStatus)")
            return nil
        }

        return AudioFile(audioFileRef: audioFileRef, fileDataFormat: fileDataFormat)
    }

    /**
      Create a new audio file. Currenly only single channel files are supported.
      
      - parameter filePath:   The new file path
      - parameter type:       The type of file to create. See `AudioFileTypeID`.
      - parameter format:     The audio format to use. See `AudioFormatID`.
      - parameter sampleRate: The sample rate to use in the new file.
      - parameter overwrite:  Wheter to overwrite an existing file. If `false` and a file exists at the given path the return value will be nil.
      - returns: The newly created AudioFile or nil if the file couldn't be created.
     */
    public class func create(filePath: String, type: AudioFileTypeID, format: AudioFormatID, sampleRate: Double, overwrite: Bool) -> AudioFile? {
        var audioFileRef: ExtAudioFileRef = nil

        let bytesPerFrame = UInt32(sizeof(Double))
        var dataFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: format,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 8 * bytesPerFrame,
            mReserved: 0)
        let dataFormatPointer = withUnsafePointer(&dataFormat) { $0 }
        let flags = overwrite ? AudioFileFlags.EraseFile.rawValue : 0
        let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, .CFURLPOSIXPathStyle, false)
        let createStatus = ExtAudioFileCreateWithURL(fileURL, type, dataFormatPointer, nil, flags, &audioFileRef)
        guard createStatus == noErr else {
            print("Failed to create audio file '\(filePath)' with error \(createStatus)")
            return nil
        }

        return AudioFile(audioFileRef: audioFileRef, fileDataFormat: dataFormat)
    }

    /**
      Convenience method to create a lossless audio file. Currenly only single channel files are supported.

      - parameter filePath:   The new file path
      - parameter sampleRate: The sample rate to use in the new file.
      - parameter overwrite:  Wheter to overwrite an existing file. If `false` and a file exists at the given path the return value will be nil.
      - returns: The newly created AudioFile or nil if the file couldn't be created.
     */
    public class func createLossless(filePath: String, sampleRate: Double, overwrite: Bool) -> AudioFile? {
        return create(filePath, type: kAudioFileM4AType, format: kAudioFormatAppleLossless, sampleRate: sampleRate, overwrite: overwrite)
    }

    init(audioFileRef: ExtAudioFileRef, fileDataFormat: AudioStreamBasicDescription) {
        self.audioFileRef = audioFileRef
        self.fileDataFormat = fileDataFormat

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

        let descriptionSize = UInt32(sizeof(AudioStreamBasicDescription))
        let setPropertyStatus = ExtAudioFileSetProperty(audioFileRef, kExtAudioFileProperty_ClientDataFormat, descriptionSize, &outputDataFormat);
        assert(setPropertyStatus == noErr, "Failed to set audio file output data format with error \(setPropertyStatus)")
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
        let status = ExtAudioFileRead(audioFileRef, &numberOfFrames, &bufferList)
        guard status == noErr else {
            print("Failed to read data from audio file with error \(status)")
            return nil
        }

        return Int(numberOfFrames)
    }

    public func writeFrames(data: [Double], count: Int) -> Bool {
        var bufferList = AudioBufferList()
        bufferList.mNumberBuffers = 1
        bufferList.mBuffers.mNumberChannels = 1
        bufferList.mBuffers.mDataByteSize = UInt32(count * sizeof(Double))
        bufferList.mBuffers.mData = UnsafeMutablePointer(data)

        let status = ExtAudioFileWrite(audioFileRef, UInt32(count), &bufferList)
        guard status == noErr else {
            print("Failed to write data to the audio file with error \(status)")
            return false
        }

        return true
    }
    
}

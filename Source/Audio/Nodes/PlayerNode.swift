// Created by hoseking on 17/05/16.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

public class PlayerNode: Node {
    private struct ScheduledAudio {
        let audioFileID: AudioFileID
        let startTime: AudioTimeStamp
        let region: ScheduledAudioFileRegion

        init(filePath: String) {
            let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, filePath, .CFURLPOSIXPathStyle, false)

            var audioFileID: AudioFileID = nil
            checkStatus(AudioFileOpenURL(fileURL, AudioFilePermissions.ReadPermission, 0, &audioFileID))
            self.audioFileID = audioFileID

            let smpteTime = SMPTETime(mSubframes: 0, mSubframeDivisor: 0, mCounter: 0, mType: .Type24, mFlags: .Running, mHours: 0, mMinutes: 0, mSeconds: 0, mFrames: 0)
            let timeStamp = AudioTimeStamp(mSampleTime: 0, mHostTime: 0, mRateScalar: 0, mWordClockTime: 0, mSMPTETime: smpteTime, mFlags: .SampleTimeValid, mReserved: 0)
            self.startTime = AudioTimeStamp(mSampleTime: -1, mHostTime: 0, mRateScalar: 0, mWordClockTime: 0, mSMPTETime: smpteTime, mFlags: .SampleTimeValid, mReserved: 0)

            var audioFileDescription = AudioStreamBasicDescription()
            var audioFileDescriptionSize = UInt32(sizeof(audioFileDescription.dynamicType))
            checkStatus(AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &audioFileDescriptionSize, &audioFileDescription))

            var packetCount = UInt64()
            var packetCountSize = UInt32(sizeof(packetCount.dynamicType))
            checkStatus(AudioFileGetProperty(audioFileID, kAudioFilePropertyAudioDataPacketCount, &packetCountSize, &packetCount))
            let framesToPlay = UInt32(packetCount) * audioFileDescription.mFramesPerPacket

            self.region = ScheduledAudioFileRegion(mTimeStamp: timeStamp, mCompletionProc: nil, mCompletionProcUserData: nil, mAudioFile: audioFileID, mLoopCount: 0, mStartFrame: 0, mFramesToPlay: framesToPlay)
        }
    }

    public var audioUnit: AudioUnit = nil
    public var audioNode: AUNode = 0
    public var cd: AudioComponentDescription

    private let scheduledAudio: ScheduledAudio!

    public init(filePath: String) {
        cd = AudioComponentDescription(manufacturer: kAudioUnitManufacturer_Apple, type: kAudioUnitType_Generator, subType: kAudioUnitSubType_AudioFilePlayer)
        scheduledAudio = ScheduledAudio(filePath: filePath)
    }

    public func play() {
        var audioFileID = scheduledAudio.audioFileID
        var region = scheduledAudio.region
        var startTime = scheduledAudio.startTime

        checkStatus(AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &audioFileID, UInt32(sizeof(audioFileID.dynamicType))))
        checkStatus(AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &region, UInt32(sizeof(region.dynamicType))))
        checkStatus(AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, UInt32(sizeof(startTime.dynamicType))))
    }
}

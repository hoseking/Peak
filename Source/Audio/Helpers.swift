// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox
import Foundation

extension Collection where Index : Comparable {
    func at(_ index: Index) -> Iterator.Element? {
        guard index >= startIndex && index < endIndex else { return nil }
        return self[index]
    }
    
    func at(_ predicate: (Iterator.Element) -> Bool) -> Iterator.Element? {
        if let index = index(where: predicate) {
            return self[index]
        }
        return nil
    }
}

public extension ScheduledAudioFileRegion {
    init(mTimeStamp: AudioTimeStamp, mCompletionProc: ScheduledAudioFileRegionCompletionProc?, mCompletionProcUserData: UnsafeMutableRawPointer, mAudioFile: OpaquePointer, mLoopCount: UInt32, mStartFrame: Int64, mFramesToPlay: UInt32) {
        self.mTimeStamp = mTimeStamp
        self.mCompletionProc = mCompletionProc
        self.mCompletionProcUserData = mCompletionProcUserData
        self.mAudioFile = mAudioFile
        self.mLoopCount = mLoopCount
        self.mStartFrame = mStartFrame
        self.mFramesToPlay = mFramesToPlay
    }
}

extension AudioComponentDescription {
    init(manufacturer: OSType, type: OSType, subType: OSType) {
        self.init(componentType: type, componentSubType: subType, componentManufacturer: manufacturer, componentFlags: 0, componentFlagsMask: 0)
    }
}

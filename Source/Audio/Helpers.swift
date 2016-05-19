// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox
import Foundation

extension CollectionType where Index : Comparable {
    func at(index: Index) -> Generator.Element? {
        guard index >= startIndex && index < endIndex else { return nil }
        return self[index]
    }
    
    func at(@noescape predicate: Generator.Element -> Bool) -> Generator.Element? {
        if let index = indexOf(predicate) {
            return self[index]
        }
        return nil
    }
}

public extension ScheduledAudioFileRegion {
    init(mTimeStamp: AudioTimeStamp, mCompletionProc: ScheduledAudioFileRegionCompletionProc?, mCompletionProcUserData: UnsafeMutablePointer<Void>, mAudioFile: COpaquePointer, mLoopCount: UInt32, mStartFrame: Int64, mFramesToPlay: UInt32) {
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

// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import AudioToolbox

public protocol Node {
    var audioUnit: AudioUnit { get set }
    var audioNode: AUNode { get set }
    var cd: AudioComponentDescription { get set }
}

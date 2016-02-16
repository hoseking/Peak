// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

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

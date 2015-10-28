// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Foundation

/// A `Buffer` is similar to an `Array` but it's a `class` instead of a `struct` and it has a fixed size. 
/// As opposed to an `Array`, assiging a `Buffer` to a new variable will not create a copy, it only creates a new reference.
/// If any reference is modified all other references will reflect the change. To copy a `Buffer` you have to explicitly call `copy()`.
public final class Buffer : MutableCollectionType, ArrayLiteralConvertible {
    public typealias Element = Double
    private var buffer: ManagedBuffer<(Int, Int), Element>

    public var count: Int {
        get {
            return buffer.value.0
        }
        set {
            buffer.value.0 = newValue
        }
    }

    public var capacity: Int {
        return buffer.value.1
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return count
    }

    /// A pointer to the RealArray's memory
    public var pointer: UnsafeMutablePointer<Element> {
        return buffer.withUnsafeMutablePointerToElements { $0 }
    }

    /// Construct an uninitialized RealArray of the given size
    public init(capacity: Int) {
        buffer = ManagedBuffer<(Int, Int), Element>.create(capacity, initialValue: { _ in (0, capacity) })
    }

    /// Construct a RealArray from an array literal
    public convenience init(arrayLiteral elements: Element...) {
        self.init(capacity: elements.count)
        pointer.initializeFrom(elements)
        count = capacity
    }

    /// Construct a RealArray from an array of reals
    public convenience init<C : CollectionType where C.Generator.Element == Element>(_ c: C) {
        self.init(capacity: Int(c.count.toIntMax()))
        pointer.initializeFrom(c)
        count = capacity
    }

    /// Construct a RealArray of `count` elements, each initialized to `repeatedValue`.
    public convenience init(count: Int, repeatedValue: Element) {
        self.init(capacity: count)
        for i in 0..<count {
            self[i] = repeatedValue
        }
        self.count = count
    }

    public subscript(index: Int) -> Element {
        get {
            precondition(0 <= index && index < count)
            return pointer[index]
        }
        set {
            precondition(0 <= index && index < capacity)
            pointer[index] = newValue
        }
    }

    public func copy() -> Buffer {
        let copy = Buffer(capacity: count)
        copy.pointer.initializeFrom(pointer, count: count)
        return copy
    }

    public func append<C : CollectionType where C.Generator.Element == Element>(c: C) {
        let p = pointer + count
        p.initializeFrom(c)
        count += Int(c.count.toIntMax())
    }

    public func removeRange(range: Range<Int>) {
        precondition(range.startIndex <= range.endIndex)
        precondition(0 <= range.startIndex && range.endIndex <= count)

        count -= range.count
        let start = pointer + range.startIndex
        let end = pointer + range.endIndex - 1
        start.assignFrom(end, count: count)
    }
}

extension Buffer : CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        var string = "["
        for v in self {
            string += "\(v.description), "
        }
        if string.startIndex.distanceTo(string.endIndex) > 1 {
            let range = string.endIndex.advancedBy(-2)..<string.endIndex
            string.replaceRange(range, with: "]")
        } else {
            string += "]"
        }
        return string
    }

    public var debugDescription: String {
        return description
    }
}

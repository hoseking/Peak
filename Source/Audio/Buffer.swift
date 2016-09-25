// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Foundation

/// A `Buffer` is similar to an `Array` but it's a `class` instead of a `struct` and it has a fixed size. 
/// As opposed to an `Array`, assiging a `Buffer` to a new variable will not create a copy, it only creates a new reference.
/// If any reference is modified all other references will reflect the change. To copy a `Buffer` you have to explicitly call `copy()`.
public final class Buffer : MutableCollection, ExpressibleByArrayLiteral {

    public typealias Element = Double
    fileprivate var buffer: ManagedBuffer<(Int, Int), Element>

    public var count: Int {
        get {
            return buffer.header.0
        }
        set {
            buffer.header.0 = newValue
        }
    }

    public var capacity: Int {
        return buffer.header.1
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return count
    }

    /// Returns the position immediately after the given index.
    ///
    /// - parameter i: A valid index of the collection. `i` must be less than `endIndex`.
    /// - returns: The index value immediately after `i`.
    public func index(after i: Int) -> Int {
        return i + 1
    }

    /// A pointer to the RealArray's memory
    var pointer: UnsafeMutablePointer<Element> {
        return buffer.withUnsafeMutablePointerToElements { $0 }
    }

    public func withUnsafeBufferPointer<R>(body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R {
        return try body(UnsafeBufferPointer(start: pointer, count: count))
    }

    public func withUnsafeMutableBufferPointer<R>(body: (UnsafeMutableBufferPointer<Element>) throws -> R) rethrows -> R {
        return try body(UnsafeMutableBufferPointer(start: pointer, count: count))
    }

    /// Construct an uninitialized RealArray of the given size
    public init(capacity: Int) {
        buffer = ManagedBuffer<(Int, Int), Element>.create(minimumCapacity: capacity, makingHeaderWith: { _ in (0, capacity) })
    }

    /// Construct a RealArray from an array literal
    public convenience init(arrayLiteral elements: Element...) {
        self.init(capacity: elements.count)
        pointer.initialize(from: elements)
        count = capacity
    }

    /// Construct a RealArray from an array of reals
    public convenience init<C : Collection>(_ c: C) where C.Iterator.Element == Element {
        self.init(capacity: Int(c.count.toIntMax()))
        pointer.initialize(from: c)
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
        copy.pointer.initialize(from: pointer, count: count)
        copy.count = count
        return copy
    }

    public func append<C : Collection>(_ c: C) where C.Iterator.Element == Element {
        let p = pointer + count
        p.initialize(from: c)
        count += Int(c.count.toIntMax())
    }

    public func removeRange(_ range: Range<Int>) {
        precondition(range.lowerBound <= range.upperBound)
        precondition(0 <= range.lowerBound && range.upperBound <= count)

        count -= range.count
        let start = pointer + range.lowerBound
        let end = pointer + range.upperBound - 1
        start.assign(from: end, count: count)
    }
}

extension Buffer : CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        var string = "["
        for v in self {
            string += "\(v.description), "
        }
        if string.characters.distance(from: string.startIndex, to: string.endIndex) > 1 {
            let range = string.characters.index(string.endIndex, offsetBy: -2)..<string.endIndex
            string.replaceSubrange(range, with: "]")
        } else {
            string += "]"
        }
        return string
    }

    public var debugDescription: String {
        return description
    }
}

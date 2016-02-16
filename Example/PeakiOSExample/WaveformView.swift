// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of Peak. The full Peak copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

import Accelerate
import UIKit
import Peak

/**
  A UIView that displays waveform samples. It uses RMS (root mean square) to combine multiple samples into an
  individual pixel.
*/
public class WaveformView: UIScrollView {
    @IBInspectable var lineColor: UIColor? = UIColor.blueColor()
    @IBInspectable var markerColor: UIColor? = UIColor.redColor()

    var lineWidth: CGFloat = 1.0

    private var samples: Buffer?
    private var markIndex: Int = -1

    var sampleRate: Double = 44100

    var startFrame: Int = 0 {
        didSet {
            setNeedsDisplay()
        }
    }

    private var endFrame: Int {
        get {
            return startFrame + Int(visibleDuration * Double(sampleRate))
        }
    }

    var duration: NSTimeInterval {
        get {
            return NSTimeInterval(samples?.count ?? 0) / sampleRate
        }
    }

    var visibleDuration: NSTimeInterval = 5 {
        didSet {
            setNeedsLayout()
        }
    }

    var samplesPerPoint: CGFloat {
        get {
            return CGFloat(endFrame - startFrame) / bounds.size.width
        }
    }

    public func setSamples(samples: Buffer) {
        self.samples = samples
        setNeedsLayout()
    }

    public func mark(time time: NSTimeInterval) {
        markIndex = Int(time * sampleRate)
        setNeedsDisplay()
    }

    override public func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()

        backgroundColor?.setFill()
        CGContextFillRect(context, rect)

        lineColor?.setFill()
        lineColor?.setStroke()
        CGContextSetLineWidth(context, lineWidth)

        let path = createPath()

        // Draw top
        CGContextAddPath(context, path)
        CGContextFillPath(context)

        // Draw bottom
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, 0, bounds.size.height)
        CGContextScaleCTM(context, 1, -1)
        CGContextAddPath(context, path)
        CGContextFillPath(context)
        CGContextRestoreGState(context)

        // Draw marker
        markerColor?.setFill()
        let x = self.bounds.width * CGFloat(markIndex - startFrame) / CGFloat(endFrame - startFrame)
        CGContextFillRect(context, CGRect(x: x - 0.5, y: 0, width: 1, height: self.bounds.height))
    }

    override public func layoutSubviews() {
        contentInset.top = 0
        contentSize.height = bounds.height
        contentSize.width = CGFloat(samples?.count ?? 0) / samplesPerPoint
        startFrame = max(0, Int(samplesPerPoint * bounds.minX))
        setNeedsDisplay()
    }

    private func createPath() -> CGPath? {
        guard let samples = samples else { return nil }

        let height = bounds.size.height
        let pixelSize = 1.0 / contentScaleFactor
        let samplesPerPixel = Int(ceil(samplesPerPoint * pixelSize))

        var point = CGPointMake(max(bounds.minX, 0), height/2);

        let path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, point.x, point.y)

        for var sampleIndex = startFrame; sampleIndex < samples.count && sampleIndex < endFrame; sampleIndex += samplesPerPixel {
            // Get the RMS value for the current pixel
            let size = vDSP_Length(min(samplesPerPixel, samples.count - sampleIndex))
            var value: Double = 0.0
            samples.withUnsafeBufferPointer { pointer in
                vDSP_rmsqvD(pointer.baseAddress + sampleIndex, 1, &value, size)
            }

            point.x += pixelSize;
            point.y = height/2 - CGFloat(value) * height/2;
            CGPathAddLineToPoint(path, nil, point.x, point.y)
        }
        CGPathAddLineToPoint(path, nil, point.x, height/2)
        CGPathCloseSubpath(path)
        return path
    }
}

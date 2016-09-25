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
open class WaveformView: UIScrollView {
    @IBInspectable var lineColor: UIColor? = UIColor.blue
    @IBInspectable var markerColor: UIColor? = UIColor.red

    var lineWidth: CGFloat = 1.0

    fileprivate var samples: Buffer?
    fileprivate var markIndex: Int = -1

    var sampleRate: Double = 44100

    var startFrame: Int = 0 {
        didSet {
            setNeedsDisplay()
        }
    }

    fileprivate var endFrame: Int {
        get {
            return startFrame + Int(visibleDuration * Double(sampleRate))
        }
    }

    var duration: TimeInterval {
        get {
            return TimeInterval(samples?.count ?? 0) / sampleRate
        }
    }

    var visibleDuration: TimeInterval = 5 {
        didSet {
            setNeedsLayout()
        }
    }

    var samplesPerPoint: CGFloat {
        get {
            return CGFloat(endFrame - startFrame) / bounds.size.width
        }
    }

    open func setSamples(_ samples: Buffer) {
        self.samples = samples
        setNeedsLayout()
    }

    open func mark(time: TimeInterval) {
        markIndex = Int(time * sampleRate)
        setNeedsDisplay()
    }

    override open func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        backgroundColor?.setFill()
        context.fill(rect)

        lineColor?.setFill()
        lineColor?.setStroke()
        context.setLineWidth(lineWidth)

        guard let path = createPath() else { return }

        // Draw top
        context.addPath(path)
        context.fillPath()

        // Draw bottom
        context.saveGState()
        context.translateBy(x: 0, y: bounds.size.height)
        context.scaleBy(x: 1, y: -1)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        // Draw marker
        markerColor?.setFill()
        let x = self.bounds.width * CGFloat(markIndex - startFrame) / CGFloat(endFrame - startFrame)
        context.fill(CGRect(x: x - 0.5, y: 0, width: 1, height: self.bounds.height))
    }

    override open func layoutSubviews() {
        contentInset.top = 0
        contentSize.height = bounds.height
        contentSize.width = CGFloat(samples?.count ?? 0) / samplesPerPoint
        startFrame = max(0, Int(samplesPerPoint * bounds.minX))
        setNeedsDisplay()
    }

    fileprivate func createPath() -> CGPath? {
        guard let samples = samples else { return nil }

        let height = bounds.size.height
        let pixelSize = 1.0 / contentScaleFactor
        let samplesPerPixel = Int(ceil(samplesPerPoint * pixelSize))

        var point = CGPoint(x: max(bounds.minX, 0), y: height/2);

        let path = CGMutablePath()
        path.move(to: point)

        for sampleIndex in stride(from: startFrame, to: endFrame, by: samplesPerPixel) {
            if sampleIndex >= samples.count {
                break
            }
            // Get the RMS value for the current pixel
            let size = vDSP_Length(min(samplesPerPixel, samples.count - sampleIndex))
            var value: Double = 0.0
            samples.withUnsafeBufferPointer { pointer in
                vDSP_rmsqvD(pointer.baseAddress! + sampleIndex, 1, &value, size)
            }

            point.x += pixelSize;
            point.y = height/2 - CGFloat(value) * height/2;
            path.addLine(to: point)
        }
        path.addLine(to: CGPoint(x: point.x, y: height/2))
        path.closeSubpath()
        return path
    }
}

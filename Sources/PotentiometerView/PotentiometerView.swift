//
//  PotentiometerView.swift
//  PotentiometerView
//
//  Created by Daniel Hooper on 2024-03-10.
//

#if canImport(UIKit)
import UIKit

protocol PotentiometerDelegate: AnyObject {
    func valueDidChange(_ value: Double)
}

/// A circular view with an indicator, like the hand of the clock, that indicates a value along a circular path
public class PotentiometerView: UIView {
    
    /// The layer for drawing an indicator, which can be thought of as a hand on a clock.
    internal let indicatorLayer = CAShapeLayer()
    
    /// A semi circle that outlines where the indicator will follow along.
    internal let potentiometerLayer = CAShapeLayer()
    
    /// A highlighted portion of the potentiometer track that will visually reflect the current value.
    internal let potentiometerHighlightLayer = CAShapeLayer()
        
    /// The starting angle for the potentiometer's track, in radians.
    /// `π / 6` splits the circle into 12 segments, like a clock. This can then be multiplied to represent a certain number of hours around the clock.
    /// In this case, `3 * π / 6` is located at 6 o'clock.
    internal let startAngle: CGFloat
    
    /// The ending angle for the potentiometer's track, in radians.
    /// A value of `0` represents 3 o'clock.
    internal let endAngle: CGFloat
    
    /// The angle to point the indicator, in radians.
    internal var indicatorAngle: CGFloat = 0
    
    /// An offset used to create a small gap between the indicator and the potentiometer track for visual clarity.
    internal var indicatorGapOffset: CGFloat {
        let size = min(frame.width, frame.height)
        let lineWidth = isLineWidthProportional ? size * 0.1 : lineWidth
        return lineWidth / min(frame.width, frame.height)
    }
    
    /// An offset used to fix the rotation of the indicator to accomodate for different `startAngle` and `endAngle` values.
    internal var rotationOffset: CGFloat {
        0.5
    }
    
    internal var lineWidth: Double { 3.0 }
    
    internal var isLineWidthProportional = true

    /// The color of the potentiometer track.
    internal let potentiometerColor: UIColor
    
    /// A color to highlight all or a portion of the potentiometer track in relation to the view's value.
    internal let potentiometerHighlightColor: UIColor
    
    /// The color or the potentiometer's indicator.
    internal let indicatorColor: UIColor
    
    internal var panStartLocation: CGPoint = .zero
    internal var panPreviousLocation: CGPoint = .zero
    internal var panTotalDistance: CGFloat = 0.0
    
    /// A normalized value from 0 to 1 that sets the position of the indicator.
    /// A value of 0 points the indicator to the bottom left, while a value of 1 points the indicator to the bottom right.
    /// A value of 0.5 would point the indicator directly upwards, in the middle.
    internal var value: Double {
        didSet {
            delegate?.valueDidChange(value)
        }
    }
    
    weak var delegate: PotentiometerDelegate?

    init(frame: CGRect, value: Double, startAngle: CGFloat = 4 * Double.pi / 6, endAngle: CGFloat = 2 * Double.pi / 6,  potentiometerColor: UIColor, highlightColor: UIColor, indicatorColor: UIColor) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.value = value
        self.potentiometerColor = potentiometerColor
        self.potentiometerHighlightColor = highlightColor
        self.indicatorColor = indicatorColor
        super.init(frame: frame)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        addGestureRecognizer(panGesture)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // For some reason it's necessary to set this frame here.
        indicatorLayer.frame = rect
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        drawPotentiometerTrack()
        drawIndicator()
        indicatorLayer.frame = bounds
        setValue(value, animationDuration: 0.0, animationCurve: .default)
    }
    
    /// Sets the internal `value` property and rotates the indicator to its corresponding angle
    /// with an animation configured by the `animationDuration` and `animationCurve` arguments.
    /// Use an`animationDuration` value of 0.001 to update the view without noticeable animation.
    func setValue(_ value: Double, animationDuration: Double, animationCurve: CAMediaTimingFunctionName = .easeInEaseOut) {
        let oldValue = self.value
        self.value = value
        let radius = min(frame.width, frame.height) / 2
        let circumference = 2 * Double.pi * radius
        let arcLength = arcLength(startAngle: endAngle, endAngle: startAngle, radius: radius)
        let offset = rotationOffset// 2.0//0.75
        let normalized = normalizeValue(value: value - offset, minValue: 0, maxValue: circumference - arcLength)
        let angle = calculateAngle(value: normalized, circumference: circumference)
        rotateIndicator(to: angle, duration: animationDuration, animationCurve: animationCurve)
        animatePotentiometerTrack(from: oldValue, to: value, duration: animationDuration, animationCurve: animationCurve)
    }
    
    internal func drawPotentiometerTrack() {
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let radius = min(frame.width, frame.height) / 2 //* 0.5
                
        let rightEndStrokeLayer = CAShapeLayer()
        rightEndStrokeLayer.strokeStart = 1 - (indicatorGapOffset * 0.25)

        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        [potentiometerLayer, rightEndStrokeLayer, potentiometerHighlightLayer].forEach { sublayer in
            sublayer.path = path.cgPath
            sublayer.lineWidth = isLineWidthProportional ? radius * 0.2 : lineWidth
            sublayer.strokeColor = potentiometerColor.cgColor
            sublayer.lineCap = .round
            sublayer.fillColor = UIColor.clear.cgColor
            layer.addSublayer(sublayer)
        }

        potentiometerHighlightLayer.strokeColor = potentiometerHighlightColor.cgColor
    }
    
    internal func drawIndicator() {
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let radius = min(bounds.width, bounds.height) / 2 //- lineWidth * 0.5
        
        let indicatorPath = UIBezierPath()
        indicatorPath.move(to: CGPoint(x: center.x, y: center.y - radius))
        indicatorPath.addLine(to: CGPoint(x: center.x, y: center.y))
        
        indicatorLayer.path = indicatorPath.cgPath
        indicatorLayer.lineCap = .round
        indicatorLayer.lineWidth =  isLineWidthProportional ? radius * 0.2 : lineWidth
        indicatorLayer.strokeColor = indicatorColor.cgColor
        layer.addSublayer(indicatorLayer)
    }
    
    internal func rotateIndicator(to angle: CGFloat, duration: CGFloat, animationCurve: CAMediaTimingFunctionName) {
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = indicatorAngle
        rotation.toValue = angle
        rotation.duration = duration
        rotation.isRemovedOnCompletion = false
        rotation.fillMode = .forwards
        rotation.timingFunction = CAMediaTimingFunction(name: animationCurve)
        indicatorLayer.add(rotation, forKey: nil)
        indicatorAngle = angle
    }
    
    internal func animatePotentiometerTrack(from: CGFloat, to: CGFloat, duration: CGFloat, animationCurve: CAMediaTimingFunctionName) {
        let strokeEndAnimation = CABasicAnimation(keyPath: "strokeEnd")
        let strokeStartAnimation = CABasicAnimation(keyPath: "strokeStart")

        [strokeEndAnimation, strokeStartAnimation].forEach { animation in
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: animationCurve)
        }
        
        strokeEndAnimation.fromValue = from
        strokeEndAnimation.toValue = to
        potentiometerHighlightLayer.add(strokeEndAnimation, forKey: "strokeEndAnimation")
        
        strokeStartAnimation.fromValue = from + indicatorGapOffset
        strokeStartAnimation.toValue = to + indicatorGapOffset
        potentiometerLayer.add(strokeStartAnimation, forKey: "strokeStartAnimation")
    }
    
    /// Calculates the arc length (distance along the circle)
    internal func arcLength(startAngle: Double, endAngle: Double, radius: Double) -> Double {
        radius * (endAngle - startAngle)
    }
    
    internal func normalizeValue(value: Double, minValue: Double, maxValue: Double) -> Double {
        minValue + (maxValue - minValue) * value
    }
    
    internal func calculateAngle(value: Double, circumference: Double) -> Double {
        (value * 2 * Double.pi) / circumference
    }
    
    @objc func panAction(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)

         switch gesture.state {
         case .changed:
             let viewHeight = frame.height
             let positionY = viewHeight - location.y
             let percentage = positionY / viewHeight
             let newValue = max(0, min(1.0 * percentage, 1.0))
             setValue(newValue, animationDuration: 0.001)
         default:
             break
         }
    }
}

public class SmallPotentiometerView: PotentiometerView {
    
    internal override var rotationOffset: CGFloat { 2.0 }
    internal override var lineWidth: Double { 4.0 }
    
    init(frame: CGRect, value: Double, potentiometerColor: UIColor, indicatorColor: UIColor) {
        super.init(frame: frame,
                   value: value,
                   startAngle: 3 * Double.pi / 6,
                   endAngle: 0.0,
                   potentiometerColor: potentiometerColor,
                   highlightColor: .systemOrange,
                   indicatorColor: indicatorColor)
    }
}

public class CenteredPotentiometerView: PotentiometerView {

    /// An additional potentiometer layer to draw from the top center of the circle to the bottom right
    /// The original `potentiometerLayer` will then draw from the bottom left to the top center
    internal let rightwardPotentiometerLayer = CAShapeLayer()
        
    internal override func drawPotentiometerTrack() {
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let radius = min(frame.width, frame.height) / 2
        let trackPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        let rightEndStrokeLayer = CAShapeLayer()
        rightEndStrokeLayer.strokeStart = 1 - (indicatorGapOffset * 0.25)
        
        let leftEndStrokeLayer = CAShapeLayer()
        leftEndStrokeLayer.strokeEnd = indicatorGapOffset * 0.25
        
        [potentiometerLayer, leftEndStrokeLayer, rightwardPotentiometerLayer, rightEndStrokeLayer, potentiometerHighlightLayer].forEach { sublayer in
            sublayer.path = trackPath.cgPath
            sublayer.lineWidth = 3.0
            sublayer.fillColor = UIColor.clear.cgColor
            sublayer.lineCap = .round
            sublayer.strokeColor = potentiometerColor.cgColor
            layer.addSublayer(sublayer)
        }
        
        potentiometerHighlightLayer.strokeStart = 0.5
        potentiometerHighlightLayer.strokeEnd = 0.5
        potentiometerHighlightLayer.lineCap = .butt
        potentiometerLayer.strokeEnd = 0.5 - indicatorGapOffset
        rightwardPotentiometerLayer.strokeStart = 0.5 + indicatorGapOffset

        potentiometerHighlightLayer.strokeColor = UIColor.systemOrange.cgColor
    }

    internal override func animatePotentiometerTrack(from: CGFloat, to: CGFloat, duration: CGFloat, animationCurve: CAMediaTimingFunctionName) {
        guard to != from else { return }
        
        let isLeftToRight = from <= 0.5 && to > 0.5
        let isRightToLeft = from >= 0.5 && to < 0.5

        let leftTrackEnd = CAKeyframeAnimation(keyPath: "strokeEnd")
        let rightTrackStart = CAKeyframeAnimation(keyPath: "strokeStart")
        
        let highlightStart = CAKeyframeAnimation(keyPath: "strokeStart")
        let highlightEnd = CAKeyframeAnimation(keyPath: "strokeEnd")

        // Assign the default values we need
        [leftTrackEnd, rightTrackStart, highlightStart, highlightEnd].forEach { animation in
            animation.duration = duration
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            animation.timingFunction = CAMediaTimingFunction(name: animationCurve)
            animation.keyTimes = [0.0, 1.0] // We'lll overwrite this if necessary
        }
        
        
        // We're not crossing over the center then get a simple animation done now and exit
        if !isLeftToRight && !isRightToLeft {
            // Animation beginning on the left to somewhere new on the left
            if to == 0.5 {
                
                if from > 0.5 {
                    highlightStart.values = [0.5, 0.5]
                    highlightEnd.values = [from, 0.5]
                    leftTrackEnd.values = [from, to - indicatorGapOffset]
                    rightTrackStart.values = [from + indicatorGapOffset, to + indicatorGapOffset]
                } else {
                    highlightStart.values = [from, 0.5]
                    highlightEnd.values = [0.5, 0.5]
                    leftTrackEnd.values = [from - indicatorGapOffset, to - indicatorGapOffset]
                    rightTrackStart.values = [from, to + indicatorGapOffset]
                }
            } else if to < 0.5 {
                leftTrackEnd.values = [from - indicatorGapOffset, to - indicatorGapOffset]
                rightTrackStart.values = [from, to]
                highlightStart.values = [from, to]
                highlightEnd.values = [0.5, 0.5]
            }
            // Animation beginning on the right to somewhere new on the right
            else {
                leftTrackEnd.values = [from, to]
                rightTrackStart.values = [from + indicatorGapOffset, to + indicatorGapOffset]

                highlightStart.values = [0.5, 0.5]
                highlightEnd.values = [from, to]
            }
        } else if isLeftToRight {
            let keyTimes = calculateKeyTimes(from: from, to: to, duration: duration)
            [leftTrackEnd, rightTrackStart, highlightStart, highlightEnd].forEach {
                $0.keyTimes = keyTimes
            }
            // The left track should maintain a gap from the start, and to the center, but close the gap to finish
            leftTrackEnd.values = [from - indicatorGapOffset, 0.5 - indicatorGapOffset, to]
            
            // The right track should have no gap from the start, but gap when centered, and then remain gapped at the finish
            rightTrackStart.values = [from, 0.5 + indicatorGapOffset, to + indicatorGapOffset]
            
            highlightStart.values = [from, 0.5, 0.5]
            highlightEnd.values = [0.5, 0.5, to]
        } else if isRightToLeft {
            let keyTimes = calculateKeyTimes(from: from, to: to, duration: duration)
            [leftTrackEnd, rightTrackStart, highlightStart, highlightEnd].forEach {
                $0.keyTimes = keyTimes
            }
            
            leftTrackEnd.values = [from, 0.5 - indicatorGapOffset, to - indicatorGapOffset]
            
            // The right track should have no gap from the start, but gap when centered, and then remain gapped at the finish
            rightTrackStart.values = [from + indicatorGapOffset, 0.5 + indicatorGapOffset, to]
            
            highlightStart.values = [0.5, 0.5, to]
            highlightEnd.values = [from, 0.5, 0.5]
        }
        
        
        potentiometerLayer.add(leftTrackEnd, forKey: "strokeEnd")
        rightwardPotentiometerLayer.add(rightTrackStart, forKey: "strokeStart")
        potentiometerHighlightLayer.add(highlightStart, forKey: "strokeStart")
        potentiometerHighlightLayer.add(highlightEnd, forKey: "strokeEnd")
    }
    
    private func calculateKeyTimes(from: CGFloat, to: CGFloat, duration: CGFloat) -> [NSNumber] {
        let totalDistance = abs(from - to)
        let fromDistanceToCenter = abs(0.5 - from)
        let toDistanceToCenter = abs(0.5 - to)
        let fromDistancePercentage = fromDistanceToCenter / totalDistance
        let toDistancePercentage = toDistanceToCenter / totalDistance
        let middleKeyTime = fromDistanceToCenter > toDistanceToCenter ? max(fromDistancePercentage, toDistancePercentage) : min(fromDistancePercentage, toDistancePercentage)
        let nsNumber = NSNumber(value: middleKeyTime)
        let keyTimes: [NSNumber] = [0.0, nsNumber, 1.0]
        return keyTimes
    }
}
#endif

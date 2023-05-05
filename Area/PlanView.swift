//
//
// PlanView.swift
// Area
//
// Created by sinezeleuny on 20.04.2023
//
        

import UIKit

class PlanView: UIView {
    
    // MARK: - Appearance constants
    
    // Color scheme
    var darkModeOn: Bool = true
    
    private var customBackgroundColor: UIColor = .systemBackground
    private var lineColor: UIColor = .label
    private var gridLineColor: UIColor = .tertiarySystemGroupedBackground
    
    private func switchDarkModeOff() {
        customBackgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        lineColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        gridLineColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
    }
    
    // Line properties
    let gridMinorLineAlpha = 0.2
    
    let const = 2.6
    let divider: CGFloat = 5
    let trackBorderOffsetPercent: Double = 0.1
    
    // Sizes
    let lineWidth: CGFloat = 2
    let gridLineWidth: CGFloat = 2
    
    private var scale: CGFloat = 0
    
    private var summVector: CGVector = CGVector(dx: 0, dy: 0)
    
    // MARK: - General parameters
    
    var area: Double = 0
    var unitsName: String = "m²"
    
    var points: [CGVector] = [] {
        didSet {
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    // MARK: - UI
    var label: UILabel = UILabel()
    
    // MARK: Supporting functions
    
    func resetPlan() {
        scale = 0
    }
    
    private func setupLabel() {
        label.attributedText = NSAttributedString(string: "\(round(1000 * area) / 1000)" + " \(unitsName)")
        if !(self.subviews.contains(label)) {
            self.addSubview(label)
        }
        label.textColor = lineColor
        
        label.sizeToFit()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }
    
    private func calculateSummVector() -> CGVector {
        var dx: Double = 0
        var dy: Double = 0
        if let firstPoint = points.first {
            for point in points {
                dx += point.dx
                dy += point.dy
                dx -= Double(firstPoint.dx)
                dy -= Double(firstPoint.dy)
            }
            dx /= Double(points.count)
            dy /= Double(points.count)
        } else {
            return CGVector.zero
        }
        
        let vector = CGVector(dx: dx, dy: dy)
        print(vector)
        return vector
    }
    
    // MARK: - Draw
    override func draw(_ rect: CGRect) {
        
        if !darkModeOn {
            switchDarkModeOff()
        }
        
        // label
        setupLabel()
        
        // this vector is used to place the plan track in center
        summVector = calculateSummVector()
        
        // background
        let path = UIBezierPath(rect: rect)
        customBackgroundColor.setFill()
        path.fill()
        
        // TODO: drawing grid
        drawGrid(rect)
        
        // MARK: drawing plan track
        drawTrack(rect)
    }
    
    private func drawTrack(_ rect: CGRect) {
        
        let radius = min(rect.width, rect.height)
        var meter = (radius / const) / (1 + scale)
        var centeringVector = CGVector(dx: -meter * summVector.dx + rect.midX, dy: -meter * summVector.dy + rect.midY)
        
        // making path
        let path = UIBezierPath()
        
        var firstPoint: CGVector? = nil
        for point in points {
            
            if firstPoint == nil {
                firstPoint = point
                print("firstPoint", firstPoint!)
                var firstCGPoint = CGPoint(x: centeringVector.dx, y: centeringVector.dy)
                while checkIf(point: firstCGPoint, isNotInside: rect, withOffsetPercent: trackBorderOffsetPercent) {
                    scale += 0.01
                    meter = (radius / const) / (1 + scale)
                    centeringVector = CGVector(dx: -meter * summVector.dx + rect.midX, dy: -meter * summVector.dy + rect.midY)
                    firstCGPoint = CGPoint(x: centeringVector.dx, y: centeringVector.dy)
                }
                path.move(to: firstCGPoint)
            } else {
                var cgpoint = calculateCGPoint(point: point, rect, scale: scale, firstPoint: firstPoint!)

                while checkIf(point: cgpoint, isNotInside: rect, withOffsetPercent: trackBorderOffsetPercent) {
                    scale += 0.01
                    cgpoint = calculateCGPoint(point: point, rect, scale: scale, firstPoint: firstPoint!)
                    print("scale change", scale, cgpoint.x, cgpoint.y)
                }
            }
            
        }
        for point in points {
            if point != firstPoint {
                let cgpoint = calculateCGPoint(point: point, rect, scale: scale, firstPoint: firstPoint!)
                path.addLine(to: cgpoint)
            }
            
        }
        if points.count >= 3 {
            path.addLine(to: CGPoint(x: centeringVector.dx + meter * (-firstPoint!.dx + points.first!.dx), y: centeringVector.dy + meter * (-firstPoint!.dy + points.first!.dy)))
        }
        
        // drawing
        lineColor.setStroke()
        path.stroke()
        
    }
    
    private func checkIf(point: CGPoint, isNotInside rect: CGRect, withOffsetPercent percent: Double) -> Bool {
        if point.x <= rect.width * percent {
            return true
        }
        if point.x >= rect.width - rect.width * percent {
            return true
        }
        if point.y <= rect.height * percent {
            return true
        }
        if point.y >= rect.height - rect.height * percent {
            return true
        }
        return false
    }
    
    private func calculateCGPoint(point: CGVector, _ rect: CGRect, scale: CGFloat, firstPoint: CGVector) -> CGPoint {
        let radius = min(rect.width, rect.height)
        let meter = (radius / const) / (1 + scale)
        let centeringVector = CGVector(dx: -meter * summVector.dx + rect.midX, dy: -meter * summVector.dy + rect.midY)
        let cgpoint = CGPoint(x: centeringVector.dx + meter * (-firstPoint.dx + point.dx), y: centeringVector.dy + meter * (-firstPoint.dy + point.dy))
        return cgpoint
    }
    
    private func drawGrid(_ rect: CGRect) {
        let radius = min(rect.width, rect.height)
        let meter = (radius / const) / (1 + scale)
        let gridOffset = CGVector(dx: meter * summVector.dx, dy: meter * summVector.dy)
        
        let minorPath = UIBezierPath()
        let majorPath = UIBezierPath()
        
        // major vertical lines
        var cx: CGFloat = 0

        repeat {
            majorPath.move(to: CGPoint(x: rect.midX - gridOffset.dx - cx, y: 0))
            majorPath.addLine(to: CGPoint(x: rect.midX - gridOffset.dx - cx, y: rect.maxY))
            
            majorPath.move(to: CGPoint(x: rect.midX - gridOffset.dx + cx, y: 0))
            majorPath.addLine(to: CGPoint(x: rect.midX - gridOffset.dx + cx, y: rect.maxX))
            
            cx = cx + meter
        } while cx < rect.midX + abs(gridOffset.dx)
        
        gridLineColor.setStroke()
        majorPath.stroke()
        
        // minor vertical lines
        cx = 0
        repeat {
            minorPath.move(to: CGPoint(x: rect.midX - gridOffset.dx - cx, y: 0))
            minorPath.addLine(to: CGPoint(x: rect.midX - gridOffset.dx - cx, y: rect.maxY))

            minorPath.move(to: CGPoint(x: rect.midX - gridOffset.dx + cx, y: 0))
            minorPath.addLine(to: CGPoint(x: rect.midX - gridOffset.dx + cx, y: rect.maxX))
            
            cx = cx + meter / divider
        } while cx < rect.midX + abs(gridOffset.dx)

        gridLineColor.withAlphaComponent(gridMinorLineAlpha).setStroke()
        minorPath.stroke()
        
        // major horizontal lines
        var cy: CGFloat = 0
        
        repeat {
            majorPath.move(to: CGPoint(x: 0, y: rect.midY - gridOffset.dy - cy))
            majorPath.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - gridOffset.dy - cy))
            
            majorPath.move(to: CGPoint(x: 0, y: rect.midY - gridOffset.dy + cy))
            majorPath.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - gridOffset.dy + cy))
            
            cy = cy + meter
        } while cy < rect.midY + abs(gridOffset.dy)

        gridLineColor.setStroke()
        majorPath.stroke()
        
        // minor horizontal lines
        cy = 0
        repeat {
            minorPath.move(to: CGPoint(x: 0, y: rect.midY - gridOffset.dy - cy))
            minorPath.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - gridOffset.dy - cy))
            
            minorPath.move(to: CGPoint(x: 0, y: rect.midY - gridOffset.dy + cy))
            minorPath.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - gridOffset.dy + cy))
            
            cy = cy + meter / divider
        } while cy < rect.midY + abs(gridOffset.dy)
        
        gridLineColor.withAlphaComponent(gridMinorLineAlpha).setStroke()
        minorPath.stroke()
        
    }
}


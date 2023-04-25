//
//  ViewController.swift
//  Area
//
//  Created by sinezeleuny on 21.02.2022.
//

import UIKit
import ARKit

class ArVC: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    // MARK: Outlets
    @IBOutlet weak var arView: ARSCNView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var infoView: UIVisualEffectView!

    @IBOutlet weak var planView: PlanView!
    var planViewCornerRadius: CGFloat = 10
    private func setupPlanView() {
        planView.layer.cornerRadius = planViewCornerRadius
        planView.clipsToBounds = true
    }
    private func updatePlanView(with objects: [SCNNode]) {
        planView.points = []
        planView.area = area
        for object in objects {
            planView.points.append(CGVector(
                dx: Double(object.position.x),
                dy: Double(object.position.z)
            ))
        }
    }
    
    @IBOutlet weak var restartButton: UIButton!
    @IBAction func restartScene(_ sender: UIButton) {
//        resetTracking()
        for node in objects {
            node.removeFromParentNode()
        }
        for node in arView.scene.rootNode.childNodes {
            if node.name == "polygon" {
                node.removeFromParentNode()
            }
        }
        previousObjects = []
        objects = []
        area = 0.0
        infoLabel.text = firstMessage
        planView.resetPlan()
    }
    
    // MARK: Funcs and vars
    var objects = [PointNode]() {
        didSet {
            print("objects set", objects)
            updatePlanView(with: objects)
        }
    } //{
//        didSet {
//            print(objects.last?.position ?? "")
//        }
//    }
    var previousObjects = [PointNode]()
    
    let coachingOverlay = ARCoachingOverlayView()
    let firstMessage = "Tap on screen to place an object"
    let secondMessage = "Tap on screen to place second one"
    let thirdMessage = "Tap on screen to place third one. You need one more object to start"
    let errorMessage = "Did not find plane to place an object. Please, try again"
    
    var area: Double = 0 {
        didSet {
            print("area set", area)
            updatePlanView(with: objects)
        }
    }
    
    func sortObjects() {
        
        // calculating a point inside the polygon
        var x: Double = 0
        var y: Double = 0
        var z: Double = 0
        for object in objects {
            x += Double(object.position.x)
            y += Double(object.position.y)
            z += Double(object.position.z)
        }
        x /= Double(objects.count)
        y /= Double(objects.count)
        z /= Double(objects.count)
        let averagePoint = SCNVector3(x, y, z)
        
        var firstQuadrant: [PointNode] = []
        var secondQuadrant: [PointNode] = []
        var thirdQuadrant: [PointNode] = []
        var fourthQuadrant: [PointNode] = []
        
        // getting tangents
        for object in objects {
            let vector = averagePoint.subtractedFrom(object.position)
            let tan = -vector.z / vector.x
            object.polygonTangent = Double(tan)
            
            if vector.x >= 0 && vector.z < 0 {
                firstQuadrant.append(object)
            }
            if vector.x < 0 && vector.z < 0 {
                secondQuadrant.append(object)
            }
            if vector.x < 0 && vector.z >= 0 {
                thirdQuadrant.append(object)
            }
            if vector.x >= 0 && vector.z >= 0 {
                fourthQuadrant.append(object)
            }
        }
        
        // sorting
        firstQuadrant.sort(by: { $0.polygonTangent < $1.polygonTangent })
        secondQuadrant.sort(by: { $0.polygonTangent < $1.polygonTangent })
        thirdQuadrant.sort(by: { $0.polygonTangent < $1.polygonTangent })
        fourthQuadrant.sort(by: { $0.polygonTangent < $1.polygonTangent })
        
//        previousObjects = objects
        objects = firstQuadrant + secondQuadrant + thirdQuadrant + fourthQuadrant
        
        let indices = previousObjects.map({ $0.index })
        print("indices", indices)
        if objects.count > 3 {
            for object in objects {
                print("object.index", object.index)
                if !indices.contains(object.index) {
                    if let indexInArray = objects.firstIndex(of: object) {
                        var leftNeighbourIndex = 0
                        var rightNeighbourIndex = 0
                        if indexInArray == 0 {
                            leftNeighbourIndex = objects.last!.index
                            rightNeighbourIndex = objects[1].index
                        } else if indexInArray == objects.count - 1 {
                            leftNeighbourIndex = objects[objects.count - 2].index
                            rightNeighbourIndex = objects.first!.index
                        } else {
                            leftNeighbourIndex = objects[indexInArray - 1].index
                            rightNeighbourIndex = objects[indexInArray + 1].index
                        }
                        
                        for previousObject in previousObjects {
                            if previousObject.index == leftNeighbourIndex {
                                let placeIndex = previousObjects.firstIndex(of: previousObject)! + 1
                                previousObjects.insert(object, at: placeIndex)
                                objects = previousObjects
                            }
                        }
                        
                    }
                    
//                    if indexInArray == 0 {
//                        print("edit first!")
//                        objects = [object] + previousObjects
//                    } else if indexInArray == objects.count - 1 {
//                        print("edit last!")
//                        objects = previousObjects + [object]
//                    }
                }
            }
        }
        print(objects.map({ $0.index }))
    }
    
    func calculateArea(_ array: [SCNNode]) -> Double {
        
        var a = Float(0.0)
        var b = Float(0.0)
        for object in array {
            let i = array.firstIndex(of: object)! + 1
            if i != array.count {
                a += array[i-1].position.x * -array[i].position.z
                b -= array[i].position.x * -array[i-1].position.z
            }
        }
        let c = array.last!.position.x * -array.first!.position.z - array.first!.position.x * -array.last!.position.z
        let d = a + b + c
        let s = Double(1/2 * abs(d))
        return s
    }
    
    // MARK: Add Object function
    
    @objc func addObject(sender: UITapGestureRecognizer?) {
        var location = CGPoint()
        if let sender = sender {
            location = sender.location(in: view)
        } else {
            location = CGPoint(x: arView.frame.width / 2, y: arView.frame.height / 2)
        }
        let hitTest = arView.hitTest(location, types: .existingPlaneUsingExtent)
        
        if hitTest.isEmpty {
            print("No plane detected")
            let previousMessage = infoLabel.text
            infoLabel.text = errorMessage
            if objects.count > 2 {
                Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false, block: {[weak self] _ in self?.infoLabel.text = previousMessage})
            }
            
            return
        } else {
            let node = PointNode()
            let columns = hitTest.first?.worldTransform.columns.3
            node.position = SCNVector3(x: columns!.x, y: columns!.y, z: columns!.z)
            let k = objects.count + 1
            node.index = k
//            node.name = "\(k)"
            previousObjects = objects
            objects.append(node)
            
            if objects.count == 1 {
                infoLabel.text = secondMessage
            } else if objects.count == 2 {
                infoLabel.text = thirdMessage
            } else if objects.count > 2 {
                sortObjects()
                updatePlanView(with: objects)
                area = calculateArea(objects)
                drawPolygon()
                infoLabel.text = "Area: \(String(format: "%.3f", area)) m²"
            }
            arView.scene.rootNode.addChildNode(node)
        }
    }
    
    func drawPolygon() {
        func generateIndices(max maxIndexValue: Int) -> [Int32] {
            var counter: Int = 0
            var output: [Int32] = []
            while counter < maxIndexValue {
                output.append(Int32(counter))
                counter += 1
            }
            return output
        }
        var indices: [Int32] = [Int32(objects.count)]
        indices.append(contentsOf: generateIndices(max: objects.count))
//        print("Indices: ", indices)
        
        var positions = objects.map({$0.position})
        let yCoordinate: Double
        if let firstPos = positions.first {
            yCoordinate = Double(firstPos.y)
            
            for pos in positions {
                if let i = positions.firstIndex(of: pos) {
                    positions[i] = SCNVector3(x: pos.x, y: Float(yCoordinate), z: pos.z)
                }
            }
        }
        
        let vertexSource = SCNGeometrySource(vertices: positions)
        
        let indexData = Data(bytes: indices,
                             count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .polygon,
                                         primitiveCount: 1,
                                         bytesPerIndex: MemoryLayout<Int32>.size)
        let polygonGeometry = SCNGeometry(sources: [vertexSource], elements: [element])
        polygonGeometry.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.7)
        
        for node in arView.scene.rootNode.childNodes {
            if node.name == "polygon" {
                node.removeFromParentNode()
            }
        }
        
        let polygon = SCNNode(geometry: polygonGeometry)
        polygon.name = "polygon"
        arView.scene.rootNode.addChildNode(polygon)
    }
    
    // MARK: VCLC
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView.delegate = self
        arView.session.delegate = self
        setupCoachingOverlay()
        setupPlanView()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(addObject))
        arView.addGestureRecognizer(tap)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        restartButton.layer.cornerRadius = 6.0
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration)
        arView.autoenablesDefaultLighting = true
        
        UIApplication.shared.isIdleTimerDisabled = true
        infoLabel.text = firstMessage
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    
        arView.session.pause()
    }

//    func sessionInterruptionEnded(_ session: ARSession) {
//        // Reset tracking and/or remove existing anchors if consistent tracking is required.
////        sessionInfoLabel.text = "Session interruption ended"
//        resetTracking()
//    }

    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
}

// MARK: - Extensions

extension ArVC: ARCoachingOverlayViewDelegate {
    
    /// - Tag: HideUI
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
//        aimView.isHidden = true
        infoView.isHidden = true
        infoLabel.isHidden = true
        restartButton.isHidden = true
        planView.isHidden = true
    }
    
    /// - Tag: PresentUI
    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
//        aimView.isHidden = false
        infoView.isHidden = false
        infoLabel.isHidden = false
        restartButton.isHidden = false
        planView.isHidden = false
    }

    /// - Tag: StartOver
    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        
    }

    func setupCoachingOverlay() {
        coachingOverlay.session = arView.session
        coachingOverlay.delegate = self
        
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)
        
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
            ])
        
        setActivatesAutomatically()
        setGoal()
    }
    
    /// - Tag: CoachingActivatesAutomatically
    func setActivatesAutomatically() {
        coachingOverlay.activatesAutomatically = true
    }

    /// - Tag: CoachingGoal
    func setGoal() {
        coachingOverlay.goal = .horizontalPlane
    }
}

extension SCNVector3: Equatable {
    public static func == (lhs: SCNVector3, rhs: SCNVector3) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
    
    func length() -> CGFloat {
        return CGFloat(sqrt(self.x * self.x + self.y * self.y + self.z * self.z))
    }
    
    func addedTo(_ vector: SCNVector3) -> SCNVector3 {
        return SCNVector3(x: self.x + vector.x, y: self.y + vector.y, z: self.z + vector.z)
    }
    
    func subtractedFrom(_ vector: SCNVector3) -> SCNVector3 {
        return SCNVector3(x: -self.x + vector.x, y: -self.y + vector.y, z: -self.z + vector.z)
    }
    
    func multipliedBy(_ number: Float) -> SCNVector3 {
        return SCNVector3(x: number * self.x , y: number * self.y, z: number * self.z )
    }
    
    func scalarWith(_ vector: SCNVector3) -> CGFloat {
        return CGFloat(self.x * vector.x + self.y * vector.y + self.z * vector.z)
    }
    
}

//
//  ViewController.swift
//  CoreML Demo
//
//  Created by Shuji Chen on 2019-10-28.
//  Copyright © 2019 Shuji Chen. All rights reserved.
//

/*
Demo Example coreML codes are reference from
https://medium.com/s23nyc-tech/using-machine-learning-and-coreml-to-control-arkit-24241c894e3b
 
 &
 
https://github.com/hanleyweng/Gesture-Recognition-101-CoreML-ARKit
*/


import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate{

    @IBOutlet var ARCanvas: ARSCNView!
    var droneNode = SCNNode()
    
    let currentMLModel = otherHandGesture().model
    
    private let serialQueue = DispatchQueue(label: "com.aboveground.dispatchqueueml")
    private var visionRequests = [VNRequest]()
    private var timer = Timer()
    // MARK: 1. initialize our CoreML model and set up the callback function for our classification requests.
    private func setupCoreML() {
        guard let selectedModel = try? VNCoreMLModel(for: currentMLModel) else {
            fatalError("Could not load model.")
        }
        
        let classificationRequest = VNCoreMLRequest(model: selectedModel,
                                                    completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]
    }
    
    // MARK: 3. Loops the CoreML Update
    @objc private func loopCoreMLUpdate() {
        serialQueue.async {
            self.updateCoreML()
        }
    }
    
    // MARK: ViewController functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        ARCanvas.delegate = self
        // Show statistics such as fps and timing information
        ARCanvas.showsStatistics = true
        
        loadShipModel()
        setupCoreML()

        //MARK: 5. A timer for calling the loopCoreMLUpdate function
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.loopCoreMLUpdate), userInfo: nil, repeats: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        ARCanvas.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        ARCanvas.session.pause()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
         // Present an error message to the user
         
     }
     
     func sessionWasInterrupted(_ session: ARSession) {
         // Inform the user that the session has been interrupted, for example, by presenting an overlay
         
     }
     
     func sessionInterruptionEnded(_ session: ARSession) {
         // Reset tracking and/or remove existing anchors if consistent tracking is required
         
     }
    // MARK: Animations & Models
    // creates a drone model
    func loadShipModel()
    {
        // Load the drone model from the collada file
        let droneScene = SCNScene(named: "art.scnassets/Drone.dae")!
        
        // Add all the child nodes to the parent node
        for child in droneScene.rootNode.childNodes
        {
            droneNode.addChildNode(child)
        }
        droneNode.position = SCNVector3(CGFloat(0), CGFloat(0), CGFloat(-1.5))
        //size of the drone model
        droneNode.scale = SCNVector3(0.5, 0.5, 0.5)
        ARCanvas.scene.rootNode.addChildNode(droneNode)
    }
    
    // MARK: Drone Movements
    func flyForward() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1
        droneNode.position = SCNVector3(droneNode.position.x, droneNode.position.y, droneNode.position.z-0.2)
        SCNTransaction.commit()
    }
    
    func flyBackward() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1
        droneNode.position = SCNVector3(droneNode.position.x, droneNode.position.y, droneNode.position.z+0.2)
        SCNTransaction.commit()
    }
    
}
// MARK: 2. Update CoreML Extension
//take in the current camera frame and pass it off to Vision to make the perform the CoreML classification.
extension ViewController {
    private func updateCoreML() {
        let pixbuff : CVPixelBuffer? = (ARCanvas.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        
        let deviceOrientation = UIDevice.current.orientation.getImagePropertyOrientation()
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixbuff!, orientation: deviceOrientation,options: [:])
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
        
    }
}

// MARK: 4. Handling device orientation
extension UIDeviceOrientation {
    func getImagePropertyOrientation() -> CGImagePropertyOrientation {
        switch self {
        case UIDeviceOrientation.portrait, .faceUp: return CGImagePropertyOrientation.right
        case UIDeviceOrientation.portraitUpsideDown, .faceDown: return CGImagePropertyOrientation.left
        case UIDeviceOrientation.landscapeLeft: return CGImagePropertyOrientation.up
        case UIDeviceOrientation.landscapeRight: return CGImagePropertyOrientation.down
        case UIDeviceOrientation.unknown: return CGImagePropertyOrientation.right
        @unknown default:
            fatalError()
        }
    }
}


// MARK: Where the magic happens
extension ViewController {
    private func classificationCompleteHandler(request: VNRequest, error: Error?) {
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            return
        }
        
        let classifications = observations[0...2]
            .compactMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        print("Classifications: \(classifications)")
        
        DispatchQueue.main.async {
            let topPrediction = classifications.components(separatedBy: "\n")[0]
            let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
            guard let topPredictionScore: Float = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces)) else { return }
            
            
            /* Do something when the prediction threshold surpasses a
             certain percentage */
            if (topPredictionScore > 0.10) {
                if (topPredictionName == "fist-UB-RHand") { self.flyBackward() }
                if (topPredictionName == "FIVE-UB-RHand") {  self.flyForward()}
            }
        }
    }
}






//
//  ViewController.swift
//  ARPharmaDemo
//
//  Created by Forrest on 7/12/17.
//  Copyright © 2017 Forrest. All rights reserved.
//  Heavily influenced by https://github.com/hollisliu/iOS-Vision-Text-Detection-Demo

import UIKit
import AVFoundation
import Vision
import CoreMedia

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let coreModel = Inceptionv3()
    private var requests = [VNRequest]()
    private let session = AVCaptureSession()
    
    @IBOutlet weak var cameraPreviewView: UIView!
    @IBOutlet weak var predictionLabel: UILabel!
    @IBOutlet weak var probabilityLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startCamera()
        
        startVision()
        //startCoreML()
        
        
        
        
        
    }

    //  Camera

    func startCamera() {
        let cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        let input = try? AVCaptureDeviceInput(device: backCamera!)
        let output = AVCaptureVideoDataOutput()
        
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: NSNumber(value: kCVPixelFormatType_32BGRA)]
        //output.alwaysDiscardsLateVideoFrames = true

        output.setSampleBufferDelegate(
            self, 
            queue: DispatchQueue(
                label: "buffer queue", 
                qos: .userInteractive, 
                attributes: .concurrent, 
                autoreleaseFrequency: .inherit, 
                target: nil
            )
        )
        session.addOutput(output)
        session.addInput(input!)
        

        cameraPreviewLayer.frame = cameraPreviewView.bounds
        cameraPreviewView.layer.addSublayer(cameraPreviewLayer)

        session.startRunning()
    }
    
    
    //  Original Output image buffer handler. Need to refactor.
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("capturingOutput")
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("unable to retrieve image buffer")
            return
        }
        
        var requestOptions:[VNImageOption : Any] = [:]
        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics:camData]
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: 6, options: requestOptions)
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
        
        //CoreML prediction
        do {
            //  Apparently coreML image analysis requires resizing of image.
            let prediction = try self.coreModel.prediction(image: self.resize(pixelBuffer: pixelBuffer)!)
            DispatchQueue.main.async {
                if let probability = prediction.classLabelProbs[prediction.classLabel] {
                    //self.predictionLabel.text = "\(prediction.classLabel) \(String(describing: probability))"
                    self.predictionLabel.text = "\(prediction.classLabel)"
                    self.probabilityLabel.text = "\(String(describing: probability * 100))"
                    //print("\(prediction.classLabel) \(String(describing: probability))")
                }
            }
        }
        catch {
            print(error.localizedDescription)
        }
        
        
    }
    
    
    //  Core ML
    
    func startCoreML() {
        print("CoreML Analysis Started")
        guard let visionModel = try? VNCoreMLModel(for: coreModel.model) else {
            fatalError("can't load Vision ML model")
        }
        let analysisRequest = VNCoreMLRequest(model: visionModel, completionHandler: modelDetectionHandler)
        /*
        let analysisRequest = VNCoreMLRequest(model: visionModel) { (request: VNRequest, error: Error?) in
            guard let observations = request.results else {
                print("no results:\(error!)")
                return
            }
         
            let classifications = observations[0...4]
                .flatMap({ $0 as? VNClassificationObservation })
                .filter({ $0.confidence > 0.2 })
                .map({ "\($0.identifier) \($0.confidence)" })
            DispatchQueue.main.async {
                self.predictionLabel.text = classifications.joined(separator: "\n")
            }
        }
        */
        //let analysisRequest = VNDetectRectanglesRequest(completionHandler: self.modelDetectionHandler)
        //analysisRequest.minimumConfidence = 0.3
        
        analysisRequest.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop
        
        self.requests = [analysisRequest]
    }
    
    func modelDetectionHandler(request: VNRequest, error: Error?) {
        print("CoreML handler detection Analysis Started")
        
        
        guard let observations = request.results else {
            print("no result")
            return
        }
        
        let classifications = observations[0...4]
            .flatMap({ $0 as? VNClassificationObservation })
            .filter({ $0.confidence > 0.2 })
            .map({ "\($0.identifier) \($0.confidence)" })
        
        let result = observations
            .map({ $0 as? VNDetectedObjectObservation })
        
        DispatchQueue.main.async() {
            self.predictionLabel.text = classifications.joined(separator: "\n")
            self.cameraPreviewView.layer.sublayers?.removeSubrange(1...)
            for request in result {
                guard let rg = request else {continue}
                self.drawObjectBox(box: rg)
            }
            
        }
        
    }
    
    func resize(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let imageSide = 299
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer, options: nil)
        let transform = CGAffineTransform(scaleX: CGFloat(imageSide) / CGFloat(CVPixelBufferGetWidth(pixelBuffer)), y: CGFloat(imageSide) / CGFloat(CVPixelBufferGetHeight(pixelBuffer)))
        ciImage = ciImage.applying(transform).cropping(to: CGRect(x: 0, y: 0, width: imageSide, height: imageSide))
        let ciContext = CIContext()
        var resizeBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, imageSide, imageSide, CVPixelBufferGetPixelFormatType(pixelBuffer), nil, &resizeBuffer)
        ciContext.render(ciImage, to: resizeBuffer!)
        return resizeBuffer
    }

    //  Vision

    func startVision() {
        print("Vision Started")
        let textRequest = VNDetectTextRectanglesRequest(completionHandler: self.textDetectionHandler)
        textRequest.reportCharacterBoxes = true
        self.requests = [textRequest]
    }

    func textDetectionHandler(request: VNRequest, error: Error?) {
        print("text detection handler  Started")

        guard let observations = request.results else {print("no result"); return}
        
        let result = observations.map({$0 as? VNTextObservation})
        
        DispatchQueue.main.async() {
            self.cameraPreviewView.layer.sublayers?.removeSubrange(1...)
            for region in result {
                guard let rg = region else {continue}
                self.drawRegionBox(box: rg)
                if let boxes = region?.characterBoxes {
                    for charBox in boxes {
                        self.drawCharBox(box: charBox)
                    }
                }
            }
        }
    }

    //  Draw Text Boxes
    
    func drawCharBox(box: VNRectangleObservation) {
        let xCoord = box.topLeft.x * cameraPreviewView.frame.size.width
        let yCoord = (1 - box.topLeft.y) * cameraPreviewView.frame.size.height
        let width = (box.topRight.x - box.bottomLeft.x) * cameraPreviewView.frame.size.width
        let height = (box.topLeft.y - box.bottomLeft.y) * cameraPreviewView.frame.size.height
        
        let layer = CALayer()
        layer.frame = CGRect(x: xCoord, y: yCoord, width: width, height: height)
        layer.borderWidth = 0.0
        layer.borderColor = UIColor.red.cgColor
        
        cameraPreviewView.layer.addSublayer(layer)
    }
    
    func drawRegionBox(box: VNTextObservation) {
        guard let boxes = box.characterBoxes else {return}
        var xMin: CGFloat = 9999.0
        var xMax: CGFloat = 0.0
        var yMin: CGFloat = 9999.0
        var yMax: CGFloat = 0.0
        
        for char in boxes {
            if char.bottomLeft.x < xMin {xMin = char.bottomLeft.x}
            if char.bottomRight.x > xMax {xMax = char.bottomRight.x}
            if char.bottomRight.y < yMin {yMin = char.bottomRight.y}
            if char.topRight.y > yMax {yMax = char.topRight.y}
        }
        
        let xCoord = xMin * cameraPreviewView.frame.size.width
        let yCoord = (1 - yMax) * cameraPreviewView.frame.size.height
        let width = (xMax - xMin) * cameraPreviewView.frame.size.width
        let height = (yMax - yMin) * cameraPreviewView.frame.size.height
        
        let layer = CALayer()
        layer.frame = CGRect(x: xCoord, y: yCoord, width: width, height: height)
        layer.borderWidth = 2.0
        layer.borderColor = UIColor.green.cgColor
        
        cameraPreviewView.layer.addSublayer(layer)
    }
    
    func drawObjectBox(box: VNDetectedObjectObservation) {
        print("draw object box request")
        let boxes = box.boundingBox
        
        let size = CGSize(width: boxes.width * cameraPreviewView.bounds.width,
                          height: boxes.height * cameraPreviewView.bounds.height)
        let origin = CGPoint(x: boxes.minX * cameraPreviewView.bounds.width,
                             y: (1 - boxes.minY) * cameraPreviewView.bounds.height - size.height)
        /*
        let xCoord = xMin * cameraPreviewView.frame.size.width
        let yCoord = (1 - yMax) * cameraPreviewView.frame.size.height
        let width = (xMax - xMin) * cameraPreviewView.frame.size.width
        let height = (yMax - yMin) * cameraPreviewView.frame.size.height
 */
        
        let layer = CALayer()
        layer.frame = CGRect(origin: origin, size: size)
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.red.cgColor
        
        cameraPreviewView.layer.addSublayer(layer)
    }
    
}

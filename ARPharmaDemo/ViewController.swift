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

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private var requests = [VNRequest]()
    private let session = AVCaptureSession()

    @IBOutlet weak var cameraPreviewView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
        startVision()
        startCamera()
        
    }

    //  Camera

    func startCamera() {
        let cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

        let input = try? AVCaptureDeviceInput(device: backCamera!)
        let output = AVCaptureVideoDataOutput()

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

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
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
    }

    //  Vision

    func startVision() {
        let textRequest = VNDetectTextRectanglesRequest(completionHandler: self.textDetectionHandler)
        textRequest.reportCharacterBoxes = true
        self.requests = [textRequest]
    }

    func textDetectionHandler(request: VNRequest, error: Error?) {

        guard let observations = request.results else {print("no result"); return}
        
        let result = observations.map({$0 as? VNTextObservation})
        
        DispatchQueue.main.async() {
            self.cameraPreviewView.layer.sublayers?.removeSubrange(1...)
            for region in result {
                guard let rg = region else {continue}
                self.drawRegionBox(box: rg)
            }
        }
    }

    //  Draw Text Box

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
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.green.cgColor
        
        cameraPreviewView.layer.addSublayer(layer)
    }

}

//
//  ViewController.swift
//  ARPharmaDemo
//
//  Created by Forrest on 7/12/17.
//  Copyright © 2017 Forrest. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.addSublayer(cameraLayer)
        
        let output = AVCaptureVideoDataOutput()
        
        captureSession.addOutput(output)
        captureSession.startRunning()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(false)
        cameraLayer.frame = view.bounds
    }
    
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera) else {
                return session
        }
        session.addInput(input)
        return session
    }()

}


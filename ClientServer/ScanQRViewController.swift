//
//  ScanQRViewController.swift
//  ClientServer
//
//  Created by MAC on 25/11/2023.
//

import UIKit
import AVFoundation

protocol ScanQRDelegate {
    func outputQRCode(_ value: String?)
}

class ScanQRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private var video = AVCaptureVideoPreviewLayer()
    private var isFirst = true
    
    var scanQRDelegate: ScanQRDelegate? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let session = AVCaptureSession()
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            session.addInput(input)
        } catch {
            print("Camera capture error")
        }
        
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]
        
        video = AVCaptureVideoPreviewLayer(session: session)
        video.frame = view.layer.bounds
        view.layer.addSublayer(video)
        
        session.startRunning()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if !metadataObjects.isEmpty {
            if let object = metadataObjects[0] as? AVMetadataMachineReadableCodeObject {
                if object.type == .qr && isFirst {
                    isFirst = false
                    let value = object.stringValue
                    scanQRDelegate?.outputQRCode(value)
                    self.dismiss(animated: true)

                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func closeView(_ sender: Any) {
        print("Close camera view")
        self.dismiss(animated: true)
    }
}

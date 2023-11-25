//
//  ViewController.swift
//  ClientServer
//
//  Created by MAC on 22/11/2023.
//

import UIKit
import Network
import VisionKit

class ViewController: UIViewController, ScanQRDelegate {
    @IBOutlet weak var lbAddress: UITextField!
    @IBOutlet weak var lbPort: UITextField!
    @IBOutlet weak var btConnect: UIButton!
    @IBOutlet weak var btStart: UIButton!
    @IBOutlet weak var lbStatus: UILabel!
    @IBOutlet weak var lbMessage: UILabel!
    @IBOutlet weak var btQRCode: UIButton!
    
    private var client: Client? = nil
    private var server: Server? = nil
    
    private var isStartServerSuccess = false
    private var isConnectToServerSuccess = false
    private var count = 0
    
    var scannerAvailable: Bool {
        if #available(iOS 16.0, *) {
            DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        } else {
            false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        lbMessage.numberOfLines = 1000
        lbStatus.numberOfLines = 1000
        btQRCode.setTitle("Scan", for: .normal)
     
        //Looks for single or multiple taps.
         let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))

        //Uncomment the line below if you want the tap not not interfere and cancel other interactions.
        //tap.cancelsTouchesInView = false

        view.addGestureRecognizer(tap)
    }

    @IBAction func connectToServer(_ sender: Any) {
        if (server != nil) {
            print("Stop server")
            DispatchQueue.global(qos: .background).async {
                self.server?.stop()
                DispatchQueue.main.async {
                    self.reset()
                }
            }
            return
        }
        if (client != nil) {
            print("Stop client")
            DispatchQueue.global(qos: .background).async {
                self.client?.stop()
                DispatchQueue.main.async {
                    self.reset()
                }
            }
            return
        }
        print("Connecting to server...")
        let address: String = lbAddress.text ?? ""
        let port: Int32 = Int32(lbPort.text ?? "") ?? 8080
        connectToServer(address: address, port: port)
    }
    
    @IBAction func startServer(_ sender: Any) {
        if (client != nil) {
            print("Send data from client")
            DispatchQueue.global(qos: .background).async {
                self.count += 1
                self.client?.connection.send(data: Data("From IOS client: \(self.count)".utf8))
            }
            return
        }
        if (server != nil && isStartServerSuccess) {
            print("Send data from server")
            server?.heartbeat()
            return
        }
        isStartServerSuccess = false
        print("Starting server...")
        DispatchQueue.global(qos: .background).async {
            do {
                self.server = Server(self.lbMessage)
                self.server?.onStateDidChange = { state in
                    DispatchQueue.main.async {
                        switch state {
                        case .setup:
                            break
                        case .waiting:
                            self.lbStatus.text = "Waiting start server..."
                            break
                        case .ready:
                            self.isStartServerSuccess = true
                            self.btConnect.setTitle("Stop server", for: .normal)
                            self.btStart.setTitle("Send to client", for: .normal)
                            let address = Utils.getWiFiAddress()
                            self.lbStatus.text = "Start server successful!\nAddress: \(address!), port: 8080"
                            self.btQRCode.setTitle("Open QR code", for: .normal)
                            break
                        case .failed(let error):
                            self.lbStatus.text = "Start server failed due to: \(error.localizedDescription)"
                        case .cancelled:
                            self.lbStatus.text = "Server was canceled"
                            break
                        default:
                            break
                        }
                    }
                }
                try self.server?.start()
            } catch {
                self.server = nil
                self.isStartServerSuccess = false
                DispatchQueue.main.async {
                    self.lbStatus.text = "Start server failed"
                }
            }
        }
    }
    
    @IBAction func openQRCode(_ sender: Any) {
        if (server == nil) {
            print("Open scanner")
            let scannerVController = ScanQRViewController(nibName: nil, bundle: nil)
            scannerVController.scanQRDelegate = self
            self.present(scannerVController, animated: true)
            return
        }
        print("Open QR code")
        let qrVController = QRViewController(nibName: nil, bundle: nil)
        qrVController.address = Utils.getWiFiAddress() ?? ""
        self.present(qrVController, animated: true)
    }
    
    func outputQRCode(_ value: String?) {
        guard let address = value else { return }
        connectToServer(address: address, port: 8080)
    }
    
    private func connectToServer(address: String, port: Int32) {
        self.client = Client(address, port, lbMessage: self.lbMessage)
        DispatchQueue.global(qos: .background).async {
            self.client?.connection.onConnectionStateCallback = { state in
                DispatchQueue.main.async {
                    if state == .ready {
                        self.btQRCode.isHidden = true
                        self.lbStatus.text = "Connect to server success"
                        self.btConnect.setTitle("Stop connect to server", for: .normal)
                        self.btStart.setTitle("Send to server", for: .normal)
                    } else {
                        self.reset()
                        self.lbStatus.text = "Connect to server failed"
                    }
                }
            }
            self.client?.onStopCallBack = {
                DispatchQueue.main.async {
                    self.reset()
                    self.lbStatus.text = "Server disconnect"
                }
            }
            self.client?.start()
        }
    }
    
    private func reset() {
        client = nil
        server = nil
        btConnect.setTitle("Connect to server", for: .normal)
        btStart.setTitle("Start server", for: .normal)
        lbStatus.text = "Waiting a connection..."
        lbMessage.text = ""
        self.btQRCode.isHidden = false
        self.btQRCode.setTitle("Scan", for: .normal)
    }
    
    //Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
}

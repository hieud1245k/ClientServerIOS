//
//  ViewController.swift
//  ClientServer
//
//  Created by MAC on 22/11/2023.
//

import UIKit
import Network

private var count = 0

class ViewController: UIViewController {
    @IBOutlet weak var lbAddress: UITextField!
    @IBOutlet weak var lbPort: UITextField!
    @IBOutlet weak var btConnect: UIButton!
    @IBOutlet weak var btStart: UIButton!
    @IBOutlet weak var lbStatus: UILabel!
    @IBOutlet weak var lbMessage: UILabel!

    private var client: Client? = nil
    private var server: Server? = nil
    
    
    private var isStartServerSuccess = false
    private var isConnectToServerSuccess = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        lbMessage.numberOfLines = 1000
        // Do any additional setup after loading the view.
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
            DispatchQueue.global(qos: .background).async {
                self.client?.stop()
                DispatchQueue.main.async {
                    self.reset()
                }
            }
            return
        }
        let address: String = lbAddress.text ?? ""
        let port: Int32 = Int32(lbPort.text ?? "") ?? 8080
        self.client = Client(address, port, lbMessage: self.lbMessage)
        DispatchQueue.global(qos: .background).async {
            self.client?.connection.onConnectionStateCallback = { state in
                DispatchQueue.main.async {
                    if state == .ready {
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
    
    @IBAction func startServer(_ sender: Any) {
        if (client != nil) {
            DispatchQueue.global(qos: .background).async {
                count += 1
                self.client?.connection.send(data: Data("From IOS client: \(count)".utf8))
            }
            return
        }
        if (server != nil) {
            server?.heartbeat()
            return
        }
        DispatchQueue.global(qos: .background).async {
            do {
                self.server = Server(self.lbMessage)
                try self.server?.start()
                self.isStartServerSuccess = true
                DispatchQueue.main.async {
                    self.btConnect.setTitle("Stop server", for: .normal)
                    self.btStart.setTitle("Send to client", for: .normal)
                    self.lbStatus.text = "Start server successful"
                }
            } catch {
                self.server = nil
                self.isStartServerSuccess = false
                DispatchQueue.main.async {
                    self.lbStatus.text = "Start server failed"
                }
            }
        }
    }
    
    private func reset() {
        client = nil
        server = nil
        btConnect.setTitle("Connect to server", for: .normal)
        btStart.setTitle("Start server", for: .normal)
        lbStatus.text = "Waiting a connection..."
        lbMessage.text = ""
    }
}

class Connection {

    init(nwConnection: NWConnection, lbMessage: UILabel? = nil) {
        self.nwConnection = nwConnection
        self.id = Connection.nextID
        Connection.nextID += 1
        self.lbMessage = lbMessage
    }

    private static var nextID: Int = 0

    let nwConnection: NWConnection
    let lbMessage: UILabel?
    let id: Int

    var didStopCallback: ((Error?) -> Void)? = nil
    var onConnectionStateCallback: ((NWConnection.State) -> Void) = { _ in }

    func start() {
        print("connection \(self.id) will start")
        self.nwConnection.stateUpdateHandler = self.stateDidChange(to:)
        self.setupReceive()
        self.nwConnection.start(queue: .main)
    }

    func send(data: Data) {
        self.nwConnection.send(content: data, contentContext: .defaultMessage, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            print("connection \(self.id) did send, data: \(data as NSData)")
        }))
    }

    func stop() {
        print("connection \(self.id) will stop")
        nwConnection.cancel()
    }

    private func stateDidChange(to state: NWConnection.State) {
        print("stateDidChange \(state)")
        switch state {
        case .setup:
            break
        case .waiting(let error):
            self.connectionDidFail(error: error)
        case .preparing:
            break
        case .ready:
            print("connection \(self.id) ready")
            onConnectionStateCallback(state)
        case .failed(let error):
            self.connectionDidFail(error: error)
            onConnectionStateCallback(state)
        case .cancelled:
            break
        default:
            break
        }
    }

    private func connectionDidFail(error: Error) {
        print("connection \(self.id) did failed, error: \(error)")
    }

    private func connectionDidEnd() {
        print("connection \(self.id) did end")
        self.stop(error: nil)
    }

    func stop(error: Error?, fromServer: Bool = true) {
        self.nwConnection.stateUpdateHandler = nil
        self.nwConnection.cancel()
        if let didStopCallback = self.didStopCallback {
            self.didStopCallback = nil
            if fromServer {
                didStopCallback(error)
            }
        }
    }

    private func setupReceive() {
        self.nwConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let message = String(data: data, encoding: .utf8)
                print("connection \(self.id) did receive, data: \(message!))")
                
                DispatchQueue.main.async {
                    self.lbMessage?.text = "\(message!)\n\(self.lbMessage?.text ?? "")"
                }
            }
            if isComplete {
                self.connectionDidEnd()
            } else if let error = error {
                self.connectionDidFail(error: error)
            } else {
                self.setupReceive()
            }
        }
    }
}

class Client {
    
    var onStopCallBack: (() -> Void) = {}

    init(_ host: String, _ ip: Int32, lbMessage: UILabel) {
        let nwConnection = NWConnection(host: .init(host), port: .init(integerLiteral: UInt16(ip)), using: .tcp)
        self.connection = Connection(nwConnection: nwConnection, lbMessage: lbMessage)
    }

    let connection: Connection

    func start() {
        self.connection.didStopCallback = self.didStopCallback(error:)
        self.connection.start()
    }
    
    func stop() {
        self.connection.stop(error: nil, fromServer: false)
    }

    func didStopCallback(error: Error?) {
        print("didStopCallback")
        onStopCallBack()
    }

//    static func run() {
//        let client = Client()
//        client.start()
//    }
}

class Server {

    init(_ lbMessage: UILabel? = nil) {
        self.listener = try! NWListener(using: .tcp, on: 8080)
        self.lbMessage = lbMessage
    }

    let listener: NWListener
    let lbMessage: UILabel?

    func start() throws {
        print("server will start")
        self.listener.stateUpdateHandler = self.stateDidChange(to:)
        self.listener.newConnectionHandler = self.didAccept(nwConnection:)
        self.listener.start(queue: .main)
    }

    func stateDidChange(to newState: NWListener.State) {
        switch newState {
        case .setup:
            break
        case .waiting:
            break
        case .ready:
            break
        case .failed(let error):
            print("server did fail, error: \(error)")
            self.stop()
        case .cancelled:
            break
        default:
            break
        }
    }

    private var connectionsByID: [Int: Connection] = [:]

    private func didAccept(nwConnection: NWConnection) {
        let connection = Connection(nwConnection: nwConnection, lbMessage: self.lbMessage)
        self.connectionsByID[connection.id] = connection
        connection.didStopCallback = { _ in
            self.connectionDidStop(connection)
        }
        connection.start()
        DispatchQueue.main.async {
            self.lbMessage?.text = "server did open connection \(connection.id)\n\(self.lbMessage?.text ?? "")"
        }
        print("server did open connection \(connection.id)")
    }

    private func connectionDidStop(_ connection: Connection) {
        self.connectionsByID.removeValue(forKey: connection.id)
        print("server did close connection \(connection.id)")
        DispatchQueue.main.async {
            self.lbMessage?.text = "server disconnect with \(connection.id)\n\(self.lbMessage?.text ?? "")"
        }
    }

    func stop() {
        self.listener.stateUpdateHandler = nil
        self.listener.newConnectionHandler = nil
        self.listener.cancel()
        for connection in self.connectionsByID.values {
            connection.didStopCallback = nil
            connection.stop()
        }
        self.connectionsByID.removeAll()
    }

    func heartbeat() {
        count += 1
        let data = "From ios server: \(count)"
        print(data)
        for connection in self.connectionsByID.values {
            connection.send(data: Data(data.utf8))
        }
    }

    static func run() {
        let listener = Server()
        try! listener.start()
        dispatchMain()
    }
}

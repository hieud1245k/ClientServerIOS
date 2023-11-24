//
//  ViewController.swift
//  ClientServer
//
//  Created by MAC on 22/11/2023.
//

import UIKit
import Network


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
    private var count = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        lbMessage.numberOfLines = 1000
        // Do any additional setup after loading the view.
    }

    @IBAction func connectToServer(_ sender: Any) {
        if (client == nil) {
            let address: String = lbAddress.text ?? ""
            let port: Int32 = Int32(lbPort.text ?? "") ?? 8080
            self.client = Client(address, port, lbMessage: self.lbMessage)
            DispatchQueue.global(qos: .background).async {
                self.client?.start()
            }
        } else {
            DispatchQueue.global(qos: .background).async {
                self.count += 1
                self.client?.connection.send(data: Data("From IOS client: \(self.count)".utf8))
            }
        }
    }
    
    @IBAction func startServer(_ sender: Any) {
        if (server == nil || !isStartServerSuccess) {
            DispatchQueue.global(qos: .background).async {
                do {
                    self.server = Server(self.lbMessage)
                    try self.server?.start()
                    self.isStartServerSuccess = true
                    DispatchQueue.main.async {
                        self.btConnect.isEnabled = false
                        self.btStart.setTitle("Send to client", for: .normal)
                        self.lbStatus.text = "Start server successful"
                    }
                } catch {
                    self.isStartServerSuccess = false
                    DispatchQueue.main.async {
                        self.lbStatus.text = "Start server failed"
                    }
                }
            }
        } else {
            server?.heartbeat()
        }
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
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .setup:
            break
        case .waiting(let error):
            self.connectionDidFail(error: error)
        case .preparing:
            break
        case .ready:
            print("connection \(self.id) ready")
        case .failed(let error):
            self.connectionDidFail(error: error)
        case .cancelled:
            break
        default:
            break
        }
    }

    private func connectionDidFail(error: Error) {
        print("connection \(self.id) did fail, error: \(error)")
        self.stop(error: error)
    }

    private func connectionDidEnd() {
        print("connection \(self.id) did end")
        self.stop(error: nil)
    }

    private func stop(error: Error?) {
        self.nwConnection.stateUpdateHandler = nil
        self.nwConnection.cancel()
        if let didStopCallback = self.didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
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

    init(_ host: String, _ ip: Int32, lbMessage: UILabel) {
        let nwConnection = NWConnection(host: .init(host), port: .init(integerLiteral: UInt16(ip)), using: .tcp)
        self.connection = Connection(nwConnection: nwConnection, lbMessage: lbMessage)
    }

    let connection: Connection

    func start() {
        self.connection.didStopCallback = self.didStopCallback(error:)
        self.connection.start()
    }

    func didStopCallback(error: Error?) {
        if error == nil {
            exit(EXIT_SUCCESS)
        } else {
            exit(EXIT_FAILURE)
        }
    }

//    static func run() {
//        let client = Client()
//        client.start()
//    }
}

class Server {

    init(_ lbMessage: UILabel? = nil) {
        self.listener = try! NWListener(using: .tcp, on: 8080)
        self.timer = DispatchSource.makeTimerSource(queue: .main)
        self.lbMessage = lbMessage
    }

    let listener: NWListener
    let timer: DispatchSourceTimer
    let lbMessage: UILabel?

    func start() throws {
        print("server will start")
        self.listener.stateUpdateHandler = self.stateDidChange(to:)
        self.listener.newConnectionHandler = self.didAccept(nwConnection:)
        self.listener.start(queue: .main)
    
        self.timer.setEventHandler(handler: self.heartbeat)
        self.timer.schedule(deadline: .now() + 5.0, repeating: 5.0)
        self.timer.activate()
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
    }

    private func stop() {
        self.listener.stateUpdateHandler = nil
        self.listener.newConnectionHandler = nil
        self.listener.cancel()
        for connection in self.connectionsByID.values {
            connection.didStopCallback = nil
            connection.stop()
        }
        self.connectionsByID.removeAll()
        self.timer.cancel()
    }

    func heartbeat() {
        let timestamp = Date()
        print("server heartbeat, timestamp: \(timestamp)")
        for connection in self.connectionsByID.values {
            let data = "heartbeat, connection: \(connection.id), timestamp: \(timestamp)\r\n"
            connection.send(data: Data(data.utf8))
        }
    }

    static func run() {
        let listener = Server()
        try! listener.start()
        dispatchMain()
    }
}

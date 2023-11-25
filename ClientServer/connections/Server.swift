//
//  Server.swift
//  ClientServer
//
//  Created by MAC on 25/11/2023.
//

import Foundation
import UIKit
import Network

class Server {
    private var count = 0

    init(_ lbMessage: UILabel? = nil) {
        self.listener = try! NWListener(using: .tcp, on: 8080)
        self.lbMessage = lbMessage
    }

    let listener: NWListener
    let lbMessage: UILabel?
    
    var onStateDidChange: ((NWListener.State) -> Void) = {_ in }

    func start() throws {
        print("server will start")
        self.listener.stateUpdateHandler = self.stateDidChange(to:)
        self.listener.newConnectionHandler = self.didAccept(nwConnection:)
        self.listener.start(queue: .main)
    }

    func stateDidChange(to newState: NWListener.State) {
        onStateDidChange(newState)
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
        print("server will stop")
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
        if (listener.state != .ready) {
            return
        }
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

//
//  Connection.swift
//  ClientServer
//
//  Created by MAC on 25/11/2023.
//

import Foundation
import UIKit
import Network

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
        print("Connection stateDidChange \(state)")
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

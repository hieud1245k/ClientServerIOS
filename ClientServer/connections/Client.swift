//
//  Client.swift
//  ClientServer
//
//  Created by MAC on 25/11/2023.
//

import Foundation
import UIKit
import Network

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

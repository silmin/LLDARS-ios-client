import Foundation
import Network
import NetworkExtension

class NWConnectionClient {
    private var host: Network.NWEndpoint.Host
    private var port: Network.NWEndpoint.Port
    private var using: NWParameters
    private var connection: NWConnection
    
    private var receiveData: Data?
    
    init(ip: String, port: UInt16, using: NWParameters) {
        self.host = NWEndpoint.Host(ip)
        self.port = NWEndpoint.Port(integerLiteral: port)
        self.using = using
        self.connection = NWConnection(host: self.host, port: self.port, using: self.using)
        self.receiveData = Data()
    }
    
    func startConnection() {
        let queue = DispatchQueue(label: "LLDARSClient")
        self.connection.start(queue: queue)
    }
    
    func sendMessage(message: Data) {
        let semaphore = DispatchSemaphore(value: 0)
        let completion = NWConnection.SendCompletion.contentProcessed { (error: NWError?) in
            NSLog("\(#function): Complete Send")
            semaphore.signal()
        }
        self.connection.send(content: message, completion: completion)
        NSLog("\(#function): sending...")
        semaphore.wait()
    }
    
    func getReceivedData() -> Data? {
        return self.receiveData
    }
    
    func receiveMessage() -> Data? {
        let semaphore = DispatchSemaphore(value: 0)
        receive(semaphore: semaphore)
        semaphore.wait()
        return getReceivedData()
    }
    
    func receiveMessageWithSize(size: Int) -> Data? {
        let semaphore = DispatchSemaphore(value: 0)
        receiveWithSize(semaphore: semaphore, size: size)
        semaphore.wait()
        return getReceivedData()
    }

    func receive(semaphore: DispatchSemaphore) {
        self.connection.receive(minimumIncompleteLength: 0, maximumLength: Int(INT_MAX), completion: { (data, context, end, error) in
            //NSLog("\(#function)-Connection: Receive Message")
            if let data = data {
                //self.receive(semaphore: semaphore)
                self.receiveData = data
                semaphore.signal()
            } else {
                NSLog("receiveMessage data nil")
                NSLog("end of receive")
                self.receiveData = nil
                semaphore.signal()
            }
        })
    }
    
    func receiveWithSize(semaphore: DispatchSemaphore, size: Int) {
        self.connection.receive(minimumIncompleteLength: 0, maximumLength: size, completion: { (data, context, end, error) in
            //NSLog("\(#function)-Connection: Receive Message")
            if let data = data {
                // self.receiveWithSize(semaphore: semaphore, size: size)
                self.receiveData = data
                semaphore.signal()
            } else {
                NSLog("receiveMessage data nil")
                NSLog("end of receive")
                semaphore.signal()
            }
        })
    }
    
    func getRemoteAddr() -> String {
        switch(self.connection.endpoint) {
        case .hostPort(let host, _):
            return "\(host)"
        default:
            return ""
        }
    }
    
    func cancelConnection() {
        self.connection.cancel()
    }
    
    deinit {
        self.connection.cancel()
        NSLog("Deinit Connection")
    }
}

class NWListenClient {
    private var port: Network.NWEndpoint.Port
    private var using: NWParameters
    private var listener: NWListener
    
    private var receiveData: Data?
    private var remoteAddr: String
    
    init(port: UInt16, using: NWParameters) {
        self.port = NWEndpoint.Port(integerLiteral: port)
        self.using = using
        self.listener = try! NWListener(using: self.using, on: self.port)
        self.receiveData = Data()
        self.remoteAddr = ""
    }
    
    func startListen() -> DispatchSemaphore {
        let queue = DispatchQueue(label: "LLDARSListener")
        let semaphore = DispatchSemaphore(value: 0)
        self.listener.newConnectionHandler = { (newConnection) in
            NSLog("\(#function): New Connection !")
            newConnection.receiveMessage(completion: { (data, context, flag, error) in
                if (flag) {
                    NSLog("\(#function)-Listener: Receve Message")
                    self.receiveData = data
                    switch(newConnection.endpoint) {
                    case .hostPort(let host, _):
                        self.remoteAddr = "\(host)"
                    default:
                        break
                    }
                    semaphore.signal()
                }
            })
            newConnection.start(queue: queue)
        }
        self.listener.start(queue: queue)
        return semaphore
    }
    
    func getReceivedData() -> Data? {
        return self.receiveData
    }
    
    func getRemoteAddr() -> String {
        return self.remoteAddr
    }
    
    func cancelListen() {
        self.listener.cancel()
    }
    
    deinit {
        self.listener.cancel()
        NSLog("Deinit Listener")
    }
}

func parseIP(ip: String) -> UInt32 {
    var addr = in_addr()
    if inet_pton(AF_INET, ip, &addr) == 1 {
        return UInt32(bigEndian: addr.s_addr)
    } else {
        NSLog("Invalid IP Address '\(ip)'")
        return 0
    }
}

func getWiFiAddress() -> String? {
    var address : String?
    
    // Get list of all interfaces on the local machine:
    var ifaddr : UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return nil }
    guard let firstAddr = ifaddr else { return nil }
    
    // For each interface ...
    for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let interface = ifptr.pointee
        // Check for IPv4 or IPv6 interface:
        let addrFamily = interface.ifa_addr.pointee.sa_family
        if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
            // Check interface name:
            let name = String(cString: interface.ifa_name)
            if  name == "en0" {
                // Convert interface address to a human readable string:
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                address = String(cString: hostname)
            }
        }
    }
    freeifaddrs(ifaddr)
    
    return address
}

func connectWiFi() {
    let manager = NEHotspotConfigurationManager.shared
    let ssid = "lldars-Hotspot"
    let password = "qwer1234"
    let hotspotConfiguration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: true)
    hotspotConfiguration.joinOnce = true
    hotspotConfiguration.lifeTimeInDays = 1
    
    manager.apply(hotspotConfiguration) { (error) in
        if let error = error {
            print("Failed connect hotspot \(ssid): \(error)")
        } else {
            print("Success connect hotspot \(ssid)")
        }
    }
}

extension UInt32 {
    public func IPv4String() -> String {
        let ip = self
        
        let byte1 = UInt8(ip & 0xff)
        let byte2 = UInt((ip>>8) & 0xff)
        let byte3 = UInt((ip>>16) & 0xff)
        let byte4 = UInt((ip>>24) & 0xff)
        
        return "\(byte4).\(byte3).\(byte2).\(byte1)"
    }
}

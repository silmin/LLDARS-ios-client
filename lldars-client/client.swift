import Foundation
import ZIPFoundation
import ARKit

func LLDARSClient(configuration: inout ARWorldTrackingConfiguration, imageNameToEntityURLs: inout [String:[URL]]) {
    let wifiAddr: String = {
        while true {
            if let addr = getWiFiAddress() {
                return addr
            } else {
                print("No WiFi address. Lookup WiFi")
                connectWiFi()
            }
        }
    }()
    
    NSLog("Wi-Fi addr: \(wifiAddr)")
    
    let res = LookupServer(from: wifiAddr)
    print(res.ip)
    print(res.port)
    
    guard let path = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
        return
    }
    
    GetObjects(from: wifiAddr, serverIp: res.ip, servicePort: res.port, to: path)
    LoadObjects(from: path, configuration: &configuration, imageNameToEntityURLs: &imageNameToEntityURLs)
}

func LookupServer(from: String) -> (ip: String, port: UInt16) {
    let ackClient = NWListenClient(port: UInt16(50000), using: .tcp)
    let bcClient = NWConnectionClient(ip: "255.255.255.255", port: UInt16(ClientBCPort), using: .udp)
    
    while true {
        let ackSemaphore = ackClient.startListen()
        bcClient.startConnection()
        
        let ip = parseIP(ip: from)
        let data = Marshal(lldars: NewDiscoverBroadcast(id: 0, origin: ip, sp: UInt16(50000)))
        NSLog("\(#function): Lookup BC")
        bcClient.sendMessage(message: data)
        
        ackSemaphore.wait()
        if let data = ackClient.getReceivedData() {
            let lldars = Unmarshal(data: data)
            if lldars.LayerType != .ServicePortNotify {
                continue
            }
            print(lldars)
            NSLog(String(bytes: lldars.Payload, encoding: .utf8)!)
            ackClient.cancelListen()
            return (ackClient.getRemoteAddr(), lldars.ServicePort)
        } else {
            return ("", 0)
        }
    }
}

func GetObjects(from: String, serverIp: String, servicePort: UInt16, to: URL) {
    let client = NWConnectionClient(ip: serverIp, port: servicePort, using: .tcp)
    client.startConnection()
    
    let ip = parseIP(ip: from)
    let data = Marshal(lldars: NewGetObjectRequest(id: 0, origin: ip, sp: servicePort))
    client.sendMessage(message: data)
    
    var i = 0
    
    while true {
        var lldars = ReadLLDARSHeader(client: client)
        print(lldars)
        switch lldars.LayerType {
        case .EndOfDelivery:
            NSLog("End of Delivery")
            return
        case .DeliveryObject:
            lldars.Payload = ReadLLDARSPayLoad(client: client, length: lldars.Length)
            NSLog("file-size: %d bytes", lldars.Payload.count)
            saveFile(data: Data(lldars.Payload), to: to, filename: "\(lldars.ServerId)-\(i).zip")
            i += 1
        default:
            continue
        }
    }
}

func LoadObjects(from: URL, configuration: inout ARWorldTrackingConfiguration, imageNameToEntityURLs: inout [String:[URL]]) {
    let resources = unzipFiles(from: from)
    print("resouces: \(resources)")
    
    resources.forEach { resource in
        let contentsUrl = resource.url.appendingPathComponent("contents/")
        var entityCnt:Int = 0
        let entityUrls = extractFiles(ext: "usdz", from: contentsUrl).compactMap { oldName -> URL? in
            let newName = "\(resource.name)_\(entityCnt).usdz"
            entityCnt += 1
            let oldUrl = contentsUrl.appendingPathComponent(oldName)
            let newUrl = contentsUrl.appendingPathComponent(newName)
            
            do {
                try FileManager.default.moveItem(at: oldUrl, to: newUrl)
            } catch {
                return nil
            }
            return newUrl
        }
        let markerUrl = resource.url.appendingPathComponent("contents/marker.jpg")
        if let arImage = loadArImage(from: markerUrl) {
            print("markerUrl: \(markerUrl)")
            print("entityUrl: \(entityUrls)")
            arImage.name = resource.name
            configuration.detectionImages.insert(arImage)
            imageNameToEntityURLs[resource.name] = entityUrls
        }
    }
}

func loadArImage(from: URL) -> ARReferenceImage? {
    do {
        let data = try Data(contentsOf: from)
        let uiImage = UIImage(data: data)!
        let ciImage = CIImage(image: uiImage)!
        let cgImage = convertCIImageToCGImage(inputImage: ciImage)!
        let arImage = ARReferenceImage(cgImage, orientation: CGImagePropertyOrientation.up, physicalWidth: 0.15)
        return arImage
    } catch {
        print("Error \(#function): \(error)")
    }
    return nil
}

func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
    let context = CIContext(options: nil)
    if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
        return cgImage
    }
    return nil
}

func saveFile(data: Data, to: URL, filename: String) {
    do {
        let path = to.appendingPathComponent(filename)
        try data.write(to: path)
        print("Succese save")
    } catch {
        print("Failed save")
        print(error)
    }
}

func unzipFiles(from: URL) -> [(name:String, url:URL)] {
    let zipFiles = extractFiles(ext: "zip", from: from)
    if zipFiles.count == 0 {
        return []
    }
    
    var resourceNames: [(name:String, url:URL)] = []
    
    print("\(#function): from: \(from)")
    zipFiles.forEach { filename in
        let dstUrl = from.appendingPathComponent(removeExt(filename: filename))
        let srcUrl = from.appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: dstUrl.path) {
            do {
                try FileManager.default.removeItem(at: dstUrl)
            } catch {
                print("Remove Error: \(error)")
            }
        }
        
        do {
            try FileManager.default.createDirectory(at: dstUrl, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.unzipItem(at: srcUrl, to: dstUrl, skipCRC32: true)
            resourceNames.append((removeExt(filename: filename), dstUrl))
        } catch {
            print("UNZIP Error: \(error)")
        }
    }
    
    return resourceNames
}

func extractFiles(ext: String, from: URL) -> [String] {
    guard let fileNames = try? FileManager.default.contentsOfDirectory(atPath: from.path) else {
        return []
    }
    
    return fileNames.compactMap { filename in
        let url = URL(fileURLWithPath: filename)
        if url.pathExtension == ext {
            return filename
        } else {
            return nil
        }
    }
}

func removeExt(filename: String) -> String {
    if let idx = filename.lastIndex(of: ".") {
        return String(filename.prefix(upTo: idx))
    } else {
        return filename
    }
}

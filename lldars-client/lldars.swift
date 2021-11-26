import Foundation

enum LLDARSLayerType: UInt8 {
    case DiscoverBroadcast
    case ServicePortNotify
    case GetObjectRequest
    case DeliveryObject
    case EndOfDelivery
    case ReceivedObjects
    case BackupObjectRequest
    case AcceptBackupObject
    case RejectBackupObject
    case SyncObjectRequest
    case AcceptSyncObject
    case RejectSyncObject
}

let ServicePort: UInt16 = 60000
let ClientBCPort: UInt16 = 60001
let ServerBCPort: UInt16 = 60002
let LLDARSLayerSize: Int = 1 + 4 + 4 + 2 + 8
let DiscoverBroadcastPayload: [UInt8] = Array("Is available LLDARS server on this network ?".utf8)
let ServicePortNotifyPayload: [UInt8] = Array("--ServicePortNotifyPayload--".utf8)
let GetObjectRequestPaylaod: [UInt8] = Array("--GetObjectRequestPayload--".utf8)
let DeliveryObjectPaylaod: [UInt8] = Array("--DeliveryObjectPayload--".utf8)
let EndOfDeliveryPayload: [UInt8] = Array("--EndOfDelivery--".utf8)
let ReceivedObjectsPaylaod: [UInt8] = Array("--ReceivedObjectsPaylaod--".utf8)

struct LLDARSLayer {
    var LayerType:LLDARSLayerType
    var ServerId:UInt32
    var Origin:UInt32
    var ServicePort:UInt16
    var Length:UInt64
    var Payload:[UInt8]
}

func Marshal(lldars:LLDARSLayer) -> Data {
    var data: Data? = nil
    data = Data([lldars.LayerType.rawValue]) + lldars.ServerId.data +
    lldars.Origin.data + lldars.ServicePort.data + lldars.Length.data + lldars.Payload
    return data!
}

func Unmarshal(data:Data) -> LLDARSLayer {
    return LLDARSLayer (
        LayerType: LLDARSLayerType(rawValue: UInt8(data[0]))!,
        ServerId: data[1...4].uint32,
        Origin: data[5...8].uint32,
        ServicePort: data[9...10].uint16,
        Length: data[11...18].uint64,
        Payload: [UInt8](data[19...])
    )
}

func NewDiscoverBroadcast(id:UInt32, origin:UInt32, sp:UInt16) -> LLDARSLayer {
    let length = UInt64(DiscoverBroadcastPayload.count)
    return NewLLDARSPakcet(type: LLDARSLayerType.DiscoverBroadcast, id: 0, origin: origin, sp: sp, length: length, payload: DiscoverBroadcastPayload)
}

func NewGetObjectRequest(id:UInt32, origin:UInt32, sp:UInt16) -> LLDARSLayer {
    let length = UInt64(GetObjectRequestPaylaod.count)
    return NewLLDARSPakcet(type: LLDARSLayerType.GetObjectRequest, id: 0, origin: origin, sp: sp, length: length, payload: GetObjectRequestPaylaod)
}

func NewReceivedObjects(id:UInt32, origin:UInt32, sp:UInt16) -> LLDARSLayer {
    let length = UInt64(ReceivedObjectsPaylaod.count)
    return NewLLDARSPakcet(type: LLDARSLayerType.ReceivedObjects, id: 0, origin: origin, sp: sp, length: length, payload: ReceivedObjectsPaylaod)
}

func NewLLDARSPakcet(type:LLDARSLayerType, id:UInt32, origin:UInt32, sp:UInt16, length:UInt64, payload:[UInt8]) -> LLDARSLayer {
    return LLDARSLayer(LayerType: type, ServerId: id, Origin: origin, ServicePort: sp, Length: length, Payload: payload)
}

func ReadLLDARSHeader(client: NWConnectionClient) -> LLDARSLayer {
    return Unmarshal(data: ReadDataFromConn(client: client, length: UInt64(LLDARSLayerSize)))
}

func ReadLLDARSPayLoad(client: NWConnectionClient, length: UInt64) -> [UInt8] {
    return [UInt8](ReadDataFromConn(client: client, length: length))
}

func ReadDataFromConn(client: NWConnectionClient, length: UInt64) -> Data {
    var data = Data()
    while true {
        let maxSize = Int(length) - data.count
        if maxSize <= 0 {
            break
        }
        if let d = client.receiveMessageWithSize(size: maxSize) {
            data += d
        }
    }
    return data
}

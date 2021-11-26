import Foundation

extension Int {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<Int>.size).reversedData
    }
}

extension UInt8 {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<UInt8>.size).reversedData
    }
}

extension UInt16 {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<UInt16>.size).reversedData
    }
}

extension UInt32 {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<UInt32>.size).reversedData
    }
}

extension UInt64 {
    var data: Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<UInt64>.size).reversedData
    }
}

extension Data {
    var reversedBytes: [UInt8] {
        var values = [UInt8](repeating: 0, count: count)
        copyBytes(to: &values, count: count)
        return values.reversed()
    }

    var reversedData: Data {
        return Data(bytes: reversedBytes, count: count)
    }

    var uint8: UInt8 {
        UInt8(bigEndian: self.withUnsafeBytes { $0.pointee })
    }

    var uint16: UInt16 {
        UInt16(bigEndian: self.withUnsafeBytes { $0.pointee })
    }

    var uint32: UInt32 {
        UInt32(bigEndian: self.withUnsafeBytes { $0.pointee })
    }

    var uint64: UInt64 {
        UInt64(bigEndian: self.withUnsafeBytes { $0.pointee })
    }
}

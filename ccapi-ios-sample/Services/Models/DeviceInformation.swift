import Foundation

// MARK: - デバイス情報レスポンス

/// `GET /ccapi/ver100/deviceinformation` のレスポンス
/// 例: `{"manufacturer":"Canon.Inc","productname":"Canon EOS R100","guid":"...","serialnumber":"...","macaddress":"...","firmwareversion":"1.1.0"}`
struct DeviceInformation: Decodable, Equatable {
    let manufacturer: String
    let productName: String
    let guid: String
    let serialNumber: String
    let macAddress: String
    let firmwareVersion: String

    enum CodingKeys: String, CodingKey {
        case manufacturer
        case productName = "productname"
        case guid
        case serialNumber = "serialnumber"
        case macAddress = "macaddress"
        case firmwareVersion = "firmwareversion"
    }
}

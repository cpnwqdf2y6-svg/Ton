import Foundation

struct WDATARecord: Hashable {
    var sourceFileName: String
    var rowNumber: Int
    var customerCode: String
    var customerName: String
    var ticketNo: String
    var netWeightText: String
    var dateText: String
    var rawFields: [String]
    var normalizedTicketNo: String
    var normalizedCustomerCode: String
}

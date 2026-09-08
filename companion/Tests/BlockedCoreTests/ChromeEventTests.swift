import AppKit
import Carbon
import XCTest
@testable import BlockedCore

final class ChromeEventTests: XCTestCase {
    func testEveryReadTargetsCapturedProcessAndUsesReadOnlyEvent() throws {
        let values = ["105", "210", "https://github.com/generaltranslation/content/pull/471"]
        for pid: pid_t in [661, 29470] {
            var index = 0
            let fields = try ChromeTarget.readFields(processID: pid) { event in
                let target = try XCTUnwrap(event.attributeDescriptor(forKeyword: keyAddressAttr))
                XCTAssertEqual(target.descriptorType, typeKernelProcessID)
                XCTAssertEqual(target.data, NSAppleEventDescriptor(processIdentifier: pid).data)
                XCTAssertEqual(event.eventClass, AEEventClass(kAECoreSuite))
                XCTAssertEqual(event.eventID, AEEventID(kAEGetData))
                let reply = NSAppleEventDescriptor.appleEvent(withEventClass: AEEventClass(kCoreEventClass),
                    eventID: AEEventID(kAEAnswer), targetDescriptor: nil,
                    returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
                reply.setParam(.init(string: values[index]), forKeyword: keyDirectObject)
                index += 1
                return reply
            }
            XCTAssertEqual(fields, values)
            XCTAssertEqual(index, 3)
        }
    }

    func testErrorReplyCannotBecomeTargetEvenIfItContainsData() {
        for error: Int32 in [-1743, -1728] {
            var reads = 0
            XCTAssertThrowsError(try ChromeTarget.readFields(processID: 661) { _ in
                reads += 1
                let reply = NSAppleEventDescriptor.appleEvent(withEventClass: AEEventClass(kCoreEventClass),
                    eventID: AEEventID(kAEAnswer), targetDescriptor: nil,
                    returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
                reply.setParam(.init(int32: error), forKeyword: keyErrorNumber)
                reply.setParam(.init(string: "105"), forKeyword: keyDirectObject)
                return reply
            })
            XCTAssertEqual(reads, 1)
        }
    }
}

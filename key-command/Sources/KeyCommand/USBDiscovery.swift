import IOKit
import IOKit.serial
import Foundation

enum USBDiscovery {
    static func paths() -> [String] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(kIOSerialBSDServiceValue), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var paths: [String] = []
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }
            func property(_ name: String) -> AnyObject? {
                IORegistryEntrySearchCFProperty(service, kIOServicePlane, name as CFString, kCFAllocatorDefault,
                    IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents))
            }
            if property("USB Product Name") as? String == "Key Command",
               (property("idVendor") as? NSNumber)?.intValue == 0x303a,
               let path = property(kIOCalloutDeviceKey) as? String { paths.append(path) }
        }
        return paths.sorted()
    }
}

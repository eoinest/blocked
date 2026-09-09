import Darwin
import Foundation

/// Nonblocking, exclusive USB CDC transport. EOF/HUP belong to the open file
/// descriptor, so a replacement device at the same /dev path is still reopened.
public final class POSIXButtonSerialPort: ButtonSerialPort {
    private var descriptor: Int32

    // Tests exercise the real poll/read/close path with an owned nonblocking pipe.
    // Production always uses the initializer that configures the USB CDC device.
    init(ownedDescriptor: Int32) { descriptor = ownedDescriptor }

    public init?(path: String) {
        let fd = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return nil }
        var configured = false
        defer { if !configured { Darwin.close(fd) } }
        guard ioctl(fd, TIOCEXCL) == 0 else { return nil }
        var settings = termios()
        guard tcgetattr(fd, &settings) == 0 else { return nil }
        cfmakeraw(&settings)
        cfsetispeed(&settings, speed_t(B115200))
        cfsetospeed(&settings, speed_t(B115200))
        settings.c_cflag |= tcflag_t(CLOCAL | CREAD | HUPCL)
        settings.c_cflag &= ~tcflag_t(CRTSCTS)
        withUnsafeMutableBytes(of: &settings.c_cc) { control in
            control[Int(VMIN)] = 1
            control[Int(VTIME)] = 0
        }
        guard tcsetattr(fd, TCSANOW, &settings) == 0,
              tcflush(fd, TCIOFLUSH) == 0 else { return nil }
        var signals = Int32(TIOCM_DTR | TIOCM_RTS)
        guard ioctl(fd, TIOCMBIS, &signals) == 0 else { return nil }
        descriptor = fd
        configured = true
    }

    deinit { close() }

    public func close() {
        if descriptor >= 0 { Darwin.close(descriptor); descriptor = -1 }
    }

    public func read() -> ButtonSerialRead {
        guard descriptor >= 0 else { return .disconnected }
        var readiness = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        let ready = Darwin.poll(&readiness, 1, 0)
        if ready < 0 { return errno == EINTR ? .idle : .disconnected }
        if readiness.revents & Int16(POLLHUP | POLLERR | POLLNVAL) != 0 { return .disconnected }
        guard ready > 0 else { return .idle }
        var bytes = [UInt8](repeating: 0, count: 512)
        let count = Darwin.read(descriptor, &bytes, bytes.count)
        if count > 0 { return .bytes(Data(bytes.prefix(count))) }
        if count == 0 { return .disconnected }
        return errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR ? .idle : .disconnected
    }

    public func write(_ data: Data) -> Bool {
        guard descriptor >= 0 else { return false }
        // Commands are a few bytes. An incomplete nonblocking write is a broken
        // session: reconnect rather than queueing an action across disconnects.
        return data.withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress, $0.count) == $0.count }
    }
}

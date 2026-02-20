// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import Foundation

public enum HallidayConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case error(String)
}

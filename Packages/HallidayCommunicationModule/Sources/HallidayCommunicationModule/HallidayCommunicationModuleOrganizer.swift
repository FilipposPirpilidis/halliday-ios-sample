// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import Foundation

public final class HallidayCommunicationModuleOrganizer {
    public static let shared = HallidayCommunicationModuleOrganizer()
    public let hallidayController: HallidayController

    public init() {
        self.hallidayController = HallidayController()
    }
}

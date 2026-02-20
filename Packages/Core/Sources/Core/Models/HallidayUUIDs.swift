// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com

import CoreBluetooth

public enum HallidayUUIDs {
    public static let writeB754Service = CBUUID(string: "B75497DB-806E-42B1-9E60-5871CA2E504B")
    public static let writeB754Char = CBUUID(string: "B75497DC-806E-42B1-9E60-5871CA2E504B")
    public static let notifyB754Char = CBUUID(string: "B75497DD-806E-42B1-9E60-5871CA2E504B")

    public static let audioService01A6BAAD = CBUUID(string: "01A6BAAD-D1F8-47EC-AC42-864FDD7BDCC9")
    public static let write01A6BWrite = CBUUID(string: "01A6BAAE-D1F8-47EC-AC42-864FDD7BDCC9")
    public static let audioNotify01A6BAAF = CBUUID(string: "01A6BAAF-D1F8-47EC-AC42-864FDD7BDCC9")

    public static let scanServices: [CBUUID] = [
        writeB754Service,
        audioService01A6BAAD
    ]

    public static let notifyCharacteristics: Set<CBUUID> = [
        notifyB754Char,
        audioNotify01A6BAAF
    ]
}

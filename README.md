# Halliday iPhone Sample

iOS sample app for connecting to Halliday glasses over BLE, opening/closing captions, streaming audio notifications, decoding Opus to PCM, and running live speech recognition.

## Author

- Filippos Pirpilidis
- Sr iOS Engineer
- f.pirpilidis@gmail.com

## Project Structure

- `App/`
  - UIKit app (MVVM with Combine)
  - Device selection, connect/disconnect, captions controls
  - Live BLE logs + live transcript UI
- `Packages/Core`
  - Shared BLE models/protocols (`HallidayConnectionState`, `HallidayDiscoveredDevice`, `HallidayBLEManaging`)
- `Packages/HallidayCommunicationModule`
  - BLE manager and controller
  - Vendor frame commands (init sequence, captions open/close, text to display)
  - Audio notify stream exposure
  - Opus transport parser + Opus decode to PCM
  - ObjC/C target with `libopus.a` + `include/opus`

## BLE UUIDs Used

Only these are used by the manager:

- Service `B75497DB-806E-42B1-9E60-5871CA2E504B`
  - Write `B75497DC-806E-42B1-9E60-5871CA2E504B`
  - Notify `B75497DD-806E-42B1-9E60-5871CA2E504B`
- Service `01A6BAAD-D1F8-47EC-AC42-864FDD7BDCC9`
  - Write `01A6BAAE-D1F8-47EC-AC42-864FDD7BDCC9`
  - Notify `01A6BAAF-D1F8-47EC-AC42-864FDD7BDCC9`

## Implemented Flow

- If no saved target UUID:
  - retrieve connected peripherals for Halliday services
  - scan for Halliday services
  - show devices in list
- On device selection:
  - save peripheral UUID in `UserDefaults`
  - connect to selected device
- On next launch:
  - auto-connect using saved UUID
- `Unlink`:
  - clears saved UUID and returns app to discovery mode

## Captions Controls

- `Open Captions` -> sends `sendRequestCaptions`
- `End Captions` -> sends `endDisplayCaptions`
- Buttons are enabled only while connected

## Audio + Speech

- Audio notify (`01A6BAAF`) is exposed as raw `Data`
- Opus packets are parsed and decoded to PCM (16kHz mono, 16-bit LE)
- PCM stream feeds iOS Speech framework for live transcript
- Final speech phrases are sent to glasses with `sendTextToHallidayDisplay`

## Notifications Debugging

BLE logs include:

- service discovery
- characteristic discovery + properties
- notify enable requests
- notify enabled/disabled confirmation
- B754/audio notify payloads in hex

## Requirements

- Xcode 16+
- iOS 16+
- Physical iPhone recommended for BLE testing
- Halliday glasses device

## Open in Xcode

Open:

- `HallidayIPhoneApp.xcodeproj`

## Permissions

`Info.plist` includes:

- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `UILaunchStoryboardName = LaunchScreen`

## Build Notes

If Xcode cache gets stale after moving folders or package edits:

1. Product -> Clean Build Folder
2. Delete DerivedData
3. Reopen project and build again

## Disclaimer

This sample is focused on BLE integration and speech pipeline behavior. Command semantics and payloads are based on observed/example flows and may need tuning per firmware version.

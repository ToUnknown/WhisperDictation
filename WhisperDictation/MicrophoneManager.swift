//
//  MicrophoneManager.swift
//  WhisperDictation
//
//  Manages audio input devices (microphones) enumeration and selection.
//

import Foundation
import AVFoundation
import CoreAudio
import Combine

// MARK: - Audio Device Model

struct AudioInputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    
    static let systemDefault = AudioInputDevice(
        id: 0,
        name: "System Default",
        uid: "system_default"
    )
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    static func == (lhs: AudioInputDevice, rhs: AudioInputDevice) -> Bool {
        lhs.uid == rhs.uid
    }
}

// MARK: - Microphone Manager

final class MicrophoneManager: ObservableObject {
    static let shared = MicrophoneManager()
    
    @Published private(set) var availableDevices: [AudioInputDevice] = []
    @Published var selectedDeviceUID: String {
        didSet {
            saveSelectedDevice()
        }
    }
    
    private let storageKey = "SelectedMicrophoneUID"
    private var deviceChangeListener: AudioObjectPropertyListenerBlock?
    
    var selectedDevice: AudioInputDevice? {
        if selectedDeviceUID == AudioInputDevice.systemDefault.uid {
            return .systemDefault
        }
        return availableDevices.first { $0.uid == selectedDeviceUID }
    }
    
    private init() {
        self.selectedDeviceUID = UserDefaults.standard.string(forKey: storageKey) 
            ?? AudioInputDevice.systemDefault.uid
        refreshDevices()
        setupDeviceChangeListener()
    }
    
    deinit {
        removeDeviceChangeListener()
    }
    
    // MARK: - Public Methods
    
    func refreshDevices() {
        var devices: [AudioInputDevice] = [.systemDefault]
        
        // Get all audio devices
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Get size of device list
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr else {
            print("[MicrophoneManager] Failed to get device list size: \(status)")
            availableDevices = devices
            return
        }
        
        // Get device IDs
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        guard status == noErr else {
            print("[MicrophoneManager] Failed to get device list: \(status)")
            availableDevices = devices
            return
        }
        
        // Filter for input devices and get their names
        for deviceID in deviceIDs {
            if hasInputChannels(deviceID: deviceID) {
                if let name = getDeviceName(deviceID: deviceID),
                   let uid = getDeviceUID(deviceID: deviceID) {
                    let device = AudioInputDevice(id: deviceID, name: name, uid: uid)
                    devices.append(device)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.availableDevices = devices
            
            // Validate selected device still exists
            if self.selectedDeviceUID != AudioInputDevice.systemDefault.uid {
                if !devices.contains(where: { $0.uid == self.selectedDeviceUID }) {
                    self.selectedDeviceUID = AudioInputDevice.systemDefault.uid
                }
            }
        }
        
        print("[MicrophoneManager] Found \(devices.count) input devices")
    }
    
    func selectDevice(_ device: AudioInputDevice) {
        selectedDeviceUID = device.uid
        print("[MicrophoneManager] Selected device: \(device.name)")
    }
    
    /// Returns the AudioDeviceID for the selected device, or nil to use system default
    func getSelectedDeviceID() -> AudioDeviceID? {
        guard selectedDeviceUID != AudioInputDevice.systemDefault.uid,
              let device = availableDevices.first(where: { $0.uid == selectedDeviceUID }) else {
            return nil
        }
        return device.id
    }
    
    // MARK: - System Default Device Management
    
    /// Gets the current system default input device
    func getSystemDefaultInputDevice() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &size,
            &deviceID
        )
        
        guard status == noErr, deviceID != 0 else {
            print("[MicrophoneManager] Failed to get system default input device: \(status)")
            return nil
        }
        
        return deviceID
    }
    
    /// Sets a device as the system default input device
    @discardableResult
    func setSystemDefaultInputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceIDVar = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            size,
            &deviceIDVar
        )
        
        if status == noErr {
            print("[MicrophoneManager] Successfully set system default input device to: \(deviceID)")
            return true
        } else {
            print("[MicrophoneManager] Failed to set system default input device: \(status)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr, propertySize > 0 else {
            return false
        }
        
        let rawBufferList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(propertySize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawBufferList.deallocate() }

        let bufferListPtr = rawBufferList.bindMemory(to: AudioBufferList.self, capacity: 1)
        let getStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            bufferListPtr
        )

        guard getStatus == noErr else {
            return false
        }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPtr)
        return bufferList.contains { $0.mNumberChannels > 0 }
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var name: CFString?
        let status = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                ptr
            )
        }
        
        guard status == noErr, let deviceName = name else {
            return nil
        }
        
        return deviceName as String
    }
    
    private func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var uid: CFString?
        let status = withUnsafeMutablePointer(to: &uid) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                ptr
            )
        }
        
        guard status == noErr, let deviceUID = uid else {
            return nil
        }
        
        return deviceUID as String
    }
    
    private func saveSelectedDevice() {
        UserDefaults.standard.set(selectedDeviceUID, forKey: storageKey)
    }
    
    // MARK: - Device Change Listener
    
    private func setupDeviceChangeListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        deviceChangeListener = { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.refreshDevices()
            }
        }
        
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            deviceChangeListener!
        )
        
        if status != noErr {
            print("[MicrophoneManager] Failed to add device change listener: \(status)")
        }
    }
    
    private func removeDeviceChangeListener() {
        guard let listener = deviceChangeListener else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            listener
        )
    }
}






//
//  HapticSettings.swift
//  Hear2gether
//
//  Created by Applied Haptics Laboratory on 2025/03/15.
//


import SwiftUI
import CoreHaptics

// HapticSettings - Store and manage haptic feedback settings globally
class HapticSettings: ObservableObject {
    // Read the values from AppStorage
    @AppStorage("iphoneVibrationEnabled") var vibrationEnabled: Bool = false
    @AppStorage("hapticSetX") var sharpnessDouble: Double = 150.0
    @AppStorage("hapticSetY") var intensityDouble: Double = 150.0
    
    // Normalized values (0.0-1.0) for use with CoreHaptics
    var normalizedSharpness: Float {
        return Float(min(1.0, max(0.0, sharpnessDouble / 300.0)))
    }
    
    var normalizedIntensity: Float {
        return Float(min(1.0, max(0.0, intensityDouble / 300.0)))
    }
    
    // Singleton pattern to access settings from anywhere
    static let shared = HapticSettings()
    
    private init() {}
}

// Extension to existing HapticManager to use the settings
extension HapticManager {
    // Updated method to use settings from HapticSettings
    func playHeartbeatHapticWithSettings(interval: Double) {
        // Check if vibration is enabled globally
        guard HapticSettings.shared.vibrationEnabled else { return }
        
        // Get intensity and sharpness from settings
        let intensityLevel = HapticSettings.shared.normalizedIntensity
        let sharpnessLevel = HapticSettings.shared.normalizedSharpness
        
        // Main vibration
        let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityLevel)
        let sharpness1 = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessLevel)
        let mainEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity1, sharpness1],
            relativeTime: 0.0
        )
        
        // Second vibration (softer, to represent the second heart beat)
        let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityLevel * 0.5)
        let sharpness2 = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessLevel * 0.6)
        let secondEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity2, sharpness2],
            relativeTime: interval * 0.15 // Slightly delayed after the first vibration
        )
        
        do {
            let pattern = try CHHapticPattern(events: [mainEvent, secondEvent], parameterCurves: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play heartbeat haptic pattern: \(error.localizedDescription)")
        }
    }
    
    // Test current intensity settings
    func testCurrentHapticSettings() {
        // Check if vibration is enabled
        guard HapticSettings.shared.vibrationEnabled else {
            print("Haptic feedback is disabled")
            return
        }
        
        // Get current settings
        let intensityLevel = HapticSettings.shared.normalizedIntensity
        let sharpnessLevel = HapticSettings.shared.normalizedSharpness
        
        print("Testing haptic feedback - Intensity: \(intensityLevel), Sharpness: \(sharpnessLevel)")
        
        // Create a test pattern
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityLevel)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessLevel)
        
        // Single stronger pulse
        let testEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0.0
        )
        
        do {
            let pattern = try CHHapticPattern(events: [testEvent], parameterCurves: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play test haptic pattern: \(error.localizedDescription)")
        }
    }
}

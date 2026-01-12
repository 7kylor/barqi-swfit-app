@preconcurrency import AVFoundation
import Foundation
import Observation

#if os(iOS)
import UIKit
#endif

/// Service for capturing audio from the microphone in real-time using AVAudioEngine
/// Provides audio buffers for streaming transcription (16kHz, mono, Float32)
@MainActor
@Observable
final class StreamingAudioCaptureService: NSObject {
  
  // MARK: - Observable State
  
  private(set) var isCapturing = false
  private(set) var audioLevel: Float = 0
  private(set) var error: CaptureError?
  private(set) var permissionStatus: PermissionStatus = .unknown
  
  // MARK: - Types
  
  enum PermissionStatus {
    case unknown
    case granted
    case denied
    case restricted
  }
  
  enum CaptureError: Error, LocalizedError {
    case permissionDenied
    case captureFailed(String)
    case noCaptureInProgress
    case sessionSetupFailed
    case engineStartFailed
    
    var errorDescription: String? {
      switch self {
      case .permissionDenied:
        return L("voice_error_mic_permission")
      case .captureFailed(let reason):
        return String(format: L("voice_error_recording_failed"), reason)
      case .noCaptureInProgress:
        return L("voice_error_no_recording")
      case .sessionSetupFailed:
        return L("voice_error_session_failed")
      case .engineStartFailed:
        return L("voice_error_session_failed")
      }
    }
  }
  
  // MARK: - Audio Buffer Callback
  
  /// Callback type for audio buffer delivery
  typealias AudioBufferCallback = (AVAudioPCMBuffer) -> Void
  
  // MARK: - Private Properties
  
  private var audioEngine: AVAudioEngine?
  private var inputNode: AVAudioInputNode?
  private var audioFormat: AVAudioFormat?
  private var levelTimer: Timer?
  private var audioBufferCallback: AudioBufferCallback?
  
  // Audio format optimized for WhisperKit: 16kHz, mono, Float32
  private let targetSampleRate: Double = 16000.0
  private let targetChannels: UInt32 = 1
  
  // Buffer size for audio capture (1024 frames = ~64ms at 16kHz)
  private let bufferSize: AVAudioFrameCount = 1024
  
  // MARK: - Initialization
  
  override init() {
    super.init()
    checkPermissionStatus()
  }
  
  // MARK: - Permission Handling
  
  /// Check current microphone permission status
  func checkPermissionStatus() {
    switch AVAudioApplication.shared.recordPermission {
    case .granted:
      permissionStatus = .granted
    case .denied:
      permissionStatus = .denied
    case .undetermined:
      permissionStatus = .unknown
    @unknown default:
      permissionStatus = .unknown
    }
  }
  
  /// Request microphone permission
  /// - Returns: Whether permission was granted
  func requestPermission() async -> Bool {
    let granted = await AVAudioApplication.requestRecordPermission()
    permissionStatus = granted ? .granted : .denied
    
    Logger.log(
      "Microphone permission: \(granted ? "granted" : "denied")",
      category: Logger.voice
    )
    
    return granted
  }
  
  // MARK: - Capture Control
  
  /// Start capturing audio and calling the provided callback with each buffer
  /// - Parameter callback: Called with each audio buffer as it's captured
  func startCapture(callback: @escaping AudioBufferCallback) async throws {
    // Check permission first
    if permissionStatus != .granted {
      let granted = await requestPermission()
      if !granted {
        throw CaptureError.permissionDenied
      }
    }
    
    // Stop any existing capture
    if isCapturing {
      stopCapture()
    }
    
    error = nil
    audioBufferCallback = callback
    
    // Set up audio session (iOS only)
    #if os(iOS)
      do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true)
      } catch {
        Logger.log(
          "Failed to set up audio session: \(error.localizedDescription)",
          level: .error,
          category: Logger.voice
        )
        throw CaptureError.sessionSetupFailed
      }
    #endif
    
    // Create audio engine
    let engine = AVAudioEngine()
    let input = engine.inputNode
    inputNode = input
    
    // Get the input format
    let inputFormat = input.inputFormat(forBus: 0)
    
    // Create target format: 16kHz, mono, Float32
    guard let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: targetSampleRate,
      channels: targetChannels,
      interleaved: false
    ) else {
      throw CaptureError.captureFailed("Failed to create audio format")
    }
    
    audioFormat = format
    
    // Create converter if needed
    let converter: AVAudioConverter?
    if inputFormat.sampleRate != targetSampleRate || inputFormat.channelCount != targetChannels {
      converter = AVAudioConverter(from: inputFormat, to: format)
    } else {
      converter = nil
    }
    
    // Install tap on input node
    input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
      Task { @MainActor [weak self] in
        guard let self = self, self.isCapturing else { return }
        
        // Convert buffer if needed
        if let converter = converter {
          guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * targetSampleRate / inputFormat.sampleRate)
          ) else {
            return
          }
          
          var error: NSError?
          // Capture buffer in a way that's safe for Sendable closure
          let bufferToConvert = buffer
          let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return bufferToConvert
          }
          
          converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
          
          if let error = error {
            Logger.log(
              "Audio conversion error: \(error.localizedDescription)",
              level: .error,
              category: Logger.voice
            )
            return
          }
          
          // Update audio level
          self.updateAudioLevel(from: convertedBuffer)
          
          // Call callback with converted buffer
          self.audioBufferCallback?(convertedBuffer)
        } else {
          // No conversion needed
          self.updateAudioLevel(from: buffer)
          self.audioBufferCallback?(buffer)
        }
      }
    }
    
    // Prepare and start engine
    engine.prepare()
    
    do {
      try engine.start()
      audioEngine = engine
      isCapturing = true
      
      // Start audio level monitoring
      startLevelMonitoring()
      
      Logger.log("Started audio capture", category: Logger.voice)
      
      // Haptic feedback
      HapticFeedback.impact(style: .light)
    } catch {
      Logger.log(
        "Failed to start audio engine: \(error.localizedDescription)",
        level: .error,
        category: Logger.voice
      )
      input.removeTap(onBus: 0)
      throw CaptureError.engineStartFailed
    }
  }
  
  /// Stop capturing audio
  func stopCapture() {
    guard isCapturing else { return }
    
    // Stop engine
    audioEngine?.stop()
    inputNode?.removeTap(onBus: 0)
    
    // Cleanup
    audioEngine = nil
    inputNode = nil
    audioFormat = nil
    audioBufferCallback = nil
    isCapturing = false
    
    stopLevelMonitoring()
    
    // Deactivate audio session (iOS only)
    #if os(iOS)
      do {
        try AVAudioSession.sharedInstance().setActive(false)
      } catch {
        Logger.log(
          "Failed to deactivate audio session: \(error.localizedDescription)",
          level: .error,
          category: Logger.voice
        )
      }
    #endif
    
    // Haptic feedback
    HapticFeedback.impact(style: .medium)
    
    Logger.log("Stopped audio capture", category: Logger.voice)
  }
  
  /// Cancel the current capture
  func cancelCapture() {
    stopCapture()
    
    Logger.log("Audio capture cancelled", category: Logger.voice)
    HapticFeedback.notification(.warning)
  }
  
  // MARK: - Audio Level Monitoring
  
  private func startLevelMonitoring() {
    levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self = self, self.isCapturing else { return }
        // Audio level is updated in the tap callback
      }
    }
  }
  
  private func stopLevelMonitoring() {
    levelTimer?.invalidate()
    levelTimer = nil
    audioLevel = 0
  }
  
  private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData else { return }
    
    // Calculate RMS (Root Mean Square) for audio level
    let channel = channelData[0]
    var sum: Float = 0
    let frameLength = Int(buffer.frameLength)
    
    for i in 0..<frameLength {
      let sample = channel[i]
      sum += sample * sample
    }
    
    let rms = sqrt(sum / Float(frameLength))
    
    // Normalize to 0-1 range (clamp to reasonable range)
    audioLevel = min(1.0, max(0.0, rms * 10.0))
  }
}

import Combine
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

// MARK: - Helper Styles
struct ScaleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
      .animation(AnimationUtilities.instant, value: configuration.isPressed)
  }
}

/// macOS-optimized button style with hover effects
struct MacButtonStyle: ButtonStyle {
  @State private var isHovered = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .opacity(isHovered ? 0.8 : 1.0)
      .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
      .animation(.easeInOut(duration: 0.1), value: isHovered)
      #if os(macOS)
        .onHover { hovering in
          isHovered = hovering
        }
      #endif
  }
}

/// Modifier that creates a spinning animation
private struct SpinningModifier: ViewModifier {
  @State private var isAnimating = false

  func body(content: Content) -> some View {
    content
      .rotationEffect(.degrees(isAnimating ? 360 : 0))
      .animation(
        .linear(duration: 1.0).repeatForever(autoreverses: false),
        value: isAnimating
      )
      .onAppear {
        isAnimating = true
      }
  }
}

@MainActor
struct ChatInputView: View {
  @Binding var text: String
  let isSending: Bool
  let onSend: () -> Void
  var onStop: (() -> Void)? = nil
  var isFocused: FocusState<Bool>.Binding
  let supportsReasoning: Bool
  @Binding var reasoningMode: ReasoningMode
  var conversationLanguage: DetectedLanguage? = nil
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ObservedObject private var presetManager = PresetManager.shared
  @Namespace private var animationNamespace

  // MARK: - Voice Input State
  var isVoiceRecording: Bool = false
  var isVoiceAvailable: Bool = true
  var isWhisperDownloading: Bool = false
  var whisperDownloadProgress: Double = 0
  var isWhisperLoading: Bool = false  // Model is being loaded/initialized
  var whisperLoadingProgress: Double = 0
  var voiceAudioLevel: Float = 0
  var onVoiceTap: (() -> Void)? = nil
  var onVoiceCancel: (() -> Void)? = nil
  var onTranscriptionStop: (() -> Void)? = nil

  // MARK: - Document Add Functionality
  var onAddDocument: (() -> Void)? = nil

  private var textAlignment: TextAlignment { .leading }
  private var frameAlignment: Alignment { .leading }

  private var layoutDirection: LayoutDirection {
    switch conversationLanguage {
    case .arabic: return .rightToLeft
    case .english: return .leftToRight
    case .unknown, nil: return RTLUtilities.layoutDirection
    }
  }

  private var hasText: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(spacing: 0) {
      // Row 1: Input Area (text field always visible)
      HStack(spacing: Space.sm) {
        // Text field (always visible, updates with transcription)
        textField
          .matchedGeometryEffect(id: "inputArea", in: animationNamespace)
      }
      #if os(macOS)
        .frame(minHeight: 32)
      #else
        .frame(minHeight: 44)
      #endif
      .padding(.top, Space.sm)
      .padding(.horizontal, Space.md)
      // Smooth animation for input field size changes
      .animation(AnimationUtilities.smooth, value: text.isEmpty)

      // Row 2: Action Buttons
      HStack(spacing: Space.sm) {
        // Left: Add & Genre (hidden during recording for cleaner look)
        if !isVoiceRecording {
          HStack(spacing: Space.sm) {

            // Genre/Preset Selector (Context Menu)
            Menu {
              ForEach(Preset.allCases) { preset in
                Button {
                  presetManager.selectPreset(preset)
                } label: {
                  Label(preset.displayName, systemImage: preset.icon)
                }
              }
            } label: {
              // Dynamic Icon based on Active Preset
              Image(systemName: presetManager.activePreset.icon)
                .font(TypeScale.title)
                .foregroundStyle(Brand.textPrimary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(PS.choose_how_to_use)
            .id("preset_menu_button")
          }
          .transition(.opacity.combined(with: .move(edge: .leading)))

          // Add Document
          Button(action: {
            HapticFeedback.selection()
            onAddDocument?()
          }) {
            Image(systemName: "plus")
              .font(TypeScale.title)
              .foregroundStyle(Brand.textPrimary)
              .frame(width: 40, height: 40)
              .contentShape(Circle())
          }
          .buttonStyle(ScaleButtonStyle())
          .accessibilityLabel(L("add_document"))
        }

        // Recording: Cancel button on left with liquid glass feel
        if isVoiceRecording {
          Button(action: {
            HapticFeedback.impact(style: .light)
            onVoiceCancel?()
          }) {
            Image(systemName: "xmark")
              .font(TypeScale.title.weight(.semibold))  // Match the plus button font weight
              .foregroundStyle(Brand.error)
              .frame(width: 28, height: 28)
            // .contentShape(Circle())
            // .liquidGlassCircle(tintColor: Brand.textSecondary.opacity(0.15))
          }
          .buttonStyle(ScaleButtonStyle())
          .accessibilityLabel(L("cancel_recording"))
          .transition(
            .asymmetric(
              insertion: .scale(scale: 0.8).combined(with: .opacity),
              removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
        }

        // Center: Animated waveform (expands to fill space during recording)
        if isVoiceRecording {
          recordingWaveform
            .transition(
              .asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
              ))
        } else {
          Spacer()
        }

        // Right: Waveform trigger (idle) & Send
        HStack(spacing: Space.sm) {
          // Waveform Button (Voice Trigger - idle state)
          if !isSending && !isVoiceRecording {
            Button(action: {
              HapticFeedback.selection()
              onVoiceTap?()
            }) {
              ZStack {
                if isWhisperDownloading || isWhisperLoading {
                  // Show circular progress when downloading or loading Whisper model
                  ZStack {
                    Circle()
                      .stroke(Brand.textSecondary.opacity(0.2), lineWidth: 2)
                    Circle()
                      .trim(
                        from: 0,
                        to: isWhisperDownloading ? whisperDownloadProgress : whisperLoadingProgress
                      )
                      .stroke(Brand.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                      .rotationEffect(.degrees(-90))
                      .animation(
                        .easeInOut(duration: 0.2),
                        value: isWhisperDownloading
                          ? whisperDownloadProgress : whisperLoadingProgress)

                    if isWhisperLoading && !isWhisperDownloading {
                      // Show spinning animation for loading (initializing model)
                      Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                          Brand.primary.opacity(0.5),
                          style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .modifier(SpinningModifier())
                    }

                    Image(systemName: "waveform")
                      .font(.system(size: 14, weight: .medium))
                      .foregroundStyle(Brand.textSecondary)
                  }
                  .frame(width: 28, height: 28)
                } else {
                  Image(systemName: "waveform")
                    .font(TypeScale.title)
                    .foregroundStyle(Brand.textPrimary)
                }
              }
              .frame(width: 40, height: 40)
              .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!isVoiceAvailable || isWhisperDownloading || isWhisperLoading)
            .opacity(isVoiceAvailable && !isWhisperDownloading && !isWhisperLoading ? 1.0 : 0.7)
            .transition(.scale.combined(with: .opacity))
          }

          // Main Action (Send / Stop / Confirm)
          ZStack {
            // Send Button (Idle)
            if !isSending && !isVoiceRecording {
              Button(action: {
                HapticFeedback.selection()
                handleSend()
              }) {
                Image(systemName: "arrow.up")
                  .font(TypeScale.headline.weight(.bold))
                  .foregroundStyle(.white)
                  .frame(width: 36, height: 36)  // Compact Send Button
                  .background(
                    Circle()
                      .fill(Brand.primary)
                  )
              }
              .buttonStyle(ScaleButtonStyle())
              .disabled(!hasText)
              .opacity(hasText ? 1.0 : 0.5)
              .transition(.scale.combined(with: .opacity))
            }

            // Stop Button (Busy - AI generating)
            if isSending {
              Button(action: {
                HapticFeedback.selection()
                onStop?()
              }) {
                Image(systemName: "stop.fill")
                  .font(TypeScale.headline.weight(.bold))
                  .foregroundStyle(Brand.textPrimary)
                  .frame(width: 36, height: 36)
                  .liquidGlassCircle(tintColor: Brand.surfaceElevated.opacity(0.5))
                  .overlay(
                    Circle()
                      .stroke(Brand.textSecondary.opacity(0.2), lineWidth: 1)
                  )
              }
              .buttonStyle(ScaleButtonStyle())
              .accessibilityLabel(L("stop_generation"))
              .accessibilityHint(L("stops_current_generation"))
              .transition(.scale.combined(with: .opacity))
            }

            // Confirm Recording Button (Stop and send transcription)
            if isVoiceRecording {
              Button(action: {
                HapticFeedback.selection()
                // During recording, send button stops transcription and sends
                handleSend()
              }) {
                Image(systemName: "arrow.up")
                  .font(TypeScale.headline.weight(.bold))
                  .foregroundStyle(.white)
                  .frame(width: 36, height: 36)
                  .background(
                    Circle()
                      .fill(Brand.primary)
                  )
              }
              .buttonStyle(ScaleButtonStyle())
              .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
              .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
              .accessibilityLabel(L("voice_stop_and_send"))
              .accessibilityHint(L("voice_stops_recording_and_sends"))
              .transition(.scale.combined(with: .opacity))
            }
          }
        }
      }
      .padding(.horizontal, Space.md)
      .padding(.bottom, Space.md)
      .animation(AnimationUtilities.transition, value: isVoiceRecording)
    }
    .liquidGlass(cornerRadius: Radius.xl)
    .environment(\.layoutDirection, layoutDirection)
    .ignoresSafeArea(.keyboard, edges: .bottom)
    .modifier(PlatformInputPadding())
  }
}

// MARK: - Platform Input Padding Modifier

struct PlatformInputPadding: ViewModifier {
  #if os(macOS)
    func body(content: Content) -> some View {
      content
        .padding(.horizontal, AdaptiveLayout.standardSpacing)
        .padding(.bottom, AdaptiveLayout.standardSpacing)
    }
  #elseif os(iOS)
    func body(content: Content) -> some View {
      content.modifier(iOSInputPadding())
    }
  #else
    func body(content: Content) -> some View {
      content
    }
  #endif
}

#if os(iOS)
  struct iOSInputPadding: ViewModifier {
    @MainActor
    func body(content: Content) -> some View {
      if DeviceType.runtimeCurrent == .iPad {
        content
          .padding(.horizontal, AdaptiveLayout.standardSpacing)
          .padding(.bottom, AdaptiveLayout.standardSpacing)
      } else {
        content
      }
    }
  }

  struct iOSTextFieldPadding: ViewModifier {
    @MainActor
    func body(content: Content) -> some View {
      if DeviceType.runtimeCurrent == .iPad {
        content
          .padding(.vertical, Space.sm)
          .padding(.horizontal, Space.md)
      } else {
        content
          .padding(.vertical, Space.xs)
      }
    }
  }
#endif

extension ChatInputView {
  // MARK: - Recording Waveform

  /// Beautiful, smooth, expanded waveform for recording state with liquid glass feel
  private var recordingWaveform: some View {
    HStack(spacing: Space.sm) {
      // Expanded waveform with more bars and liquid glass effect
      ExpandedWaveformView(audioLevel: voiceAudioLevel)
        .frame(maxWidth: .infinity)
        .frame(height: 28)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, Space.xs)
    .padding(.vertical, Space.xs)
    .animation(AnimationUtilities.smooth, value: voiceAudioLevel)
  }

  // MARK: - Text Field

  private var textField: some View {
    #if os(macOS)
      // macOS: Use TextEditor for multi-line with better keyboard handling
      ZStack(alignment: .topLeading) {
        if text.isEmpty {
          Text(L("ask_me_anything_hint"))
            .foregroundStyle(Brand.textSecondary.opacity(0.6))
            .font(TypeScale.body)
            .padding(.vertical, Space.sm)
            .padding(.horizontal, Space.md)
            .allowsHitTesting(false)
        }

        TextEditor(text: $text)
          .font(TypeScale.body)
          .scrollContentBackground(.hidden)
          .background(Color.clear)
          #if os(macOS)
            .frame(minHeight: 24, maxHeight: 100)
          #else
            .frame(minHeight: 32, maxHeight: 200)
          #endif
          .padding(.vertical, Space.sm)
          .padding(.horizontal, Space.md)
      }
      .frame(maxWidth: .infinity, alignment: frameAlignment)
      .environment(\.layoutDirection, layoutDirection)
      .accessibilityLabel(L("message_input"))
      .accessibilityHint(L("type_your_message_cmd_enter"))
      // Keyboard shortcut: Cmd+Enter to send
      .background(
        Button(action: {
          handleSend()
        }) {
          EmptyView()
        }
        .keyboardShortcut(.return, modifiers: .command)
        .opacity(0)
      )
    #elseif os(iOS)
      // iOS: Standard text field (works for both iPhone and iPad)
      TextField(L("ask_me_anything_hint"), text: $text, axis: .vertical)
        .focused(isFocused)
        .textInputAutocapitalization(.sentences)
        .disableAutocorrection(true)
        .submitLabel(.send)
        .lineLimit(1...10)
        .multilineTextAlignment(textAlignment)
        .font(TypeScale.body)
        .padding(.vertical, Space.xs)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .environment(\.layoutDirection, layoutDirection)
        .accessibilityLabel(L("message_input"))
        .accessibilityHint(L("type_your_message"))
        .onSubmit {
          handleSend()
          isFocused.wrappedValue = false
        }
        .modifier(iOSTextFieldPadding())
    #else
      TextField(L("ask_me_anything_hint"), text: $text, axis: .vertical)
        .focused(isFocused)
        .textInputAutocapitalization(.sentences)
        .disableAutocorrection(true)
        .submitLabel(.send)
        .lineLimit(1...10)
        .multilineTextAlignment(textAlignment)
        .font(TypeScale.body)
        .padding(.vertical, Space.xs)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .environment(\.layoutDirection, layoutDirection)
        .accessibilityLabel(L("message_input"))
        .accessibilityHint(L("type_your_message"))
        .onSubmit {
          handleSend()
          isFocused.wrappedValue = false
        }
    #endif
  }

  /// Platform-appropriate button size
  private var buttonSize: CGFloat {
    #if os(macOS)
      return 32
    #else
      return 40
    #endif
  }

  /// Whether voice input is available on this platform
  private var voiceAvailableOnPlatform: Bool {
    #if os(macOS)
      return false  // Voice input not supported on macOS yet
    #else
      return isVoiceAvailable
    #endif
  }

  private func handleSend() {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    onSend()
  }
}

// MARK: - Waveform View

private struct WaveformView: View {
  let audioLevel: Float
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var wavePhase: Double = 0
  @State private var animationTask: Task<Void, Never>?

  private let barCount = 7
  private let minBarHeight: CGFloat = 3
  private let maxBarHeight: CGFloat = 18
  private let barWidth: CGFloat = 2.5
  private let barSpacing: CGFloat = 3

  var body: some View {
    HStack(spacing: barSpacing) {
      ForEach(0..<barCount, id: \.self) { index in
        WaveformBar(
          index: index,
          audioLevel: audioLevel,
          wavePhase: wavePhase,
          minHeight: minBarHeight,
          maxHeight: maxBarHeight,
          width: barWidth,
          reduceMotion: reduceMotion
        )
      }
    }
    .frame(height: maxBarHeight)
    .onAppear {
      if !reduceMotion {
        startWaveAnimation()
      }
    }
    .onDisappear {
      animationTask?.cancel()
      animationTask = nil
    }
    .onChange(of: reduceMotion) { _, newValue in
      if newValue {
        animationTask?.cancel()
        animationTask = nil
        wavePhase = 0
      } else {
        startWaveAnimation()
      }
    }
  }

  private func startWaveAnimation() {
    animationTask?.cancel()
    animationTask = Task { @MainActor in
      while !Task.isCancelled && !reduceMotion {
        // Smooth continuous wave animation
        withAnimation(.linear(duration: 0.08)) {
          wavePhase += 0.15
          if wavePhase > .pi * 2 {
            wavePhase = 0
          }
        }
        try? await Task.sleep(nanoseconds: 80_000_000)  // ~120Hz frame rate
      }
    }
  }
}

// MARK: - Waveform Bar

private struct WaveformBar: View {
  let index: Int
  let audioLevel: Float
  let wavePhase: Double
  let minHeight: CGFloat
  let maxHeight: CGFloat
  let width: CGFloat
  let reduceMotion: Bool

  private var barHeight: CGFloat {
    // Base audio level contribution (70%)
    let audioContribution = CGFloat(audioLevel) * 0.7

    // Wave pattern contribution (30%) - creates flowing wave effect
    // Each bar has a phase offset to create wave motion across bars
    let phaseOffset = Double(index) * 0.6
    let wave = (sin(wavePhase + phaseOffset) + 1.0) * 0.5  // 0.0 to 1.0
    let waveContribution = CGFloat(wave) * 0.3

    // Combine contributions
    let combinedLevel = audioContribution + waveContribution

    // Map to height range with smooth curve
    let normalizedLevel = pow(combinedLevel, 0.8)  // Slight curve for more natural feel
    let height = minHeight + (maxHeight - minHeight) * normalizedLevel

    // Ensure minimum visible height when audio is present
    if audioLevel > 0.03 {
      return max(height, minHeight + 1)
    }
    return minHeight
  }

  var body: some View {
    RoundedRectangle(cornerRadius: width / 2)
      .fill(Brand.primary)
      .frame(width: width)
      .frame(height: barHeight)
      .animation(
        reduceMotion ? nil : AnimationUtilities.responsive,
        value: audioLevel
      )
      .animation(
        reduceMotion ? nil : .linear(duration: 0.08),
        value: wavePhase
      )
  }
}

// MARK: - Expanded Waveform View (for recording state)

private struct ExpandedWaveformView: View, Animatable {
  var audioLevel: Float
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var animatableData: Float {
    get { audioLevel }
    set { audioLevel = newValue }
  }

  var body: some View {
    if reduceMotion {
      reducedMotionView
    } else {
      animatedWaveformView
    }
  }

  private var reducedMotionView: some View {
    RoundedRectangle(cornerRadius: Radius.sm)
      .fill(Brand.primary.opacity(0.5))
      .frame(height: 8 + CGFloat(audioLevel) * 24)
      .frame(maxWidth: .infinity)
      .animation(.linear(duration: 0.1), value: audioLevel)
      .accessibilityLabel(L("voice_recording_indicator"))
  }

  private var animatedWaveformView: some View {
    TimelineView(.animation) { timeline in
      Canvas { context, size in
        let timeValue = timeline.date.timeIntervalSinceReferenceDate
        drawWaveform(context: context, size: size, time: timeValue)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(backgroundView)
  }

  private var backgroundView: some View {
    Capsule()
      .fill(Brand.primary.opacity(0.06))
      .blur(radius: 12)
  }

  private func drawWaveform(context: GraphicsContext, size: CGSize, time: TimeInterval) {
    let width = size.width
    let height = size.height
    let midHeight = height / 2.0

    // Calculate amplitude
    let baseAmplitude = height * 0.4
    let visualLevel = pow(Double(audioLevel), 0.8)
    let targetAmplitude = CGFloat(max(0.1, visualLevel * 1.5)) * baseAmplitude

    // Draw particles
    if audioLevel > 0.05 {
      drawParticles(
        context: context, width: width, height: height, time: time, audioLevel: audioLevel)
    }

    // Draw wave layers
    for i in 0..<3 {
      drawWaveLayer(
        context: context, layerIndex: i, width: width, midHeight: midHeight, height: height,
        time: time, targetAmplitude: targetAmplitude)
    }
  }

  private func drawParticles(
    context: GraphicsContext, width: CGFloat, height: CGFloat, time: TimeInterval, audioLevel: Float
  ) {
    let particleCount = 8
    for i in 0..<particleCount {
      let seed = Double(i) * 13.0
      let cycleSpeed = 0.5 + (seed.truncatingRemainder(dividingBy: 0.5))
      let particleTime = time * cycleSpeed + seed
      let cyclePos = particleTime.truncatingRemainder(dividingBy: 1.0)

      let xBase = (seed * 100.0).truncatingRemainder(dividingBy: width)
      let xSway = sin(time * 2.0 + seed) * 10.0
      let x = xBase + xSway
      let y = height - (CGFloat(cyclePos) * height)

      let particleSize = 2.0 + sin(particleTime * 5.0) * 1.0
      let opacity = sin(cyclePos * .pi) * 0.4 * Double(audioLevel * 3.0)

      if opacity > 0.05 {
        let rect = CGRect(x: x, y: y, width: particleSize, height: particleSize)
        context.fill(
          Circle().path(in: rect),
          with: .color(Brand.primary.opacity(opacity))
        )
      }
    }
  }

  private func drawWaveLayer(
    context: GraphicsContext, layerIndex: Int, width: CGFloat, midHeight: CGFloat, height: CGFloat,
    time: TimeInterval, targetAmplitude: CGFloat
  ) {
    var path = Path()
    path.move(to: CGPoint(x: 0, y: midHeight))

    let iFloat = Double(layerIndex)
    let speed = 2.5 + iFloat
    let frequency = (1.5 + iFloat * 0.3) / width * 300.0
    let phaseOffset = iFloat * 2.5
    let waveTime = time * speed + phaseOffset

    for x in stride(from: 0, to: width, by: 2) {
      let normalizedX = x / width
      let sine1 = sin(x * .pi / 180 * frequency + waveTime)
      let sine2 = sin(x * .pi / 180 * (frequency * 2.5) + waveTime * 1.3)
      let combinedSine = (sine1 + sine2 * 0.4) / 1.4
      let taper = sin(normalizedX * .pi)
      let y = midHeight + combinedSine * targetAmplitude * taper
      path.addLine(to: CGPoint(x: x, y: y))
    }

    let opacity = 0.8 - (iFloat * 0.2)
    let lineWidth = layerIndex == 0 ? 2.5 : 1.5

    if layerIndex == 0 {
      var fillPath = path
      fillPath.addLine(to: CGPoint(x: width, y: height))
      fillPath.addLine(to: CGPoint(x: 0, y: height))
      fillPath.closeSubpath()

      let gradient = Gradient(colors: [
        Brand.primary.opacity(0.2),
        Brand.primary.opacity(0.0),
      ])
      context.fill(
        fillPath,
        with: .linearGradient(
          gradient,
          startPoint: CGPoint(x: width / 2, y: midHeight),
          endPoint: CGPoint(x: width / 2, y: height)
        )
      )
    }

    let strokeGradient = Gradient(colors: [
      Brand.primary.opacity(opacity * 0.3),
      Brand.primary.opacity(opacity),
      Brand.primary.opacity(opacity * 0.3),
    ])
    context.stroke(
      path,
      with: .linearGradient(
        strokeGradient,
        startPoint: CGPoint(x: 0, y: midHeight),
        endPoint: CGPoint(x: width, y: midHeight)
      ),
      lineWidth: lineWidth
    )
  }
}

import SwiftUI

struct AnimatedWaveView: View {
  var color: Color = Brand.primary
  var size: CGFloat = 120
  @State private var phase: Double = 0
  
  var body: some View {
    ZStack {
      // Wave 1 - Primary
      SineWaveShape(phase: phase, amplitude: size * 0.15, frequency: 1.0)
        .stroke(color, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
        .frame(width: size, height: size * 0.6)
        .offset(y: size * 0.12)
      
      // Wave 2 - Secondary
      SineWaveShape(phase: phase + 1.5, amplitude: size * 0.12, frequency: 1.2)
        .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
        .frame(width: size, height: size * 0.6)
      
      // Wave 3 - Tertiary
      SineWaveShape(phase: phase + 3.0, amplitude: size * 0.1, frequency: 1.4)
        .stroke(color.opacity(0.4), style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round))
        .frame(width: size, height: size * 0.6)
        .offset(y: -size * 0.1)
    }
    .onAppear {
      withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
        phase = .pi * 2
      }
    }
  }
}

struct SineWaveShape: Shape {
  var phase: Double
  var amplitude: CGFloat
  var frequency: Double
  
  var animatableData: Double {
    get { phase }
    set { phase = newValue }
  }
  
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let width = rect.width
    let height = rect.height
    let midHeight = height / 2
    
    // Start path
    path.move(to: CGPoint(x: 0, y: midHeight + sin(phase) * amplitude))
    
    // Draw sine wave
    for x in stride(from: 0, through: width, by: 2) {
      let relativeX = x / width
      let angle = relativeX * 2 * .pi * frequency + phase
      let y = midHeight + sin(angle) * amplitude
      path.addLine(to: CGPoint(x: x, y: y))
    }
    
    return path
  }
}

#Preview {
  ZStack {
    Color.black.ignoresSafeArea()
    AnimatedWaveView(color: .white, size: 200)
  }
}

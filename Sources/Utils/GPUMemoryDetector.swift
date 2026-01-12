import Foundation
import Metal

/// Result of GPU configuration calculation
struct GPUConfiguration {
  let gpuLayers: Int
  let useMmap: Bool

  static let cpuOnly = GPUConfiguration(gpuLayers: 0, useMmap: true)
}

/// Utility for detecting GPU memory and calculating optimal GPU offload layers
enum GPUMemoryDetector {
  /// Safety margin for GPU memory usage (use 70% of available when mmap is disabled)
  private static let safetyMargin: Double = 0.70

  /// Estimated memory overhead for KV cache and compute buffers per layer (MB)
  private static let perLayerOverheadMB: Double = 25.0

  /// Base overhead for Metal compute pipelines and context (MB)
  private static let baseOverheadMB: Double = 400.0

  /// Threshold for model-to-GPU ratio above which mmap should be disabled
  private static let mmapDisableThreshold: Double = 0.70

  /// Returns the recommended max working set size for GPU in bytes
  /// This is the maximum amount of memory the GPU can use efficiently
  static func getRecommendedGPUMemoryBytes() -> Int64 {
    guard let device = MTLCreateSystemDefaultDevice() else {
      Logger.log(
        "Metal device not available, falling back to CPU-only mode",
        level: .error,
        category: Logger.engine
      )
      return 0
    }

    return Int64(device.recommendedMaxWorkingSetSize)
  }

  /// Returns the recommended max working set size for GPU in MB
  static func getRecommendedGPUMemoryMB() -> Int {
    return Int(getRecommendedGPUMemoryBytes() / 1_048_576)
  }

  /// Returns usable GPU memory after applying safety margin (MB)
  static func getUsableGPUMemoryMB() -> Int {
    let total = Double(getRecommendedGPUMemoryMB())
    let usable = total * safetyMargin - baseOverheadMB
    return max(0, Int(usable))
  }

  /// Calculates optimal GPU configuration for a model based on available GPU memory
  /// - Parameters:
  ///   - modelSizeBytes: Size of the model file in bytes
  ///   - totalLayers: Total number of layers in the model (default 32 for most LLaMA-based models)
  ///   - requestedLayers: The number of layers requested by the model configuration
  /// - Returns: GPUConfiguration with optimal GPU layers and mmap setting
  static func calculateOptimalGPUConfig(
    modelSizeBytes: Int64,
    totalLayers: Int = 32,
    requestedLayers: Int = 20
  ) -> GPUConfiguration {
    let recommendedMB = getRecommendedGPUMemoryMB()
    let usableMemoryMB = getUsableGPUMemoryMB()

    // If no GPU memory available, use CPU only
    guard usableMemoryMB > 0 else {
      Logger.log(
        "No usable GPU memory detected, using CPU-only mode",
        category: Logger.engine
      )
      return .cpuOnly
    }

    // Calculate model size in MB
    let modelSizeMB = Double(modelSizeBytes) / 1_048_576.0
    let modelToGPURatio = modelSizeMB / Double(recommendedMB)

    // For large models relative to GPU memory, use minimal GPU layers with mmap enabled
    // Disabling mmap causes the model to load into RAM which increases total memory pressure
    // and can trigger iOS jetsam (signal 9). Better to keep mmap and use few GPU layers.
    if modelToGPURatio > mmapDisableThreshold {
      // Use minimal GPU layers to reduce Metal buffer allocation
      // Even 2-4 layers gives some GPU acceleration for key operations
      let minimalLayers = 4

      Logger.log(
        "GPU config: Large model (ratio=\(String(format: "%.2f", modelToGPURatio))), "
          + "using minimal GPU layers=\(minimalLayers) with mmap enabled",
        level: .info,
        category: Logger.engine
      )

      return GPUConfiguration(gpuLayers: minimalLayers, useMmap: true)
    }

    // For smaller models, use normal mmap with calculated layers
    let perLayerWeightsMB = modelSizeMB / Double(totalLayers)
    let perLayerTotalMB = perLayerWeightsMB + perLayerOverheadMB
    let maxLayers = Int(Double(usableMemoryMB) / perLayerTotalMB)
    let optimalLayers = min(maxLayers, min(requestedLayers, totalLayers))
    let finalLayers = max(0, optimalLayers)

    Logger.log(
      "GPU config: recommendedMB=\(recommendedMB), usableMemoryMB=\(usableMemoryMB), "
        + "modelSizeMB=\(Int(modelSizeMB)), gpuLayers=\(finalLayers), useMmap=true",
      category: Logger.engine
    )

    return GPUConfiguration(gpuLayers: finalLayers, useMmap: true)
  }

  /// Returns device GPU info for diagnostics
  static func getGPUInfo() -> String {
    guard let device = MTLCreateSystemDefaultDevice() else {
      return "Metal not available"
    }

    let recommendedMB = getRecommendedGPUMemoryMB()
    let usableMB = getUsableGPUMemoryMB()

    return "GPU: \(device.name), Recommended: \(recommendedMB) MB, Usable: \(usableMB) MB"
  }
}

import Foundation

/// Policy for inspecting and limiting network request payloads.
public struct PayloadPolicy: Sendable {
    public let maxPayloadSize: Int
    public let blockBase64Content: Bool
    public let base64SampleThreshold: Double

    public init(
        maxPayloadSize: Int = 10_485_760,
        blockBase64Content: Bool = true,
        base64SampleThreshold: Double = 0.7
    ) {
        self.maxPayloadSize = maxPayloadSize
        self.blockBase64Content = blockBase64Content
        self.base64SampleThreshold = base64SampleThreshold
    }
}

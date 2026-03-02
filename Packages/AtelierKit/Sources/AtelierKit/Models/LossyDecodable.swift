/// Wrapper that absorbs decoding failures for individual array elements.
///
/// Use with `[LossyDecodable<T>]` to decode arrays fault-tolerantly:
/// elements that fail to decode become `nil` instead of failing the
/// entire array. Follow with `.compactMap(\.value)` to get `[T]`.
struct LossyDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

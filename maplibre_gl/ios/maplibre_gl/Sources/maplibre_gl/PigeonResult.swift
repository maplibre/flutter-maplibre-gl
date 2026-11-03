import Flutter
import Foundation

/// Answers a Pigeon completion from code written against `FlutterResult`, so
/// the existing handlers keep their signatures. Only the first answer is
/// delivered: a second one would be a second reply to the same message.
func voidResult(_ completion: @escaping (Result<Void, Error>) -> Void) -> FlutterResult {
    pigeonResult(completion) { _ in () }
}

/// Turns a `FlutterResult` answer into a Pigeon completion: a `FlutterError`
/// and `FlutterMethodNotImplemented` fail it, anything else goes through
/// `convert`, and a `convert` that throws fails it too. Only the first answer
/// is delivered.
func pigeonResult<T>(
    _ completion: @escaping (Result<T, Error>) -> Void,
    convert: @escaping (Any?) throws -> T
) -> FlutterResult {
    var answered = false
    return { value in
        guard !answered else { return }
        answered = true
        if let error = value as? FlutterError {
            completion(.failure(PigeonError(
                code: error.code,
                message: error.message,
                details: error.details as? String
            )))
        } else if let object = value as? NSObject, object === FlutterMethodNotImplemented {
            completion(.failure(PigeonError(
                code: "notImplemented",
                message: "Not implemented on iOS.",
                details: nil
            )))
        } else {
            // A value convert cannot read fails the call, as on Android,
            // instead of reaching Dart as something it cannot parse.
            let converted: T
            do {
                converted = try convert(value)
            } catch {
                completion(.failure(error as? PigeonError ?? PigeonError(
                    code: "error",
                    message: "\(error)",
                    details: nil
                )))
                return
            }
            completion(.success(converted))
        }
    }
}

import Flutter
import MapLibre

/*
 *  Answers `camera#animate` and `camera#ease` the way Android and web do: true once the camera
 *  arrives, false when something cuts the animation short first, such as another camera call, a
 *  gesture or new content insets.
 *
 *  MLNMapView runs the completion handler of `setCamera` and `fly(to:)` both when the animation
 *  ends and when it is cancelled, with nothing telling the two apart. Comparing the final camera
 *  with the requested one is not enough either: a target beyond the zoom limits, or a latitude
 *  the map cannot center at that zoom, arrives clamped. What does tell them apart is
 *  MLNMapView's `cancelTransitions`, which every gesture and every camera call runs before it
 *  moves the camera, the same place where the Android SDK reports onCancel. It flags the change
 *  it causes with `.transitionCancelled`, and the `regionDidChange` that ends the animation
 *  carries the flag synchronously, before the completion handler runs on a later turn of the
 *  main queue. So the outcome is settled there, and the completion handler only answers.
 *
 *  While a gesture is in progress MLNMapView holds `regionDidChange` back, so two more signals
 *  count as an interruption: the reason of the change naming a gesture, and `shouldChangeFrom`,
 *  which every gesture asks right after cancelling the running animation.
 */
final class CameraAnimationTracker {
    private final class Animation {
        let result: FlutterResult
        var interrupted = false

        init(result: @escaping FlutterResult) {
            self.result = result
        }
    }

    /// Change reasons that mean the running animation did not arrive.
    private static let interruptingReasons: MLNCameraChangeReason = [
        .transitionCancelled,
        .gesturePan,
        .gesturePinch,
        .gestureRotate,
        .gestureZoomIn,
        .gestureZoomOut,
        .gestureOneFingerZoom,
        .gestureTilt,
    ]

    /// The animation moving the camera, until it ends or is interrupted.
    private var running: Animation?
    /// Whether a start call is in progress, and whether its animation already ended in it.
    private var isStarting = false
    private var endedWhileStarting = false

    /// Starts an animation and answers `result` with whether the camera arrived. `start` must
    /// pass the completion handler it gets to MLNMapView.
    func track(result: @escaping FlutterResult, start: (@escaping () -> Void) -> Void) {
        // The new animation stops the running one, as on Android and web.
        interruptRunning()
        let animation = Animation(result: result)
        isStarting = true
        endedWhileStarting = false
        start { [weak self] in
            if self?.running === animation {
                self?.running = nil
            }
            animation.result(!animation.interrupted)
        }
        isStarting = false
        // A zero duration ends inside the start call, and nothing can cut it short any more.
        if !endedWhileStarting {
            running = animation
        }
    }

    /// Marks the running animation as cut short, by a camera call or a gesture. Called before the
    /// call moves the camera, so it also covers one MLNMapView does not flag, such as a
    /// `camera#move` to where the camera already is.
    func interruptRunning() {
        running?.interrupted = true
        running = nil
    }

    /// Call from `mapView(_:regionDidChangeWith:animated:)`.
    func regionDidChange(reason: MLNCameraChangeReason, animated: Bool) {
        if isStarting {
            // Inside a start call, a cancelled change is the previous animation being stopped,
            // already settled by interruptRunning. Any other is the new one ending at once.
            if !reason.contains(.transitionCancelled) {
                endedWhileStarting = true
            }
            return
        }
        guard let animation = running else { return }
        // A resize of the view moves the camera at once without ending the animation, and its
        // change still reads as programmatic. Only an animated change or an interrupting reason
        // ends it; a gesture ends without animation when it does not drift.
        if !animated && reason.isDisjoint(with: Self.interruptingReasons) {
            return
        }
        running = nil
        if !reason.isDisjoint(with: Self.interruptingReasons) {
            animation.interrupted = true
        }
    }
}

import Flutter
import Foundation
import MapLibre
import UIKit

public class MapSnapshotter: NSObject {
    private var snapshotter: MLNMapSnapshotter?
    private var result: FlutterResult?
    private var channel: FlutterMethodChannel?
    
    public init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }
    
    public func startSnapshot(
        arguments: [String: Any],
        result: @escaping FlutterResult
    ) {
        self.result = result
        
        guard let width = arguments["width"] as? Int,
              let height = arguments["height"] as? Int,
              let styleUrl = arguments["styleUrl"] as? String,
              let cameraPosition = arguments["cameraPosition"] as? [String: Any]
        else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing required arguments",
                details: nil
            ))
            return
        }
        
        let size = CGSize(width: width, height: height)
        let camera = MLNMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 0, longitude: 0), fromDistance: 1000, pitch: 0, heading: 0)
        let options = MLNMapSnapshotOptions(styleURL: URL(string: styleUrl)!, camera: camera, size: size)
        
        // Configure camera
        if let zoom = cameraPosition["zoom"] as? Double {
            print("Setting zoom level to: \(zoom)")
            options.zoomLevel = zoom
        }
        
        if let center = cameraPosition["target"] as? [String: Double],
           let lat = center["latitude"],
           let lng = center["longitude"] {
            options.camera.centerCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        
        // Create snapshotter
        snapshotter = MLNMapSnapshotter(options: options)
        
        // Start snapshot
        snapshotter?.start { (snapshot, error) in
            if let error = error {
                self.result?(FlutterError(
                    code: "SNAPSHOT_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
                return
            }
            
            guard let snapshot = snapshot else {
                self.result?(FlutterError(
                    code: "SNAPSHOT_ERROR",
                    message: "Failed to generate snapshot",
                    details: nil
                ))
                return
            }
            
            // Convert snapshot to image data
            let image = snapshot.image
            
            // Add markers if provided
            var finalImage = image
            if let markers = arguments["markers"] as? [[String: Any]] {
                finalImage = self.addMarkers(to: image, markers: markers, snapshot: snapshot)
            }
            
            // Convert to PNG data
            guard let imageData = finalImage.pngData() else {
                self.result?(FlutterError(
                    code: "SNAPSHOT_ERROR",
                    message: "Failed to convert image to PNG",
                    details: nil
                ))
                return
            }
            
            // Return image data to Flutter
            self.result?(FlutterStandardTypedData(bytes: imageData))
        }
    }
    
    private func addMarkers(to image: UIImage, markers: [[String: Any]], snapshot: MLNMapSnapshot) -> UIImage {
        print("iOS image size: \(image.size), scale: \(image.scale)")
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(at: CGPoint.zero)
        
        let context = UIGraphicsGetCurrentContext()
        
        for marker in markers {
            guard let position = marker["position"] as? [String: Double],
                  let lat = position["latitude"],
                  let lng = position["longitude"],
                  let iconData = marker["iconData"] as? FlutterStandardTypedData,
                  let iconSize = marker["iconSize"] as? Double else {
                continue
            }
            
            // Convert marker coordinates to point on image
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let point = snapshot.point(for: coordinate)
            
            // Create icon from data
            guard let iconImage = UIImage(data: iconData.data) else { continue }
            print("iOS iconImage size: \(iconImage.size), scale: \(iconImage.scale)")
            
            // Use original icon size (already includes DPR from Flutter)
            let size = iconImage.size
            print("iOS marker - using original icon size: \(size.width)x\(size.height)")
            let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height)
            
            // Draw icon
            iconImage.draw(in: CGRect(origin: origin, size: size))
        }
        
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resultImage ?? image
    }
}
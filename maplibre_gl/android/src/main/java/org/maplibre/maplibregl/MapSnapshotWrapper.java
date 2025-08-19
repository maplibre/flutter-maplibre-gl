package org.maplibre.maplibregl;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PointF;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.flutter.plugin.common.MethodChannel;
import org.maplibre.android.snapshotter.MapSnapshot;
import org.maplibre.android.snapshotter.MapSnapshotter;
import org.maplibre.android.camera.CameraPosition;
import org.maplibre.android.geometry.LatLng;
import org.maplibre.android.maps.MapLibreMap;
import org.maplibre.android.maps.Style;
import org.maplibre.android.style.layers.PropertyValue;

import java.io.ByteArrayOutputStream;
import java.util.List;
import java.util.Map;

public class MapSnapshotWrapper {
    private static final String TAG = MapSnapshotWrapper.class.getSimpleName();
    
    private final MethodChannel channel;
    private final android.content.Context context;
    private MapSnapshotter snapshotter;
    private MethodChannel.Result result;
    
    public MapSnapshotWrapper(MethodChannel channel, android.content.Context context) {
        this.channel = channel;
        this.context = context;
    }
    
    public void startSnapshot(Map<String, Object> arguments, MethodChannel.Result result) {
        this.result = result;
        
        try {
            // Parse arguments
            Integer width = (Integer) arguments.get("width");
            Integer height = (Integer) arguments.get("height");
            String styleUrl = (String) arguments.get("styleUrl");
            Map<String, Object> cameraPositionMap = (Map<String, Object>) arguments.get("cameraPosition");
            
            if (width == null || height == null || styleUrl == null || cameraPositionMap == null) {
                result.error("INVALID_ARGUMENTS", "Missing required arguments", null);
                return;
            }
            
            // Create snapshot options
            MapSnapshotter.Options options = new MapSnapshotter.Options(width, height)
                    .withStyle(styleUrl);
            
            // Configure camera
            if (cameraPositionMap.containsKey("target")) {
                Map<String, Object> target = (Map<String, Object>) cameraPositionMap.get("target");
                if (target != null) {
                    Double lat = (Double) target.get("latitude");
                    Double lng = (Double) target.get("longitude");
                    if (lat != null && lng != null) {
                        options.withCameraPosition(new CameraPosition.Builder()
                                .target(new LatLng(lat, lng))
                                .build());
                    }
                }
            }
            
            if (cameraPositionMap.containsKey("zoom")) {
                Double zoom = (Double) cameraPositionMap.get("zoom");
                if (zoom != null) {
                    CameraPosition.Builder cameraBuilder = new CameraPosition.Builder();
                    if (options.getCameraPosition() != null) {
                        cameraBuilder.target(options.getCameraPosition().target);
                    }
                    CameraPosition cameraPosition = cameraBuilder.zoom(zoom).build();
                    Log.d(TAG, "Setting camera zoom to: " + zoom);
                    options.withCameraPosition(cameraPosition);
                }
            }
            
            // Create snapshotter
            snapshotter = new MapSnapshotter(context, options);
            
            // Set up snapshot listener
            snapshotter.start(new MapSnapshotter.SnapshotReadyCallback() {
                @Override
                public void onSnapshotReady(@NonNull MapSnapshot snapshot) {
                    try {
                        // Get the bitmap
                        Bitmap bitmap = snapshot.getBitmap();
                        
                        // Add markers if provided
                        List<Map<String, Object>> markers = (List<Map<String, Object>>) arguments.get("markers");
                        if (markers != null && !markers.isEmpty()) {
                            bitmap = addMarkersToBitmap(bitmap, markers, snapshot);
                        }
                        
                        // Convert to PNG byte array
                        ByteArrayOutputStream stream = new ByteArrayOutputStream();
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
                        byte[] imageData = stream.toByteArray();
                        
                        // Return success result
                        result.success(imageData);
                    } catch (Exception e) {
                        Log.e(TAG, "Error processing snapshot", e);
                        result.error("SNAPSHOT_ERROR", "Failed to process snapshot: " + e.getMessage(), null);
                    }
                }
            });
            
        } catch (Exception e) {
            Log.e(TAG, "Error starting snapshot", e);
            result.error("SNAPSHOT_ERROR", "Failed to start snapshot: " + e.getMessage(), null);
        }
    }
    
    private Bitmap addMarkersToBitmap(Bitmap originalBitmap, List<Map<String, Object>> markers, MapSnapshot snapshot) {
        // Create a mutable copy of the original bitmap
        Bitmap.Config config = originalBitmap.getConfig();
        if (config == null) {
            config = Bitmap.Config.ARGB_8888;
        }
        Bitmap resultBitmap = originalBitmap.copy(config, true);
        
        Canvas canvas = new Canvas(resultBitmap);
        Paint paint = new Paint();
        
        for (Map<String, Object> marker : markers) {
            try {
                // Parse marker data
                Map<String, Object> position = (Map<String, Object>) marker.get("position");
                Double lat = (Double) position.get("latitude");
                Double lng = (Double) position.get("longitude");
                byte[] iconData = (byte[]) marker.get("iconData");
                Double iconSize = (Double) marker.get("iconSize");
                
                if (lat == null || lng == null || iconData == null || iconSize == null) {
                    continue;
                }
                
                // Convert coordinates to screen point
                LatLng markerLatLng = new LatLng(lat, lng);
                PointF point = snapshot.pixelForLatLng(markerLatLng);
                
                // Create icon bitmap
                BitmapFactory.Options options = new BitmapFactory.Options();
                options.inPreferredConfig = Bitmap.Config.ARGB_8888;
                Bitmap iconBitmap = BitmapFactory.decodeByteArray(iconData, 0, iconData.length, options);
                
                if (iconBitmap != null) {
                    Log.d(TAG, "Android bitmap size: " + iconBitmap.getWidth() + "x" + iconBitmap.getHeight());
                    // Use original bitmap size (already includes DPR from Flutter)
                    int scaledWidth = iconBitmap.getWidth();
                    int scaledHeight = iconBitmap.getHeight();
                    Log.d(TAG, "Android marker - using original bitmap size: " + scaledWidth + "x" + scaledHeight);
                    Bitmap scaledIcon = iconBitmap; // Use original bitmap directly
                    
                    // Draw icon centered at the point
                    float left = point.x - scaledWidth / 2;
                    float top = point.y - scaledHeight;
                    canvas.drawBitmap(scaledIcon, left, top, paint);
                    
                    // Only recycle scaledIcon if it's a different bitmap
                    if (scaledIcon != iconBitmap) {
                        scaledIcon.recycle();
                    }
                    iconBitmap.recycle();
                }
                
            } catch (Exception e) {
                Log.e(TAG, "Error drawing marker", e);
            }
        }
        
        return resultBitmap;
    }
}
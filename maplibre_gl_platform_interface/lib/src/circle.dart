// This file is generated.

// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of maplibre_gl_platform_interface;

class Circle implements Annotation {
  Circle(this._id, this.options, [this._data]);

  /// A unique identifier for this circle.
  ///
  /// The identifier is an arbitrary unique string.
  final String _id;
  String get id => _id;

  final Map? _data;
  Map? get data => _data;

  /// The circle configuration options most recently applied programmatically
  /// via the map controller.
  ///
  /// The returned value does not reflect any changes made to the circle through
  /// touch events. Add listeners to the owning map controller to track those.
  CircleOptions options;

  @override
  Map<String, dynamic> toGeoJson() {
    final geojson = options.toGeoJson();
    geojson["id"] = id;
    geojson["properties"]["id"] = id;

    return geojson;
  }

  @override
  void translate(LatLng delta) {
    options = options
        .copyWith(CircleOptions(geometry: this.options.geometry! + delta));
  }
}

/// Configuration options for [Circle] instances.
///
/// When used to change configuration, null values will be interpreted as
/// "do not change this configuration option".
class CircleOptions {
  /// Creates a set of circle configuration options.
  ///
  /// By default, every non-specified field is null, meaning no desire to change
  /// circle defaults or current configuration.
  const CircleOptions({
    this.circleRadius,
    this.circleColor,
    this.circleBlur,
    this.circleOpacity,
    this.circleStrokeWidth,
    this.circleStrokeColor,
    this.circleStrokeOpacity,
    this.geometry,
    this.draggable,
  });

  final double? circleRadius;
  final String? circleColor;
  final double? circleBlur;
  final double? circleOpacity;
  final double? circleStrokeWidth;
  final String? circleStrokeColor;
  final double? circleStrokeOpacity;
  final LatLng? geometry;
  final bool? draggable;

  static const CircleOptions defaultOptions = CircleOptions();

  CircleOptions copyWith(CircleOptions changes) {
    return CircleOptions(
      circleRadius: changes.circleRadius ?? circleRadius,
      circleColor: changes.circleColor ?? circleColor,
      circleBlur: changes.circleBlur ?? circleBlur,
      circleOpacity: changes.circleOpacity ?? circleOpacity,
      circleStrokeWidth: changes.circleStrokeWidth ?? circleStrokeWidth,
      circleStrokeColor: changes.circleStrokeColor ?? circleStrokeColor,
      circleStrokeOpacity: changes.circleStrokeOpacity ?? circleStrokeOpacity,
      geometry: changes.geometry ?? geometry,
      draggable: changes.draggable ?? draggable,
    );
  }

  dynamic toJson([bool addGeometry = true]) {
    final Map<String, dynamic> json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value != null) {
        json[fieldName] = value;
      }
    }

    addIfPresent('circleRadius', circleRadius);
    addIfPresent('circleColor', circleColor);
    addIfPresent('circleBlur', circleBlur);
    addIfPresent('circleOpacity', circleOpacity);
    addIfPresent('circleStrokeWidth', circleStrokeWidth);
    addIfPresent('circleStrokeColor', circleStrokeColor);
    addIfPresent('circleStrokeOpacity', circleStrokeOpacity);
    if (addGeometry) {
      addIfPresent('geometry', geometry?.toJson());
    }
    addIfPresent('draggable', draggable);
    return json;
  }

  Map<String, dynamic> toGeoJson() {
    return {
      "type": "Feature",
      "properties": toJson(false),
      "geometry": {
        "type": "Point",
        "coordinates": geometry!.toGeoJsonCoordinates()
      }
    };
  }
}

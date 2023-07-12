import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';
import 'package:maplibre_gl_example/page.dart';
import 'package:maplibre_gl_example/util.dart';

class MapPaddingPage extends ExamplePage {
  const MapPaddingPage({
    super.key,
  }) : super(const Icon(Icons.padding), 'Padding');

  @override
  Widget build(BuildContext context) {
    return const _MapPaddingBody();
  }
}

class _MapPaddingBody extends StatefulWidget {
  const _MapPaddingBody({super.key});

  @override
  State<_MapPaddingBody> createState() => _MapPaddingBodyState();
}

class _MapPaddingBodyState extends State<_MapPaddingBody> {
  late MaplibreMapController mapController;

  var _mapPadding = EdgeInsets.zero;

  Symbol? _markerSymbol;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                SizedBox(
                  child: MaplibreMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition:
                        const CameraPosition(target: LatLng(0.0, 0.0)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.red.withOpacity(0.5),
                    width: _mapPadding.right,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    color: Colors.red.withOpacity(0.5),
                    width: _mapPadding.left,
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    color: Colors.red.withOpacity(0.5),
                    height: _mapPadding.top,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    color: Colors.red.withOpacity(0.5),
                    height: _mapPadding.bottom,
                  ),
                ),
                Container(
                  padding: _mapPadding,
                  alignment: Alignment.center,
                  child: Container(
                    color: Colors.pink.withOpacity(.2),
                    height: 40,
                    width: 40,
                  ),
                ),
              ],
            ),
          ),
          MaterialButton(
            onPressed: _toggleMarker,
            child: const Text("Toggle marker"),
          ),
          MaterialButton(
            onPressed: _togglePadding,
            child: const Text("Toggle padding"),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
  }

  void _togglePadding() {
    final newPadding = _mapPadding == EdgeInsets.zero
        ? const EdgeInsets.only(left: 40, right: 32, top: 10, bottom: 80)
        : EdgeInsets.zero;
    mapController.setPadding(newPadding);
    setState(() => _mapPadding = newPadding);
  }

  Future<void> _toggleMarker() async {
    if (_markerSymbol != null) {
      await mapController.removeSymbol(_markerSymbol!);
      _markerSymbol = null;
      return;
    }

    await addImageFromAsset(
      mapController,
      "custom-marker",
      "assets/symbols/custom-marker.png",
    );
    const latLng = LatLng(48, 13);
    _markerSymbol = await mapController.addSymbol(
      const SymbolOptions(geometry: latLng, iconImage: "custom-marker"),
    );
    await mapController.moveCamera(CameraUpdate.newLatLng(latLng));
    await mapController.animateCamera(
      CameraUpdate.zoomTo(9),
      duration: const Duration(milliseconds: 500),
    );
  }
}

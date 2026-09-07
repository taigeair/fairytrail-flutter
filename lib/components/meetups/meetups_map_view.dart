import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/meetups/discovery_radius.dart';
import 'package:fairytrail/meetups/meetup_category.dart';
import 'package:fairytrail/meetups/meetup_map_pins.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;

typedef MeetupPinTap = void Function(MeetupDto meetup);
typedef MapLatLngTap = void Function(double latitude, double longitude);

/// Map centred on [latitude]/[longitude] with category badge pins.
class MeetupsMapView extends StatefulWidget {
  const MeetupsMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    this.meetups = const [],
    this.showMyLocation = true,
    this.onMeetupTap,
    this.onMapTap,
    this.onPanLimitReached,
    this.draftLatitude,
    this.draftLongitude,
  });

  /// Initial / recenter framing (tight).
  static const double viewRadiusKm = 1;

  /// Can't zoom out past this viewport radius.
  static const double maxZoomOutRadiusKm = 20;

  /// Max distance the camera may pan from [latitude]/[longitude].
  static const double maxPanRadiusKm = DiscoveryRadius.km;

  final double latitude;
  final double longitude;
  final List<MeetupDto> meetups;
  final bool showMyLocation;
  final MeetupPinTap? onMeetupTap;
  final MapLatLngTap? onMapTap;

  /// Fired when the user tries to pan beyond [maxPanRadiusKm] (debounced).
  final VoidCallback? onPanLimitReached;
  final double? draftLatitude;
  final double? draftLongitude;

  static bool get usesAppleMaps => !kIsWeb && Platform.isIOS;

  static double zoomForRadiusKm(double latitude, double radiusKm) {
    final cosLat = math.cos(latitude * math.pi / 180).abs().clamp(0.2, 1.0);
    const mapWidthPx = 360.0;
    final metersAcross = radiusKm * 2000;
    final zoom =
        math.log(156543.03392 * cosLat * mapWidthPx / metersAcross) / math.ln2;
    return zoom.clamp(3.0, 18.0);
  }

  @override
  State<MeetupsMapView> createState() => MeetupsMapViewState();
}

class MeetupsMapViewState extends State<MeetupsMapView> {
  google.GoogleMapController? _google;
  apple.AppleMapController? _apple;

  final Map<MeetupCategory, google.BitmapDescriptor> _googleIcons = {};
  final Map<MeetupCategory, apple.BitmapDescriptor> _appleIcons = {};
  google.BitmapDescriptor? _googleDraftIcon;
  google.BitmapDescriptor? _googleUserLocationIcon;
  apple.BitmapDescriptor? _appleDraftIcon;
  bool _iconsReady = false;

  bool _clampingCamera = false;
  bool _suppressPanLimit = false;
  DateTime? _lastPanLimitToastAt;
  double? _lastCameraLat;
  double? _lastCameraLng;
  double? _lastCameraZoom;

  static const _pinAnchor = Offset(0.5, 0.5);
  static const _meetupMarkerZIndex = 999;
  static const _panLimitToastCooldown = Duration(seconds: 3);

  /// Same scales used when painting pin bitmaps (see [_loadIcons]).
  static const _iosPinScale = 1.38;
  static const _androidPinScale = 1.4;

  /// On-screen pin size in logical px (matches rendered marker icons).
  static double get pinLogicalSize =>
      meetupPinLogicalWidth *
      (MeetupsMapView.usesAppleMaps ? _iosPinScale : _androidPinScale);

  /// De-emphasise default Google POI icons so meetup pins stand out.
  static const _googleMapStyle = '''
[
  {"featureType": "poi", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]}
]
''';

  double get _zoom => MeetupsMapView.zoomForRadiusKm(
    widget.latitude,
    MeetupsMapView.viewRadiusKm,
  );

  /// Most-zoomed-out allowed — ~[maxZoomOutRadiusKm] km across the viewport.
  double get _minZoom => MeetupsMapView.zoomForRadiusKm(
    widget.latitude,
    MeetupsMapView.maxZoomOutRadiusKm,
  );

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  @override
  void didUpdateWidget(covariant MeetupsMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final homeMoved =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    if (!homeMoved) return;
    // Pan radius is anchored to [latitude]/[longitude]. When home moves
    // (resume / recenter), suppress the "nearby only" toast while the camera
    // catches up, then re-frame around the new origin.
    unawaited(_onHomeLocationChanged());
  }

  Future<void> _onHomeLocationChanged() async {
    _suppressPanLimit = true;
    try {
      await animateTo(widget.latitude, widget.longitude);
      // Let camera idle settle before re-enabling pan checks.
      await Future<void>.delayed(const Duration(milliseconds: 450));
    } finally {
      _suppressPanLimit = false;
    }
  }

  Future<void> _loadIcons() async {
    final deviceRatio = WidgetsBinding.instance.platformDispatcher.views.isEmpty
        ? 3.0
        : WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio;
    // Paint sharper than 2x screens; Google Maps needs matching imagePixelRatio.
    final paintRatio = deviceRatio < 3 ? 3.0 : deviceRatio;

    if (MeetupsMapView.usesAppleMaps) {
      // Slightly larger than the base so pins stay readable on Apple Maps.
      final pinW = meetupPinLogicalWidth * _iosPinScale;
      final pinH = meetupPinLogicalHeight * _iosPinScale;
      for (final c in MeetupCategory.values) {
        final bytes = await meetupCategoryPinPng(
          c,
          logicalWidth: pinW,
          logicalHeight: pinH,
          pixelRatio: paintRatio,
        );
        _appleIcons[c] = apple.BitmapDescriptor.fromBytes(bytes);
      }
      final draft = await meetupDraftPinPng(
        logicalWidth: pinW,
        logicalHeight: pinH,
        pixelRatio: paintRatio,
      );
      _appleDraftIcon = apple.BitmapDescriptor.fromBytes(draft);
    } else {
      // With imagePixelRatio set, Google Maps sizes correctly.
      final pinW = meetupPinLogicalWidth * _androidPinScale;
      final pinH = meetupPinLogicalHeight * _androidPinScale;
      for (final c in MeetupCategory.values) {
        final bytes = await meetupCategoryPinPng(
          c,
          logicalWidth: pinW,
          logicalHeight: pinH,
          pixelRatio: paintRatio,
        );
        _googleIcons[c] = google.BitmapDescriptor.bytes(
          bytes,
          imagePixelRatio: paintRatio,
        );
      }
      final draft = await meetupDraftPinPng(
        logicalWidth: pinW,
        logicalHeight: pinH,
        pixelRatio: paintRatio,
      );
      _googleDraftIcon = google.BitmapDescriptor.bytes(
        draft,
        imagePixelRatio: paintRatio,
      );
      if (widget.showMyLocation) {
        final userDot = await meetupUserLocationDotPng(pixelRatio: paintRatio);
        _googleUserLocationIcon = google.BitmapDescriptor.bytes(
          userDot,
          imagePixelRatio: paintRatio,
        );
      }
    }

    if (mounted) setState(() => _iconsReady = true);
  }

  Future<void> animateTo(double lat, double lng) async {
    final wasSuppressed = _suppressPanLimit;
    _suppressPanLimit = true;
    final r = MeetupsMapView.viewRadiusKm;
    final b = _boundsAround(lat, lng, r);
    try {
      if (MeetupsMapView.usesAppleMaps) {
        await _apple?.animateCamera(
          apple.CameraUpdate.newLatLngBounds(
            apple.LatLngBounds(
              southwest: apple.LatLng(b.$1, b.$2),
              northeast: apple.LatLng(b.$3, b.$4),
            ),
            48,
          ),
        );
        return;
      }
      await _google?.animateCamera(
        google.CameraUpdate.newLatLngBounds(
          google.LatLngBounds(
            southwest: google.LatLng(b.$1, b.$2),
            northeast: google.LatLng(b.$3, b.$4),
          ),
          48,
        ),
      );
    } finally {
      if (!wasSuppressed) {
        // Keep suppress if a home-change is in progress.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (mounted) _suppressPanLimit = false;
      }
    }
  }

  (double, double, double, double) _boundsAround(
    double lat,
    double lng,
    double radiusKm,
  ) {
    final latDelta = radiusKm / 111.32;
    final cosLat = math.cos(lat * math.pi / 180).abs().clamp(0.2, 1.0);
    final lngDelta = radiusKm / (111.32 * cosLat);
    return (lat - latDelta, lng - lngDelta, lat + latDelta, lng + lngDelta);
  }

  google.LatLngBounds get _googlePanBounds {
    final b = _boundsAround(
      widget.latitude,
      widget.longitude,
      MeetupsMapView.maxPanRadiusKm,
    );
    return google.LatLngBounds(
      southwest: google.LatLng(b.$1, b.$2),
      northeast: google.LatLng(b.$3, b.$4),
    );
  }

  Future<void> _fitToRadius() => animateTo(widget.latitude, widget.longitude);

  bool get _hasDraft =>
      widget.draftLatitude != null && widget.draftLongitude != null;

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  /// Project [lat]/[lng] onto the circle of [radiusKm] around home.
  static (double, double) _clampToRadius(
    double homeLat,
    double homeLng,
    double lat,
    double lng,
    double radiusKm,
  ) {
    final d = _haversineKm(homeLat, homeLng, lat, lng);
    if (d <= radiusKm || d == 0) return (lat, lng);
    final t = radiusKm / d;
    return (homeLat + (lat - homeLat) * t, homeLng + (lng - homeLng) * t);
  }

  void _notifyPanLimit() {
    final now = DateTime.now();
    final last = _lastPanLimitToastAt;
    if (last != null && now.difference(last) < _panLimitToastCooldown) return;
    _lastPanLimitToastAt = now;
    widget.onPanLimitReached?.call();
  }

  Future<void> _enforcePanLimit(double lat, double lng) async {
    if (_clampingCamera || _suppressPanLimit) return;
    final dist = _haversineKm(widget.latitude, widget.longitude, lat, lng);
    if (dist <= MeetupsMapView.maxPanRadiusKm) return;

    _clampingCamera = true;
    _notifyPanLimit();
    final clamped = _clampToRadius(
      widget.latitude,
      widget.longitude,
      lat,
      lng,
      MeetupsMapView.maxPanRadiusKm,
    );
    try {
      if (MeetupsMapView.usesAppleMaps) {
        await _apple?.animateCamera(
          apple.CameraUpdate.newLatLng(apple.LatLng(clamped.$1, clamped.$2)),
        );
      } else {
        await _google?.animateCamera(
          google.CameraUpdate.newLatLng(google.LatLng(clamped.$1, clamped.$2)),
        );
      }
    } finally {
      _clampingCamera = false;
    }
  }

  void _onCameraMove(double lat, double lng, double zoom) {
    _lastCameraLat = lat;
    _lastCameraLng = lng;
    _lastCameraZoom = zoom;
  }

  /// Geographic hit radius that matches the on-screen pin icon at the current zoom.
  double pinHitRadiusKm(double latitude) {
    final zoom = _lastCameraZoom ?? _zoom;
    final cosLat = math.cos(latitude * math.pi / 180).abs().clamp(0.2, 1.0);
    final metersPerPx = 156543.03392 * cosLat / math.pow(2.0, zoom);
    // Anchor is center — radius to the edge of the painted icon.
    return (pinLogicalSize / 2) * metersPerPx / 1000.0;
  }

  void _onCameraIdle() {
    final lat = _lastCameraLat;
    final lng = _lastCameraLng;
    if (lat == null || lng == null) return;
    unawaited(_enforcePanLimit(lat, lng));
  }

  @override
  Widget build(BuildContext context) {
    if (MeetupsMapView.usesAppleMaps) {
      return apple.AppleMap(
        initialCameraPosition: apple.CameraPosition(
          target: apple.LatLng(widget.latitude, widget.longitude),
          zoom: _zoom,
        ),
        myLocationEnabled: widget.showMyLocation,
        compassEnabled: false,
        minMaxZoomPreference: apple.MinMaxZoomPreference(_minZoom, null),
        onTap: (pos) => widget.onMapTap?.call(pos.latitude, pos.longitude),
        onCameraMove: (pos) => _onCameraMove(
          pos.target.latitude,
          pos.target.longitude,
          pos.zoom,
        ),
        onCameraIdle: _onCameraIdle,
        annotations: {
          if (_iconsReady)
            for (final m in widget.meetups)
              if (_appleIcons[m.category] != null)
                apple.Annotation(
                  annotationId: apple.AnnotationId('m-${m.id}'),
                  position: apple.LatLng(m.latitude, m.longitude),
                  anchor: _pinAnchor,
                  icon: _appleIcons[m.category]!,
                  onTap: () => widget.onMeetupTap?.call(m),
                ),
          if (_iconsReady && _hasDraft && _appleDraftIcon != null)
            apple.Annotation(
              annotationId: apple.AnnotationId('draft'),
              position: apple.LatLng(
                widget.draftLatitude!,
                widget.draftLongitude!,
              ),
              anchor: _pinAnchor,
              icon: _appleDraftIcon!,
            ),
        },
        onMapCreated: (c) {
          _apple = c;
          _fitToRadius();
        },
      );
    }

    return google.GoogleMap(
      initialCameraPosition: google.CameraPosition(
        target: google.LatLng(widget.latitude, widget.longitude),
        zoom: _zoom,
      ),
      myLocationEnabled:
          widget.showMyLocation && (kIsWeb || !Platform.isAndroid),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      cameraTargetBounds: google.CameraTargetBounds(_googlePanBounds),
      minMaxZoomPreference: google.MinMaxZoomPreference(_minZoom, null),
      onTap: (pos) => widget.onMapTap?.call(pos.latitude, pos.longitude),
      onCameraMove: (pos) => _onCameraMove(
        pos.target.latitude,
        pos.target.longitude,
        pos.zoom,
      ),
      onCameraIdle: _onCameraIdle,
      markers: {
        if (widget.showMyLocation &&
            !kIsWeb &&
            Platform.isAndroid &&
            _googleUserLocationIcon != null)
          google.Marker(
            markerId: const google.MarkerId('user-location'),
            position: google.LatLng(widget.latitude, widget.longitude),
            anchor: const Offset(0.5, 0.5),
            icon: _googleUserLocationIcon!,
            zIndexInt: 1,
          ),
        for (final m in widget.meetups)
          if (_iconsReady && _googleIcons[m.category] != null)
            google.Marker(
              markerId: google.MarkerId('m-${m.id}'),
              position: google.LatLng(m.latitude, m.longitude),
              anchor: _pinAnchor,
              consumeTapEvents: true,
              icon: _googleIcons[m.category]!,
              zIndexInt: _meetupMarkerZIndex,
              onTap: () => widget.onMeetupTap?.call(m),
            ),
        if (_iconsReady && _hasDraft && _googleDraftIcon != null)
          google.Marker(
            markerId: const google.MarkerId('draft'),
            position: google.LatLng(
              widget.draftLatitude!,
              widget.draftLongitude!,
            ),
            anchor: _pinAnchor,
            consumeTapEvents: true,
            icon: _googleDraftIcon!,
            zIndexInt: _meetupMarkerZIndex + 1,
          ),
      },
      style: _googleMapStyle,
      onMapCreated: (c) {
        _google = c;
        _fitToRadius();
      },
    );
  }
}

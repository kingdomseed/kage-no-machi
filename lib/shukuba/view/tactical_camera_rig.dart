import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter_scene/scene.dart' show PerspectiveCamera;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart'
    show Ray, Vector3, degrees2Radians;

class TacticalCameraRig {
  new({CameraPreset initialPreset = CameraPreset.duskOverview})
    : _camera = initialPreset.toPerspectiveCamera(),
      _target = initialPreset.target.toVector3(),
      _baseVerticalFovDegrees = initialPreset.verticalFovDegrees {
    _syncSphericalFromEye(initialPreset.eye.toVector3());
  }

  static const double minDistanceMeters = 12;
  static const double maxDistanceMeters = 115;
  static const double minPitchRadians = 2 * degrees2Radians;
  static const double maxPitchRadians = 64 * degrees2Radians;
  static const double horizonLiftStartRadians = 16 * degrees2Radians;
  static const double panBoundsMeters = 32;
  static const double keyPanSpeedMetersPerSec = 18;

  final PerspectiveCamera _camera;
  final Vector3 _target;

  double _yawRadians = -math.pi * 0.75;
  double _pitchRadians = CameraPreset.defaultPitchDegrees * degrees2Radians;
  double _distanceMeters = 56;
  double _baseVerticalFovDegrees;

  PerspectiveCamera get camera => _camera;

  Vec3 get target => _target.toVec3();

  double get yawRadians => _yawRadians;

  double get pitchRadians => _pitchRadians;

  double get distanceMeters => _distanceMeters;

  PerspectiveCamera applyPreset(CameraPreset preset) {
    _baseVerticalFovDegrees = preset.verticalFovDegrees;
    _target.setValues(preset.target.x, preset.target.y, preset.target.z);
    _camera
      ..fovRadiansY = preset.verticalFovDegrees * degrees2Radians
      ..fovNear = preset.nearMeters
      ..fovFar = preset.farMeters
      ..target = _target.clone()
      ..position = preset.eye.toVector3();
    _syncSphericalFromEye(preset.eye.toVector3());
    return _camera;
  }

  void orbitByRadians(double deltaYawRadians, [double deltaPitchRadians = 0]) {
    _yawRadians = _wrapAngle(_yawRadians + deltaYawRadians);
    if (deltaPitchRadians != 0) {
      _pitchRadians = (_pitchRadians + deltaPitchRadians).clamp(
        minPitchRadians,
        maxPitchRadians,
      );
    }
    _applySphericalToCamera();
  }

  void orbitByScreenDelta(Offset screenDelta, Size viewSize) {
    final refHeight = viewSize.height > 1 ? viewSize.height : 800.0;
    final deltaYaw = screenDelta.dx * (math.pi * 1.15 / refHeight);
    final deltaPitch = screenDelta.dy * (math.pi * 0.65 / refHeight);
    orbitByRadians(deltaYaw, deltaPitch);
  }

  void zoomByScrollDelta(double scrollDeltaY) {
    final scale = math.exp(scrollDeltaY * 0.0014);
    _distanceMeters = (_distanceMeters * scale).clamp(
      minDistanceMeters,
      maxDistanceMeters,
    );
    _applySphericalToCamera();
  }

  void panByAxes({
    required double rightInput,
    required double forwardInput,
    required double dtSeconds,
    GroundHeightSampler? sampleGroundY,
  }) {
    if (rightInput == 0 && forwardInput == 0) {
      return;
    }
    final right = _camera.horizontalRight;
    final forward = _camera.horizontalForward;
    final speed = keyPanSpeedMetersPerSec * (_distanceMeters / 48) * dtSeconds;
    _moveTarget(
      dx: (right.x * rightInput + forward.x * forwardInput) * speed,
      dz: (right.z * rightInput + forward.z * forwardInput) * speed,
      sampleGroundY: sampleGroundY,
    );
  }

  void panByScreenDelta(
    Offset screenDelta,
    Size viewSize, {
    GroundHeightSampler? sampleGroundY,
  }) {
    if (viewSize.height <= 0) {
      return;
    }
    final metersPerPixel =
        2 *
        _distanceMeters *
        math.tan(_camera.fovRadiansY * 0.5) /
        viewSize.height;
    final right = _camera.horizontalRight;
    final forward = _camera.horizontalForward;
    final dragRight = -screenDelta.dx * metersPerPixel;
    final dragForward =
        screenDelta.dy *
        metersPerPixel /
        math.max(math.sin(_pitchRadians), 0.22);
    _moveTarget(
      dx: right.x * dragRight + forward.x * dragForward,
      dz: right.z * dragRight + forward.z * dragForward,
      sampleGroundY: sampleGroundY,
    );
  }

  Vec3? raycastGround(
    Offset screenPosition,
    Size viewSize,
    GroundHeightSampler sampleGroundY,
  ) {
    if (viewSize.width <= 0 || viewSize.height <= 0) {
      return null;
    }
    final rawRay = _camera.screenPointToRay(screenPosition, viewSize);
    final dir = rawRay.direction.normalized();
    if (dir.y >= -1e-4) {
      return null;
    }
    final ray = Ray.originDirection(rawRay.origin, dir);

    const stepMeters = 1.5;
    const maxDistance = 280.0;
    var prevT = 0.0;
    final prevPoint = ray.at(prevT);
    var prevHeightDiff = prevPoint.y - sampleGroundY(prevPoint.x, prevPoint.z);

    for (var t = prevT + stepMeters; t <= maxDistance; t += stepMeters) {
      final point = ray.at(t);
      final groundY = sampleGroundY(point.x, point.z);
      final diff = point.y - groundY;
      if (prevHeightDiff >= 0 && diff <= 0) {
        var lo = prevT;
        var hi = t;
        for (var iter = 0; iter < 12; iter++) {
          final mid = (lo + hi) * 0.5;
          final midPoint = ray.at(mid);
          final midDiff = midPoint.y - sampleGroundY(midPoint.x, midPoint.z);
          if (midDiff > 0) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        final hit = ray.at((lo + hi) * 0.5);
        if (hit.x.abs() > 38 || hit.z.abs() > 38) {
          return null;
        }
        return Vec3(hit.x, sampleGroundY(hit.x, hit.z), hit.z);
      }
      prevT = t;
      prevHeightDiff = diff;
    }
    return null;
  }

  void _moveTarget({
    required double dx,
    required double dz,
    GroundHeightSampler? sampleGroundY,
  }) {
    final nextX = (_target.x + dx).clamp(-panBoundsMeters, panBoundsMeters);
    final nextZ = (_target.z + dz).clamp(-panBoundsMeters, panBoundsMeters);
    final nextY = sampleGroundY != null
        ? math.max<double>(0, sampleGroundY(nextX, nextZ)) * 0.45 + 1.2
        : _target.y;
    _target.setValues(nextX, nextY, nextZ);
    _applySphericalToCamera();
  }

  void _syncSphericalFromEye(Vector3 eye) {
    final offset = eye - _target;
    final dist = offset.length;
    if (dist <= 1e-4) {
      return;
    }
    _distanceMeters = dist.clamp(minDistanceMeters, maxDistanceMeters);
    final sinPitch = (offset.y / dist).clamp(
      math.sin(minPitchRadians),
      math.sin(maxPitchRadians),
    );
    _pitchRadians = math.asin(sinPitch);
    _yawRadians = math.atan2(offset.x, offset.z);
    if (offset.y < dist * math.sin(6 * degrees2Radians)) {
      _target.y = math.min(_target.y, 2.2);
    }
  }

  void _applySphericalToCamera() {
    final horiz = math.cos(_pitchRadians) * _distanceMeters;
    final sinPitch = math.sin(_pitchRadians);
    final rawH =
        ((horizonLiftStartRadians - _pitchRadians) /
                (horizonLiftStartRadians - minPitchRadians))
            .clamp(0.0, 1.0);
    final h = rawH * rawH * (3 - 2 * rawH);
    final eyeLift = h * (2.4 + 0.06 * _distanceMeters);
    final targetLift = h * (3.2 + 0.22 * _distanceMeters);
    final eye = Vector3(
      _target.x + math.sin(_yawRadians) * horiz,
      _target.y + sinPitch * _distanceMeters + eyeLift,
      _target.z + math.cos(_yawRadians) * horiz,
    );
    _camera
      ..fovRadiansY = (_baseVerticalFovDegrees + 6 * h) * degrees2Radians
      ..fovNear = (_distanceMeters * (0.017 + 0.095 * sinPitch.clamp(0.0, 1.0)))
          .clamp(0.45, 6.0)
      ..target = Vector3(_target.x, _target.y + targetLift, _target.z)
      ..position = eye;
  }

  static double _wrapAngle(double radians) {
    var wrapped = radians;
    while (wrapped > math.pi) {
      wrapped -= math.pi * 2;
    }
    while (wrapped < -math.pi) {
      wrapped += math.pi * 2;
    }
    return wrapped;
  }
}

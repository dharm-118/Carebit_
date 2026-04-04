import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const MethodChannel _carebitRuntimeChannel = MethodChannel(
  'com.carebit.frontend/runtime',
);

enum CarebitAndroidDeviceKind { emulator, physical, unknown }

class CarebitBackendRuntime {
  const CarebitBackendRuntime({
    required this.androidDeviceKind,
    required this.isWeb,
    required this.targetPlatform,
  });

  factory CarebitBackendRuntime.currentPlatform() {
    return CarebitBackendRuntime(
      androidDeviceKind: CarebitAndroidDeviceKind.unknown,
      isWeb: kIsWeb,
      targetPlatform: defaultTargetPlatform,
    );
  }

  final CarebitAndroidDeviceKind androidDeviceKind;
  final bool isWeb;
  final TargetPlatform targetPlatform;

  bool get isAndroid => !isWeb && targetPlatform == TargetPlatform.android;

  bool get isAndroidEmulator =>
      isAndroid && androidDeviceKind == CarebitAndroidDeviceKind.emulator;

  bool get isKnownPhysicalAndroidDevice =>
      isAndroid && androidDeviceKind == CarebitAndroidDeviceKind.physical;

  bool get isUnknownAndroidDevice =>
      isAndroid && androidDeviceKind == CarebitAndroidDeviceKind.unknown;
}

final carebitBackendRuntimeProvider = Provider<CarebitBackendRuntime>((
  Ref ref,
) {
  return CarebitBackendRuntime.currentPlatform();
});

Future<CarebitBackendRuntime> resolveCarebitBackendRuntime() async {
  final CarebitBackendRuntime runtime = CarebitBackendRuntime.currentPlatform();

  if (!runtime.isAndroid) {
    return runtime;
  }

  try {
    final bool? isEmulator = await _carebitRuntimeChannel.invokeMethod<bool>(
      'isAndroidEmulator',
    );

    return CarebitBackendRuntime(
      androidDeviceKind: switch (isEmulator) {
        true => CarebitAndroidDeviceKind.emulator,
        false => CarebitAndroidDeviceKind.physical,
        null => CarebitAndroidDeviceKind.unknown,
      },
      isWeb: runtime.isWeb,
      targetPlatform: runtime.targetPlatform,
    );
  } catch (_) {
    return runtime;
  }
}

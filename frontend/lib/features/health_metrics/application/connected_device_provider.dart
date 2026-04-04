import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_client/constants/app_constants.dart';
import 'package:mobile_client/dto/device_dto.dart';
import 'package:mobile_client/models/watch_data.dart';

const String _fitbitConnectionsCollection = 'fitbit_connections';

final firebaseAuthProvider = Provider<FirebaseAuth>((Ref ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((Ref ref) {
  return FirebaseFirestore.instance;
});

final connectedFitbitDeviceProvider = StreamProvider<WatchData?>((Ref ref) {
  final FirebaseAuth firebaseAuth = ref.watch(firebaseAuthProvider);
  final FirebaseFirestore firestore = ref.watch(firebaseFirestoreProvider);
  final StreamController<WatchData?> controller =
      StreamController<WatchData?>();
  StreamSubscription<User?>? authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      connectionSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? deviceSubscription;
  bool isDisposed = false;
  int deviceBindingGeneration = 0;
  String? activeDeviceDocumentId;
  String? activeUserId;
  bool hasBoundUser = false;

  Future<void> bindDeviceDocument(String? documentId) async {
    final int bindingGeneration = ++deviceBindingGeneration;
    activeDeviceDocumentId = documentId;

    final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
        previousDeviceSubscription = deviceSubscription;
    deviceSubscription = null;
    await previousDeviceSubscription?.cancel();

    if (isDisposed || bindingGeneration != deviceBindingGeneration) {
      return;
    }

    if (documentId == null) {
      if (!isDisposed) {
        controller.add(null);
      }
      return;
    }

    deviceSubscription = firestore
        .collection(AppConstants.watchDataCollection)
        .doc(documentId)
        .snapshots()
        .listen(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) {
            if (isDisposed) {
              return;
            }

            final Map<String, dynamic>? payload = snapshot.data();
            if (payload == null) {
              controller.add(null);
              return;
            }

            controller.add(DeviceDto.fromJson(payload).toModel());
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!isDisposed) {
              controller.addError(error, stackTrace);
            }
          },
        );
  }

  Future<void> bindAuthenticatedUser(User? user) async {
    final String? nextUserId = user?.uid;
    if (hasBoundUser && nextUserId == activeUserId) {
      return;
    }

    hasBoundUser = true;
    activeUserId = nextUserId;

    final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
        previousConnectionSubscription = connectionSubscription;
    connectionSubscription = null;
    await previousConnectionSubscription?.cancel();
    await bindDeviceDocument(null);

    if (isDisposed || user == null) {
      return;
    }

    connectionSubscription = firestore
        .collection(_fitbitConnectionsCollection)
        .doc(user.uid)
        .snapshots()
        .listen(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) {
            if (isDisposed) {
              return;
            }

            final String? documentId = _readString(
              snapshot.data()?['connectedDeviceDocId'],
            );
            if (documentId == activeDeviceDocumentId) {
              return;
            }

            unawaited(bindDeviceDocument(documentId));
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!isDisposed) {
              controller.addError(error, stackTrace);
            }
          },
        );
  }

  authSubscription = firebaseAuth.authStateChanges().listen(
    (User? user) {
      unawaited(bindAuthenticatedUser(user));
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!isDisposed) {
        controller.addError(error, stackTrace);
      }
    },
  );
  unawaited(bindAuthenticatedUser(firebaseAuth.currentUser));

  ref.onDispose(() {
    isDisposed = true;
    unawaited(authSubscription?.cancel());
    unawaited(connectionSubscription?.cancel());
    unawaited(deviceSubscription?.cancel());
    unawaited(controller.close());
  });

  return controller.stream;
});

String? _readString(Object? value) {
  if (value is! String) {
    return null;
  }

  final String normalizedValue = value.trim();
  return normalizedValue.isEmpty ? null : normalizedValue;
}

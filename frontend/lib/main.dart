import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/fitbit_callback_session_store.dart';
import 'firebase_options.dart';

/// Entry point of the Carebit app.
///
/// Firebase and SharedPreferences are initialized before the widget tree
/// starts so that [fitbitCallbackSessionStoreProvider] can be satisfied by a
/// concrete [SharedPreferencesFitbitCallbackSessionStore] at the root
/// [ProviderScope].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: <Override>[
        fitbitCallbackSessionStoreProvider.overrideWithValue(
          SharedPreferencesFitbitCallbackSessionStore(sharedPreferences: prefs),
        ),
      ],
      child: const CarebitApp(),
    ),
  );
}
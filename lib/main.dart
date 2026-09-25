import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupServiceLocator();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SaetaCiudadanoApp());
}

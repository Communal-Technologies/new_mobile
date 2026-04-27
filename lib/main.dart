import 'dart:async';

import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/core/theme/colors.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/routes/app_routes.dart';
import 'package:communal_mobile/routes/auth_status_notifier.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/cubits/splash/splash_cubit.dart';
import 'package:communal_mobile/cubits/settings/settings_cubit.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/cubits/security/security_cubit.dart';
import 'package:communal_mobile/core/widgets/connectivity_listener.dart';
import 'package:communal_mobile/core/services/push_notification_service.dart';
import 'package:communal_mobile/core/widgets/security_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:toastification/toastification.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _assertBuildTimeConfig();
  await configureDependencies();

  // Set system UI style (status bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // Light app surfaces need dark status bar icons by default.
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Lock to portrait only — fire-and-forget; the `.then` chains the
  // runApp call so we don't await this at top level.
  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then(
    (_) => runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => getIt<SplashCubit>()),
          BlocProvider(create: (_) => getIt<SettingsCubit>()),
          BlocProvider(create: (_) => getIt<ConnectivityCubit>()),
        ],
        child: const MyApp(),
      ),
    ),
  ));
}

/// Surfaces missing build-time `--dart-define` values at startup instead of
/// letting features (Maps, geocoding) fail silently the first time they run.
/// Hard-asserts in debug; logs a warning in release so the rest of the app
/// (login, transfers, etc.) still works without map features.
void _assertBuildTimeConfig() {
  final mapsKey = AppConstants.googleMapsApiKey;
  if (mapsKey.isEmpty) {
    assert(
      false,
      'GOOGLE_MAPS_API_KEY is not set. Pass it via '
      '--dart-define-from-file=tool/dart_defines.json (see README).',
    );
    if (kReleaseMode) {
      // ignore: avoid_print
      debugPrint('WARNING: GOOGLE_MAPS_API_KEY missing — map features disabled.');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(430, 932),
      splitScreenMode: true,
      builder: (context, _) {
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            
            return MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>(
                  create: (_) => getIt<AuthBloc>()..add(AppStarted()),
                ),
                BlocProvider<SecurityCubit>(
                  create: (_) => SecurityCubit(snapshot.data!, const FlutterSecureStorage()),
                ),
              ],
              child: MultiBlocListener(
                listeners: [
                  // Audit M29: bridge AuthBloc state into the listenable that
                  // appRouter's `redirect` consults. Fires on every state
                  // transition (resolved vs. unresolved, authed vs. not) so a
                  // logout immediately bounces protected routes back to /login.
                  BlocListener<AuthBloc, AuthState>(
                    listenWhen: (previous, current) =>
                        previous.runtimeType != current.runtimeType,
                    listener: (context, state) {
                      final resolved = state is AuthAuthenticated ||
                          state is AuthUnauthenticated;
                      appAuthStatusNotifier.update(
                        isAuthenticated: state is AuthAuthenticated,
                        isResolved: resolved,
                      );
                    },
                  ),
                  BlocListener<AuthBloc, AuthState>(
                    listenWhen: (previous, current) =>
                        current is AuthAuthenticated && previous != current,
                    listener: (context, state) async {
                      if (state is! AuthAuthenticated) return;
                      await PushNotificationService.instance.initializeAndSync(
                        getIt<AuthRepository>(),
                      );
                    },
                  ),
                ],
                child: ToastificationWrapper(
                  // Must sit above [SecurityWrapper]: the lock UI swaps in a nested
                  // [MaterialApp] and must not mount a second [ToastificationWrapper]
                  // (the package uses one module-level GlobalKey for the overlay).
                  child: SecurityWrapper(
                    child: MaterialApp.router(
                      debugShowCheckedModeBanner: false,
                      theme: AppTheme.light,
                      themeMode: ThemeMode.light,
                      routerConfig: appRouter,
                      builder: (context, child) {
                        return ConnectivityListener(
                          child: child ?? const SizedBox.shrink(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_state.dart';

/// A widget that listens to connectivity changes and shows snackbars
class ConnectivityListener extends StatefulWidget {
  final Widget child;
  final bool showOfflineSnackbar;
  final bool persistentOfflineSnackbar;

  const ConnectivityListener({
    super.key,
    required this.child,
    this.showOfflineSnackbar = true,
    this.persistentOfflineSnackbar = true,
  });

  @override
  State<ConnectivityListener> createState() => _ConnectivityListenerState();
}

class _ConnectivityListenerState extends State<ConnectivityListener> {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _currentSnackBarController;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);

        if (state is ConnectivityDisconnected && widget.showOfflineSnackbar) {
          // Close any existing snackbar first
          _currentSnackBarController?.close();
          
          // Hide any existing snackbars
          scaffoldMessenger.clearSnackBars();

          // Show persistent offline snackbar
          _currentSnackBarController = scaffoldMessenger.showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No internet connection. Please check your network.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: widget.persistentOfflineSnackbar
                  ? const Duration(days: 365) // Effectively infinite
                  : const Duration(seconds: 5),
              action: widget.persistentOfflineSnackbar
                  ? null
                  : SnackBarAction(
                      label: 'Dismiss',
                      textColor: Colors.white,
                      onPressed: () {
                        _currentSnackBarController?.close();
                        scaffoldMessenger.hideCurrentSnackBar();
                      },
                    ),
            ),
          );
        } else if (state is ConnectivityConnected) {
          // Close the offline snackbar controller if it exists
          if (_currentSnackBarController != null) {
            _currentSnackBarController!.close();
            _currentSnackBarController = null;
          }
          
          // Clear all snackbars (including persistent offline snackbar) when connection is restored
          scaffoldMessenger.clearSnackBars();

          // Show restoration snackbar if it was offline before
          if (state.wasOffline) {
            // Use a small delay to ensure the offline snackbar is fully cleared
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.wifi, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Internet connection restored',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                      label: 'Dismiss',
                      textColor: Colors.white,
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      },
                    ),
                  ),
                );
              }
            });
          }
        }
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _currentSnackBarController?.close();
    super.dispose();
  }
}


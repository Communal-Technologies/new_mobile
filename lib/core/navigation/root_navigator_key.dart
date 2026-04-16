import 'package:flutter/material.dart';

/// [MaterialApp.router] / [GoRouter] shell navigator. Used for overlays (e.g. idle prompt)
/// from widgets that sit *above* the router in the tree (such as [SecurityWrapper]).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

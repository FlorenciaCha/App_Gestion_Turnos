import 'package:flutter/widgets.dart';

/// Global RouteObserver to allow screens to be aware of navigation events.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

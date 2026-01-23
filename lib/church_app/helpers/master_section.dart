

import 'package:flutter/material.dart';

/// A reusable section that can render itself into the home scroll.
abstract class MasterSection {
  String get id;

  /// Lower number shows earlier in the page.
  int get order;

  /// Return one or more slivers (so everything is one scroll).
  List<Widget> buildSlivers(BuildContext context);
}
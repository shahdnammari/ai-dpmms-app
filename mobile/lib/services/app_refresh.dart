import 'package:flutter/material.dart';

class AppRefresh {
  static final ValueNotifier<int> notifier = ValueNotifier(0);

  static void trigger() {
    notifier.value++;
  }
}
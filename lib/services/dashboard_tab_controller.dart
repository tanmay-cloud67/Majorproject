import 'package:flutter/foundation.dart';

class DashboardTabController {
  DashboardTabController._();

  static final ValueNotifier<int> indexNotifier = ValueNotifier<int>(0);

  static int get index => indexNotifier.value;

  static void setIndex(int index) {
    if (indexNotifier.value == index) {
      return;
    }
    indexNotifier.value = index;
  }
}

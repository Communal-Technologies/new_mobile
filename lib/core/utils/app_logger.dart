import 'dart:developer';

import 'package:flutter/foundation.dart';

void appLog(dynamic data, [dynamic data2]) {
  if (kDebugMode) {
    log('''APP LOGGER IS PRINTING ===========================================
      YOUR DATA IS ----> $data \n\n
      YOUR DATA 2 IS ----> $data2 \n 
      ===============================================================''');
  }
}

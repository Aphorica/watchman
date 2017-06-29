// Copyright (c) 2017, rickb. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'dart:io' as io;

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

main(List<String> args) {
  bool verbose = false;
  List<String> fnlist = <String>[];

  for (String arg in args) {
          // scan for flags, first
    if (arg == '-v') {
      verbose = true;
      continue;
    }

    String fn = p.absolute(arg);

    io.File fi = new io.File(fn);
    if (fi.existsSync() && fi.statSync().type == io.FileSystemEntityType.FILE) {
      fnlist.add(fn);
      if (verbose) {
        print("Added: $fn");
      }
    }

    else if (verbose) {
      print('Error: "$fn" is not a file - ignoring');
    }
  }

  if (fnlist.isNotEmpty) {
    for (String fn in fnlist) {
      print ('adding watcher on: "$fn"');
      FileWatcher watcher = new FileWatcher(fn);
      watcher.events.listen((event) {
        print('Got an event...');
        print(event);
      });
    }
  }

  else {
    print("Usage: watch <-v> [file list]");
  }

  return 0;
}
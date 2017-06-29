// Copyright (c) 2017, rickb. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'dart:io';
import 'dart:convert';

import 'package:watcher/watcher.dart';
import 'package:sass/sass.dart' as Sass;

main(List<String> args) {
  bool verbose = false;
  String configFile = '', configString;;
  Map<String, String> cmdList = <String,String>{};

  for (int argIX = 0; argIX < args.length; argIX++) {
          // scan for flags, first
    String arg = args[argIX];

    if (arg == '-v') {
      verbose = true;
    }
    else {
      configFile = args[argIX];
    }
  }

  if (configFile.isEmpty) {
    print("Usage: watchman <-v> configFile");
    return 1;
  }

  else {
    File fi = new File(configFile);
    if (!fi.existsSync() && fi.statSync().type != FileSystemEntityType.FILE) {
      print("ERROR: $configFile doesn't exist or is not a file...");
      return 1;
    }

    configString = fi.readAsStringSync();
  }

  Map<String,dynamic> cfg;

  try {
    cfg = JSON.decode(configString);
  }
  catch(e) {
    print ("ERROR: $e");
    return 1;
  }

  if (cfg.containsKey('sass')) {
    if (verbose)
      print ('Process sass files:');
    List<String> sassPaths = cfg['sass'];
    for (String path in sassPaths) {

      if (verbose)
        print('  Scanning $path...');

      Directory dir = new Directory(path);
      if (dir.existsSync()) {
        for (FileSystemEntity entity in dir.listSync(recursive:true)) {
          if (entity.statSync().type == FileSystemEntityType.FILE &&
               entity.path.endsWith('.scss') || entity.path.endsWith('.sass')) {
            String fullPath = (entity.absolute.path);
            if (verbose)
              print ('    Adding file: "${entity.path}"');
              
            FileWatcher watcher = new FileWatcher(fullPath);
            watcher.events.listen((event) {
              String sassStr = Sass.render(fullPath);
              String outPath = fullPath.replaceFirst(new RegExp('\.s[ca]ss'), '.css');
              File outFile = new File(outPath);
              if (verbose)
                print('Sass output: $fullPath => $outPath');

              try {
                outFile.writeAsStringSync(sassStr);
              } catch (e) {
                print("ERROR: writing to $outPath");
                print(e);
              }
            });          
          }
        }
      } else {
        print('ERROR: Sass search path "$path" does not exist');
      }
    }
  }

/*
  if (cfg.containsKey('cmd')) {
    List<Map<String, String>> cmdEntities = cfg['cmd'];
    for (Map<String, String> cmdEntity in cmdEntities) {

    }
  }

  return 0;

    String fn = p.absolute(arg);

    File fi = new File(fn);
    if (fi.existsSync() && fi.statSync().type == FileSystemEntityType.FILE) {
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
  */

  return 0;
}
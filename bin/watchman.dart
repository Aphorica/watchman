// Copyright (c) 2017, rickb, Aphorica Inc. All rights reserved. Use of this source code
// is governed by a MIT-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:watcher/watcher.dart';
import 'package:sass/sass.dart' as Sass;

main(List<String> args) {
  bool verbose = false;
  String configFile = '', configString;
  String rootPath = '.';

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

  YamlMap cfg;

  try {
    cfg = loadYaml(configString);
  }
  catch(e) {
    print ("ERROR: Reading config");
    print ("$e");
    return 1;
  }

  if (cfg.containsKey('root')) {
    rootPath = cfg['root'];
  }

  rootPath = p.canonicalize(rootPath);

  if (verbose) {
    print ('Root path: "$rootPath"');
  }

  if (cfg.containsKey('sass')) {
    if (verbose)
      print ('Processing \'sass\' section:');
    List<String> sassPaths = cfg['sass'];
    for (String path in sassPaths) {
      File sassFile = new File(path);
      if (sassFile.statSync().type == FileSystemEntityType.FILE) {
        processSassFile(sassFile, verbose);
      } else {
        if (verbose)
          print('  Scanning $path...');

        Directory dir = new Directory(path);
        if (dir.existsSync()) {
          for (FileSystemEntity entity in dir.listSync(recursive:true)) {
            processSassFile(entity, verbose);
          }
        } else {
          print('ERROR: Sass search path "$path" does not exist');
        }
      }
    }
  }

  if (cfg.containsKey('copy')) {
    if (verbose)
      print('Processing \'copy\' section:');
    List<Map<String, String>> cmdEntities = cfg['copy'];
    for (Map<String, String> cmdEntity in cmdEntities) {
      File fi = new File(cmdEntity['src-path']);
      if (fi.existsSync() && fi.statSync().type == FileSystemEntityType.FILE) {
        String fullSrcPath = fi.absolute.path;
        String fullDstPath = cmdEntity['dst-path'];
        if (!p.isAbsolute(fullDstPath))
          fullDstPath = p.join(rootPath,fullDstPath);

        if (verbose) {
          print ("  Adding item:");
          print ("    SrcPath: $fullSrcPath");
          print ("    DstPath: $fullDstPath");
        }

        File fiDst = new File(fullDstPath);
        if (!fiDst.existsSync())
          copyFile(fullSrcPath, fullDstPath, verbose);

        FileWatcher watcher = new FileWatcher(fullSrcPath);
        watcher.events.listen((event) {
          copyFile(fullSrcPath, fullDstPath, verbose);
        });          

      }

      else {
        print ('  ERROR: file "${cmdEntity['path']}" does not exist or is not a file');
      }
    }
  }

  return 0;
}

void processSassFile(FileSystemEntity entity, bool verbose) {
  if (entity.statSync().type == FileSystemEntityType.FILE &&
      entity.path.endsWith('.scss') || entity.path.endsWith('.sass')) {
  String fullPath = (entity.absolute.path);
  if (verbose)
    print ('    Adding file: "${entity.path}"');
    
  String outPath = fullPath.replaceFirst(new RegExp('\.s[ca]ss'), '.css');
  File outFile = new File(outPath);
  if (!outFile.existsSync())
    sassFile(fullPath, outPath, verbose);

  FileWatcher watcher = new FileWatcher(fullPath);
  watcher.events.listen((event) {
      sassFile(fullPath, outPath, verbose);
    });          
  }
}

void copyFile(String src, String dst, bool verbose) {
  File fi = new File(src);
  if (verbose) {
    print ('Copying: "$src" => "$dst"');
  }
  try {
    fi.copySync(dst);
  } catch (e) {
    print('ERROR: copying $src to $dst');
    print(e);
  }
}

void sassFile(String src, String dst, bool verbose) {
  String sassStr = Sass.render(src);
  File outFile = new File(dst);
  if (verbose) {
    print('Sass output: "$src" => "$dst"');
  }

  try {
    outFile.writeAsStringSync(sassStr);
  } catch (e) {
    print("ERROR: writing to $dst");
    print(e);
  }
}
// Copyright (c) 2017, rickb, Aphorica Inc. All rights reserved. Use of this source code
// is governed by a MIT-style license that can be found in the LICENSE file.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:watcher/watcher.dart';
import 'package:sass/sass.dart' as Sass;

main(List<String> args) {
  bool verbose = false;
  bool doWatch = true;
  bool force = false;
  String configFile = '', configString;
  String rootPath = '.';

  for (int argIX = 0; argIX < args.length; argIX++) {
          // scan for flags, first
    String arg = args[argIX];

    if (arg[0] == '-') {
      if (arg.contains('v')) {
        verbose = true;
      }
      if (arg.contains('n')) {
        doWatch = false;
      }
      if (arg.contains('f')) {
        force = true;
      }
    }
    else {
      configFile = args[argIX];
    }
  }

  if (configFile.isEmpty) {
    print("Usage: watchman <-v -f -n> configFile");
    print("Where:");
    print("  -f = force on init.  Files will be overwritten whether they exist or not.");
    print("  -n = no watch.  Files will be processed and then exits.");
    print("  -v = verbose");
    print("  configFile = The file containing the configuration yaml");
    print("Flag args may be groups, i.e. '-fv'");
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

////////////////////////////////////////////////////////////////////////////////////////
/// beg process pubspec
////////////////////////////////////////////////////////////////////////////////////////

  String psPath = p.join(rootPath, 'pubspec.src');
  File ps = new File(psPath);
  if (ps.existsSync()) {
     pubYaml(rootPath, verbose);

     if (doWatch) {
       if (verbose) {
         print('  Watching $psPath');
       }
        FileWatcher watcher = new FileWatcher(psPath);
        watcher.events.listen((event) {
          pubYaml(rootPath, verbose);
      });     
    }
  }

////////////////////////////////////////////////////////////////////////////////////////
/// end process pubspec
/// beg process sass
////////////////////////////////////////////////////////////////////////////////////////

  if (cfg.containsKey('sass')) {
    if (verbose)
      print ('Processing \'sass\' section:');
    List<String> sassPaths = cfg['sass'];
    for (String path in sassPaths) {
      File sassFile = new File(path);
      if (sassFile.statSync().type == FileSystemEntityType.FILE) {
        processSassFile(sassFile, verbose, doWatch, force);
      } else {
        if (verbose)
          print('  Scanning $path...');

        Directory dir = new Directory(path);
        if (dir.existsSync()) {
          for (FileSystemEntity entity in dir.listSync(recursive:true)) {
            processSassFile(entity, verbose, doWatch, force);
          }
        } else {
          print('ERROR: Sass search path "$path" does not exist');
        }
      }
    }
  }

////////////////////////////////////////////////////////////////////////////////////////
/// end process sass
/// beg process copy
////////////////////////////////////////////////////////////////////////////////////////

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
          print ("  For item:");
          print ("    SrcPath: $fullSrcPath");
          print ("    DstPath: $fullDstPath");
        }

        File fiDst = new File(fullDstPath);
        if (force || !fiDst.existsSync())
          copyFile(fullSrcPath, fullDstPath, verbose);

        if (doWatch) {
          if (verbose) {
            print ("      watching...");
          }
          FileWatcher watcher = new FileWatcher(fullSrcPath);
          watcher.events.listen((event) {
            copyFile(fullSrcPath, fullDstPath, verbose);
          });          
        }
      }

      else {
        print ('  ERROR: file "${cmdEntity['path']}" does not exist or is not a file');
      }
    }
  }

////////////////////////////////////////////////////////////////////////////////////////
/// end process copy
////////////////////////////////////////////////////////////////////////////////////////

  return 0;
}

void processSassFile(FileSystemEntity entity, bool verbose, bool doWatch, bool force) {
  if (entity.statSync().type == FileSystemEntityType.FILE &&
      entity.path.endsWith('.scss') || entity.path.endsWith('.sass')) {
  String fullPath = (entity.absolute.path);
  if (verbose) {
    print ('    For file: "${entity.path}"');
  }
    
  String outPath = fullPath.replaceFirst(new RegExp('\.s[ca]ss'), '.css');
  File outFile = new File(outPath);
  if (force || !outFile.existsSync()) {
    sassFile(fullPath, outPath, verbose);
  }

  if (doWatch) {
    if (verbose) {
      print ('      watching...');
    }
    FileWatcher watcher = new FileWatcher(fullPath);
    watcher.events.listen((event) {
        sassFile(fullPath, outPath, verbose);
      });          
    }
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

void pubYaml(String rootPath, bool verbose) {
  String fullSrcPath = p.join(rootPath, 'pubspec.src'),
         fullDstPath = p.join(rootPath, 'pubspec.yaml'); 
  File ps = new File(fullSrcPath);
  String psStr = ps.readAsStringSync();
  List<Match> envMatches = <Match>[];

  if (verbose) {
    print('Pubspec output: "$fullSrcPath" => "$fullDstPath"');
  }

  for (int ix = 0; ix < 2; ix++) {
    RegExp regex = ix == 0? new RegExp(r'([$][{]?[A-Z0-9)]*[}]?)') : new RegExp(r'([%][A-Z0-9]*[%]?)'); 
                // scan for both win and nix

    envMatches.addAll(regex.allMatches(psStr));
  }

  if (envMatches.isNotEmpty) {
    RegExp cleanDelimsRegEx = new RegExp(r'[%${}]');
    Set<String> envStrings = new Set<String>();
            // contains a unique set of all of the instances

    for (Match envMatch in envMatches)
    {
      if (envMatch.groupCount > 0) {
        envStrings.add(envMatch.group(0));
      }
    }

    for (String envString in envStrings) {
      String envName = envString.replaceAll(cleanDelimsRegEx, '');
              // clean out the delimiters

      String envVal = Platform.environment[envName];

      if (envVal != null || envVal.isNotEmpty)
        psStr = psStr.replaceAll(envString, envVal);
    }

    File psOut = new File(fullDstPath);
    psOut.writeAsStringSync(psStr);
  }
}
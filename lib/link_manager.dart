library dslink.link_manager;

import "dart:async";
import "dart:convert" as Convert;
import "dart:convert";
import "dart:io";

import "io.dart";
import "utils.dart" as DSUtils;

import "package:path/path.dart" as pathlib;

abstract class LinkManager {
  List<Function> _startLinks = [];
  Map<String, Function> linkCommanders = {};
  List<Process> _linkProcesses = [];
  List<String> _loadedLinks = [];

  String getBrokerUrl();
  bool isLinkDisabled(String name);
  enable(String name);
  disable(String name);

  addLink(String name, String description, String version, String updateType, bool enable);
  setLinkState(String name, String state);

  loadLink(String path, [bool shouldStartNow = false, bool skipDuplicates = false]) async {
    var name = pathlib.basename(path);
    var logFile = new File("logs/${name}.log");

    var gitDir = new Directory("${path}/.git");
    var gitExe = await findExecutable("git");
    var isGitLink = await gitDir.exists();
    var isUpdatableGit = isGitLink && gitExe != null;
    var updateType = isUpdatableGit ? "git" : "none";

    if (isUpdatableGit) {
      BetterProcessResult result = await exec(gitExe, args: ["pull"], workingDirectory: path, outputFile: logFile);
      if (result.exitCode != 0) {
        print("Warning: Tried to run 'git pull' in '${path}', but it failed.");
      }
    }

    var dslinkJsonFile = new File("${path}/dslink.json");
    var linkDir = new Directory(path).absolute;

    if (!(await dslinkJsonFile.exists())) {
      return;
    }

    Map json;

    try {
      json = Convert.JSON.decode(await dslinkJsonFile.readAsString());
    } catch (e) {
      print("ERROR while loading dslink.json at ${dslinkJsonFile.path}: ${e}");
      return;
    }

    DSUtils.DSLinkJSON c = new DSUtils.DSLinkJSON.from(json);

    try {
      c.verify();
    } catch (e) {
      print("ERROR while verifying dslink.json at ${dslinkJsonFile.path}: ${e}");
      return;
    }

    try {
      if (_basicLinkData != null && updateType == "none") {
        var rn = c.name;
        if (_basicLinkData.any((x) => x["name"] == rn)) {
          updateType = "repository";
        }
      }
    } catch (e) {}

    if (_loadedLinks.contains(name)) {
      if (!skipDuplicates) {
        print("ERROR while loading '${name}': duplicate link found! (path: ${path})");
      }
      return;
    }

    _loadedLinks.add(name);

    if (!(await logFile.exists())) {
      await logFile.create(recursive: true);
    }

    await addLink(name, c.description, c.version, updateType, !isLinkDisabled(name));

    await setLinkState(name, "getting dependencies");

    if (c.getDependencies != null && c.getDependencies.isNotEmpty) {
      var deps = c.getDependencies;
      if (c.engines != null && c.engines.isNotEmpty && c.engines.keys.first == "dart" && deps.every((x) => x.startsWith("pub "))) {
        var pubspecFile = new File(pathlib.join(path, "pubspec.yaml"));

        if (!(await pubspecFile.exists())) {
          deps = [];
        }
      }

      if (deps.isNotEmpty) {
        print("Fetching Dependencies for DSLink '${name}'");

        for (var cmd in deps) {
          var parts = cmd.split(" ");
          var exe = parts[0];

          if (!pathlib.isAbsolute(exe) && !exe.contains("/") && !exe.contains("\\")) {
            exe = await findExecutable(exe);

            if (exe == null) {
              print("ERROR while fetching dependencies for link '${name}:'");
              print("This DSLink requires '${exe}' to fetch it's dependencies.");
              return;
            }
          }

          var args = parts.skip(1).toList();

          var result = await exec(exe, args: args, outputFile: logFile, workingDirectory: path, environment: {
            "DSA_LINK_NAME": name
          });

          if (result.exitCode != 0) {
            print("ERROR while fetching dependencies for link '${name}':");
            print("Process '${exe}' with arugments ${args} exited with status ${result.exitCode}");
            return;
          }
        }
        print("Fetched Dependencies for DSLink '${name}'");
      }
    }

    await setLinkState(name, "stopped");

    Process ourProc;
    RuntimeManager runtime;

    bool reloadForced = false;
    bool running = false;
    bool noRestart = false;

    Function starter;
    Function commander;

    commander = linkCommanders[name] = (String cmd) async {
      if (cmd == "restart") {
        if (!running) {
          await commander("start");
        } else {
          reloadForced = true;
          noRestart = false;
          await commander("stop");
          reloadForced = true;
          noRestart = false;
        }
      } else if (cmd == "start") {
        var isDisabled = isLinkDisabled(name);

        if (wasDisabled) {
          await setLinkEnabled(name);
        }

        if (!running && starter != null) {
          starter();
        }
      } else if (cmd == "stop") {
        if (!reloadForced) {
          noRestart = true;
        }

        if (ourProc != null) {
          var mpid = ourProc.pid;
          await forceKill(mpid);
        } else if (runtime != null) {
          runtime.stopLink(linkDir.path);
        }
      } else if (cmd == "enable") {
        enable(name);
      } else if (cmd == "disable") {
        if (!isLinkDisabled(name)) {
          disable(name);
        }
      } else if (cmd == "update-git") {
        BetterProcessResult result = await exec(gitExe, args: ["pull"], workingDirectory: path, outputFile: logFile);
        if (result.exitCode != 0) {
          return "Failed.";
        } else {
          return "Success!";
        }
      } else if (cmd == "uninstall") {
        await linkCommanders[name]("stop");

        while (running) {
          await new Future.delayed(const Duration(milliseconds: 25));
        }

        await brokerWorkerClient.callMethod("removeLink", name);
        _loadedLinks.remove(name);
        linkCommanders.remove(name);

        var dir = new Directory(path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }

        print("DSLink '${name}' has been uninstalled.");
      } else if (cmd == "update-repo") {
        await linkCommanders[name]("stop");
        try {
          var rname = json["name"];
          var info = await fetchLinkRepositoryInfo();
          var entry = info.firstWhere((x) => x["name"] == rname, orElse: () => null);

          if (entry == null) {
            return "${rname} was not found in the repository.";
          }

          var zipUrl = entry["zip"];

          return await LinkManager.updateLinkFromZip(linkDir, zipUrl, json);
        } catch (e) {
          return e.toString();
        }
      } else if (cmd == "getLinkDirectory") {
        return linkDir;
      } else if (cmd == "getLinkJson") {
        return json;
      }
    };

    var canUseRuntime = json["useRuntimeManager"] != null ? json["useRuntimeManager"] : true;

    canUseRuntime = canUseRuntime && !Platform.isWindows && gconfig.useRuntimeManager;

    if (canUseRuntime && c.engines != null && c.engines.isNotEmpty && c.engines.keys.contains("dart")) {
      runtime = await getDartRuntimeManager(_linkProcesses);
    }

    if (canUseRuntime &&
    (
        (c.engines != null && c.engines.isNotEmpty && c.engines.keys.contains("java")) ||
        c.name.startsWith("dslink-java-") && c.configs.containsKey("handler_class") &&
        c.configs.containsKey("name") && c.configs.containsKey("log"))) {
      String jpath = pathlib.join("bin", "runtimes", "java.jar");

      if (await new File(jpath).exists()) {
        runtime = await getJavaRuntimeManager(_linkProcesses);
      }
    }

    starter = ([onReady()]) async {
      if (gconfig.disabledLinks.contains(name)) {
        if (onReady != null) {
          onReady();
        }
        return null;
      }

      await setLinkState(name, "starting");

      String exe;
      var args = [];

      if (c.engines == null || c.engines.isEmpty) {
        exe = c.main;

        if ((exe.endsWith(".bat") || exe.endsWith(".exe")) && !Platform.isWindows) {
          exe = exe.substring(0, exe.length - 4);
        } else if (Platform.isWindows) {
          if (!exe.endsWith(".bat")) {
            exe = "${exe}.bat";
          }
        }

        if (Platform.isWindows) {
          exe = exe.replaceAll("/", "\\");
        }

        if (!pathlib.isAbsolute(exe)) {
          exe = pathlib.join(linkDir.path, exe);
        }
      } else {
        exe = c.engines.keys.first;

        if (exe == "dart") {
          try {
            exe = Platform.resolvedExecutable;
          } catch (e) {
            exe = Platform.executable;
          }

          if (exe == null || exe.isEmpty) {
            exe = await findExecutable("dart");
          }
        }

        if (exe == "java") {
          exe = await findExecutable("java");

          if (exe == null) {
            exe = "java";
          }

          args.add("-jar");
        }

        args.add(c.main);
      }

      var cfg = {};

      c.configs.keys.where((it) => c.configs[it]["value"] != null || c.configs[it]["default"] != null).forEach((x) {
        cfg[x] = c.configs[x]["value"] == null ? c.configs[x]["default"] : c.configs[x]["value"];
      });

      cfg.addAll(gconfig.linkConfig.containsKey(name) ? gconfig.linkConfig[name] : {});

      if (c.configs.containsKey("broker") && !cfg.containsKey("broker"))  {
        cfg["broker"] = getBrokerUrl();

        if (canUseRuntime && runtime != null && c.engines != null && c.engines.containsKey("dart")) {
          cfg["log-file"] = logFile.absolute.path;
        }
      }

      for (var m in c.configs.keys) {
        var l = c.configs[m];
        if (l["required"] == true && l["value"] == null && !cfg.containsKey(m)) {
          print("Error: DSLink '${name}' requires the config '${m}' to be specified.");
          if (onReady != null) {
            onReady();
          }
          return null;
        }
      }

      for (var cx in cfg.keys) {
        if (!c.configs.containsKey(cx) && cx != "log-file") {
          print("Warning: DSLink '${name}' was configured to have '${cx}' be '${cfg[cx]}', but that option was not found for this link.");
        }

        args.addAll(["--${cx}", "${cfg[cx]}"]);
      }

      doStart() async {
        if (runtime != null) {
          await runtime.startLink(linkDir.path, c.main, cfg);
          running = true;
          await setLinkState(name, "started");
          print("DSLink '${name}' started.");
          if (onReady != null) {
            onReady();
          }
          await runtime.onLinkEnd(linkDir.path).first;
          running = false;
          return null;
        }

        try {
          await exec(exe, args: args, outputFile: logFile, workingDirectory: path, handler: (Process proc) {
            if (onReady != null) {
              onReady();
            }
            print("DSLink '${name}' started.");
            running = true;
            setLinkState(name, "started");
            ourProc = proc;
            _linkProcesses.add(proc);
          }, outputHandler: (String stuff) {
            if (stuff.toLowerCase().contains("connected")) {
              setLinkState(name, "connected");
            }
          }, environment: {
            "DSA_LINK_NAME": name
          });
        } catch (e) {
          if (e is ProcessException) {
            if ((Platform.isLinux || Platform.isMacOS) && exe != "bash") {
              args.insert(0, exe);
              exe = "bash";
              return await doStart();
            }

            print("DSLink '${name}' errored during startup.");
            _linkProcesses.remove(ourProc);

            running = false;
            await setLinkState(name, "errored");
            noRestart = true;
            return null;
          }
        }
      }

      await doStart();

      try {
        if (ourProc != null) {
          await forceKill(ourProc.pid);
        }
      } catch (e) {}

      _linkProcesses.remove(ourProc);

      running = false;
      await setLinkState(name, "stopped");

      if (!reloadForced && !noRestart) {
        print("DSLink '${name}' suddenly stopped.");
        await new Future.delayed(const Duration(seconds: 1));
      } else {
        if (noRestart) {
          print("DSLink '${name}' is now stopped.");
        } else {
          print("DSLink '${name}' is now restarting.");
        }
      }

      if (!noRestart) {
        await starter();
      }

      noRestart = false;
    };

    if (shouldStartNow) {
      starter();
    } else {
      _startLinks.add(starter);
    }
  }

  List<Map<String, dynamic>> _basicLinkData;
}

const String LINK_REPO_URL = "https://iot-dsa.github.io/links/links.json";

Future<List<Map<String, dynamic>>> fetchLinkRepositoryInfo() async {
  return Convert.JSON.decode(Convert.UTF8.decode(await fetchUrl(LINK_REPO_URL)));
}

Future<String> updateLinkFromZip(Directory linkDir, String zipUrl, Map json) async {
  try {
    var allowDeleteUpdate = json["backupForUpdate"] == true;

    var backupFileMap = {};
    if (allowDeleteUpdate) {
      var protected = [
        "nodes.json",
        ".dslink.key"
      ];

      if (json["protectedFiles"] != null) {
        protected.addAll(json["protectedFiles"]);
      }

      for (var fn in protected) {
        var file = new File(pathlib.join(linkDir.path, fn));

        if (await file.exists()) {
          backupFileMap[fn] = await file.readAsBytes();
        }
      }
    }

    var zipData = await fetchUrl(zipUrl);
    await extractArchiveSmart(zipData, linkDir, handleSingleDirectory: true);

    if (allowDeleteUpdate) {
      for (var fn in backupFileMap.keys.toList()) {
        var value = backupFileMap.remove(fn);
        var file = new File(pathlib.join(linkDir.path, fn));
        await file.writeAsBytes(value);
      }
    }

    return "Success!";
  } catch (e) {
    return e.toString();
  }
}

Future<InstallResult> installLinkFromGit(String url, String name) async {
  var linksDir = new Directory("dslinks");

  if (!(await linksDir.exists())) {
    await linksDir.create(recursive: true);
  }

  var linkDir = new Directory("dslinks/${name}").absolute;

  if (await linkDir.exists()) {
    return new InstallResult.fail("A link of the name '${name}' already exists!");
  }

  var gitExecutable = await findExecutable("git");

  if (gitExecutable == null) {
    return new InstallResult.fail("Git is not installed.");
  }

  BetterProcessResult result = await exec(gitExecutable, args: ["clone", url, linkDir.path], outputFile: new File("logs/installer.log"), writeToBuffer: true);

  if (result.exitCode != 0) {
    String msg;

    if (result.stderr.contains("Could not resolve host")) {
      msg = "Failed to resolve host. Either this site does not exist, or you are not connected to the internet.";
    } else if (result.stderr.contains("does not exist")) {
      msg = "Repository does not exist.";
    } else {
      msg = result.stderr.toString();
    }

    return new InstallResult.fail(msg);
  } else {
    return new InstallResult.ok("Success!");
  }
}

Future<InstallResult> installLinkFromZip(String url, String name) async {
  var linksDir = new Directory("dslinks");

  if (!(await linksDir.exists())) {
    await linksDir.create(recursive: true);
  }

  var linkDir = new Directory("dslinks/${name}").absolute;

  if (await linkDir.exists()) {
    return new InstallResult.fail("A link of the name '${name}' already exists!");
  }

  await linkDir.create(recursive: true);

  try {
    List<int> bytes = await fetchUrl(url);

    await extractArchiveSmart(bytes, linkDir, handleSingleDirectory: true);

    return new InstallResult.ok("Success!");
  } catch (e) {
    return new InstallResult.fail(e.toString());
  }
}

class InstallResult {
  final bool success;
  final String message;

  InstallResult(this.success, this.message);

  InstallResult.ok(this.message) : success = true;
  InstallResult.fail(this.message) : success = false;
}

RuntimeManager dartRuntimeManager;
RuntimeManager javaRuntimeManager;

Future<RuntimeManager> getJavaRuntimeManager(List<Process> adds) async {
  if (startingJavaRuntimeManager) {
    print("Waiting for Java Runtime Manager to start.");
    while (true) {
      if (!startingJavaRuntimeManager) {
        break;
      }

      await new Future.delayed(const Duration(milliseconds: 5));
    }
    return javaRuntimeManager;
  }

  if (javaRuntimeManager != null) {
    return javaRuntimeManager;
  }

  startingJavaRuntimeManager = true;
  String javaExe = await findExecutable("java");

  if (javaExe == null) {
    javaExe = "java";
  }

  String path = pathlib.join("bin", "runtimes", "java.jar");

  var starter = () async {
    var proc = await Process.start(javaExe, ["-jar", path]);
    adds.add(proc);
    return proc;
  };

  var manager = new RuntimeManager(await starter(), logFile: new File("logs/runtime-java.log"), restart: starter, name: "Java");
  javaRuntimeManager = manager;
  startingJavaRuntimeManager = false;
  return manager;
}

bool startingDartRuntimeManager = false;
bool startingJavaRuntimeManager = false;

Future<RuntimeManager> getDartRuntimeManager(List<Process> adds) async {
  if (startingDartRuntimeManager) {
    print("Waiting for Dart Runtime Manager to start.");
    while (true) {
      if (!startingDartRuntimeManager) {
        break;
      }

      await new Future.delayed(const Duration(milliseconds: 5));
    }
    return dartRuntimeManager;
  }

  if (dartRuntimeManager != null) {
    return dartRuntimeManager;
  }

  startingDartRuntimeManager = true;

  String dartExe;
  String path = pathlib.join("bin", "runtime.dart");
  try {
    dartExe = Platform.resolvedExecutable;
  } catch (e) {
    dartExe = Platform.executable.isNotEmpty ? Platform.executable : "dart";
  }

  if (!(await new File(path).exists())) {
    path = pathlib.join("bin", "helpers", "runtime.dart");
  }

  var sf = new File(pathlib.join(pathlib.dirname(path), pathlib.basenameWithoutExtension(path) + ".snapshot")).absolute;
  if (await sf.exists()) {
    path = sf.path;
  }

  var starter = () async {
    var proc = await Process.start(dartExe, ["-Ddslink.runtime.manager=true", path]);
    adds.add(proc);
    return proc;
  };

  var manager = new RuntimeManager(await starter(), logFile: new File("logs/runtime-dart.log"), restart: starter, name: "Dart");
  dartRuntimeManager = manager;
  startingDartRuntimeManager = false;
  return manager;
}

bool noRestartRuntime = false;

class RuntimeManager {
  Process process;

  Stream onLinkEnd(String path) {
    return _endStream.stream.where((x) => x == path);
  }

  Stream onLinkReady(String path) {
    return _readyStream.stream.where((x) => x == path);
  }

  StreamController<String> _endStream = new StreamController.broadcast();
  StreamController<String> _readyStream = new StreamController.broadcast();

  RuntimeManager(this.process, {String name, File logFile, Future<Process> restart()}) {
    handle() async {
      IOSink raf;

      if (logFile != null) {
        if (!(await logFile.exists())) {
          await logFile.create(recursive: true);
        }

        raf = await logFile.openWrite(mode: FileMode.APPEND);
      }

      process.exitCode.then((code) async {
        print("${name == null ? "A" : name} runtime manager died: ${code}");
        try {
          raf.close();
        } catch (e) {}
        if (restart != null && !noRestartRuntime) {
          process = await restart();
          handle();
        }
      });

      process.stdout.transform(UTF8.decoder).listen((String data) {
        if (data.startsWith("\u0002") && data.trim().endsWith("\u0003")) {
          data = data.trim();
          var content = data.substring(1, data.length - 1);
          var json = JSON.decode(content);
          handleEvent(json);
        } else {
          if (raf != null) {
            try {
              raf.write(data);
              raf.flush();
            } catch (e) {}
          } else {
            stdout.write(data);
          }
        }
      });

      process.stderr.transform(UTF8.decoder).listen((String data) {
        if (raf != null) {
          try {
            raf.write(data);
            raf.flush();
          } catch (e) {}
        } else {
          stderr.write(data);
        }
      });
    }

    handle();
  }

  void handleEvent(Map json) {
    var event = json["event"];

    if (event == "fail") {
      _endStream.add(json["path"]);
    } else if (event == "stopped") {
      _endStream.add(json["path"]);
    } else if (event == "ready" || event == "started") {
      _readyStream.add(json["path"]);
    }
  }

  Future startLink(String path, String main, Map<String, dynamic> configs) {
    write({
      "event": "start",
      "path": path,
      "main": main,
      "configs": configs
    });

    return onLinkReady(path).first;
  }

  void stopLink(String path) {
    write({
      "event": "stop",
      "path": path
    });
  }

  void write(data) {
    var out = JSON.encode(data);

    process.stdin.write("\u0002" + out + "\u0003");
  }
}

/// DSLink SDK IO Utilities
library dslink.io;

import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:path/path.dart" as pathlib;
import "package:archive/archive.dart";
import "utils.dart" show currentTimestamp;
import "package:http/http.dart" as http;

/// Read raw text from stdin.
Stream<String> readStdinText() => stdin.transform(UTF8.decoder);

/// Read each line from stdin.
Stream<String> readStdinLines() =>
    readStdinText().transform(new LineSplitter());

/// Helpers for working with HTTP
class HttpHelper {
  /// Main HTTP Client
  static HttpClient client = new HttpClient();

  /// Creates an [HttpClientRequest] with the given parameters.
  /// [method] is the HTTP method.
  /// [url] is the URL to make the request to.
  /// [headers] specifies additional headers to set.
  static Future<HttpClientRequest> createRequest(String method, String url, {Map<String, String> headers}) async {
    var request = await client.openUrl(method, Uri.parse(url));
    if (headers != null) {
      headers.forEach(request.headers.set);
    }
    return request;
  }

  /// Reads the entire [response] as a list of bytes.
  static Future<List<int>> readBytesFromResponse(HttpClientResponse response) async {
    return await response.fold([], (a, b) {
      a.addAll(b);
      return a;
    });
  }

  /// Fetches the specified [url] from HTTP.
  /// If [headers] is specified, the headers will be added onto the request.
  static Future<String> fetchUrl(String url, {Map<String, String> headers}) async {
    var request = await createRequest("GET", url, headers: headers);
    var response = await request.close();
    return UTF8.decode(await readBytesFromResponse(response));
  }

  /// Fetches the specified [url] from HTTP as JSON.
  /// If [headers] is specified, the headers will be added onto the request.
  static Future<dynamic> fetchJSON(String url, {Map<String, String> headers}) async {
    return JSON.decode(await fetchUrl(url, headers: headers));
  }

  static const String _webSocketGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

  /// Custom WebSocket Connection logic.
  static Future<WebSocket> connectToWebSocket(
      String url, {Iterable<String> protocols, Map<String, dynamic> headers, HttpClient httpClient}) async {
    if (const bool.fromEnvironment("calzone.build", defaultValue: false)) {
      return await WebSocket.connect(url, protocols: protocols, headers: headers);
    }

    Uri uri = Uri.parse(url);
    if (uri.scheme != "ws" && uri.scheme != "wss") {
      throw new WebSocketException("Unsupported URL scheme '${uri.scheme}'");
    }

    Random random = new Random();
    // Generate 16 random bytes.
    Uint8List nonceData = new Uint8List(16);
    for (int i = 0; i < 16; i++) {
      nonceData[i] = random.nextInt(256);
    }
    String nonce = CryptoUtils.bytesToBase64(nonceData);

    uri = new Uri(
        scheme: uri.scheme == "wss" ? "https" : "http",
        userInfo: uri.userInfo,
        host: uri.host,
        port: uri.port,
        path: uri.path,
        query: uri.query,
      fragment: uri.fragment
    );

    HttpClient _client = httpClient == null ? (new HttpClient()
        ..badCertificateCallback = (a, b, c) => true) : httpClient;

    return _client.openUrl("GET", uri).then((HttpClientRequest request) {
      if (uri.userInfo != null && !uri.userInfo.isEmpty) {
        // If the URL contains user information use that for basic
        // authorization.
        String auth = CryptoUtils.bytesToBase64(UTF8.encode(uri.userInfo));
        request.headers.set(HttpHeaders.AUTHORIZATION, "Basic $auth");
      }
      if (headers != null) {
        headers.forEach((field, value) => request.headers.add(field, value));
      }
      // Setup the initial handshake.
      request.headers
        ..set(HttpHeaders.CONNECTION, "Upgrade")
        ..set(HttpHeaders.UPGRADE, "websocket")
        ..set("Sec-WebSocket-Key", nonce)
        ..set("Cache-Control", "no-cache")
        ..set("Sec-WebSocket-Version", "13");
      if (protocols != null) {
        request.headers.add("Sec-WebSocket-Protocol", protocols.toList());
      }
      return request.close();
    })
    .then((response) {
      void error(String message) {
        // Flush data.
        response.detachSocket().then((socket) {
          socket.destroy();
        });
        throw new WebSocketException(message);
      }
      if (response.statusCode != HttpStatus.SWITCHING_PROTOCOLS ||
        response.headers[HttpHeaders.CONNECTION] == null ||
        !response.headers[HttpHeaders.CONNECTION].any(
              (value) => value.toLowerCase() == "upgrade") ||
        response.headers.value(HttpHeaders.UPGRADE).toLowerCase() != "websocket") {
        error("Connection to '$uri' was not upgraded to websocket");
      }
      String accept = response.headers.value("Sec-WebSocket-Accept");
      if (accept == null) {
        error("Response did not contain a 'Sec-WebSocket-Accept' header");
      }
      SHA1 sha1 = new SHA1();
      sha1.add("$nonce$_webSocketGUID".codeUnits);
      List<int> expectedAccept = sha1.close();
      List<int> receivedAccept = CryptoUtils.base64StringToBytes(accept);
      if (expectedAccept.length != receivedAccept.length) {
        error("Reasponse header 'Sec-WebSocket-Accept' is the wrong length");
      }
      for (int i = 0; i < expectedAccept.length; i++) {
        if (expectedAccept[i] != receivedAccept[i]) {
          error("Bad response 'Sec-WebSocket-Accept' header");
        }
      }
      var protocol = response.headers.value('Sec-WebSocket-Protocol');
      return response.detachSocket()
        .then((socket) => new WebSocket.fromUpgradedSocket(socket, protocol: protocol, serverSide: false));
    });
  }
}

/// Generates a random socket port.
Future<int> getRandomSocketPort() async {
  var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4.address, 0);
  var port = server.port;
  await server.close();
  return port;
}

typedef void ProcessHandler(Process process);
typedef void OutputHandler(String str);

Stdin get _stdin => stdin;

class BetterProcessResult extends ProcessResult {
  final String output;

  BetterProcessResult(int pid, int exitCode, stdout, stderr, this.output) :
  super(pid, exitCode, stdout, stderr);
}

Future<String> createFileChecksum(File file) async {
  var bytes = await file.readAsBytes();
  var hash = new MD5();
  hash.add(bytes);
  var result = hash.close();
  return CryptoUtils.bytesToHex(result);
}

Future<bool> verifyFileChecksum(File file, String expected) async {
  var actual = await createFileChecksum(file);
  return expected == actual;
}

Future writeFileChecksum(File file) async {
  var path = file.path + ".md5";
  var checksumFile = new File(path);
  var checksum = await createFileChecksum(file);
  await checksumFile.writeAsString(checksum);
}

enum ChecksumState {
  CREATED, SAME, MODIFIED
}

Future<ChecksumState> doFileChecksum(String path) async {
  var file = new File(path);
  var checksumFile = new File(file.path + ".md5");

  if (!(await checksumFile.exists())) {
    await writeFileChecksum(file);
    return ChecksumState.CREATED;
  }

  var expect = (await checksumFile.readAsString()).trim();
  var result = await verifyFileChecksum(file, expect);

  if (result) {
    return ChecksumState.SAME;
  } else {
    await writeFileChecksum(file);
    return ChecksumState.MODIFIED;
  }
}

Future<BetterProcessResult> exec(
    String executable,
    {
    List<String> args: const [],
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    stdin,
    ProcessHandler handler,
    OutputHandler stdoutHandler,
    OutputHandler stderrHandler,
    OutputHandler outputHandler,
    File outputFile,
    bool inherit: false,
    bool writeToBuffer: false
    }) async {
  IOSink raf;

  if (outputFile != null) {
    if (!(await outputFile.exists())) {
      await outputFile.create(recursive: true);
    }

    raf = await outputFile.openWrite(mode: FileMode.APPEND);
  }

  try {
    Process process = await Process.start(
        executable,
        args,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell
    );

    if (raf != null) {
      await raf.writeln("[${currentTimestamp}] == Executing ${executable} with arguments ${args} (pid: ${process.pid}) ==");
    }

    var buff = new StringBuffer();
    var ob = new StringBuffer();
    var eb = new StringBuffer();

    process.stdout.transform(UTF8.decoder).listen((str) async {
      if (writeToBuffer) {
        ob.write(str);
        buff.write(str);
      }

      if (stdoutHandler != null) {
        stdoutHandler(str);
      }

      if (outputHandler != null) {
        outputHandler(str);
      }

      if (inherit) {
        stdout.write(str);
      }

      if (raf != null) {
        await raf.write("[${currentTimestamp}] ${str}");
      }
    });

    process.stderr.transform(UTF8.decoder).listen((str) async {
      if (writeToBuffer) {
        eb.write(str);
        buff.write(str);
      }

      if (stderrHandler != null) {
        stderrHandler(str);
      }

      if (outputHandler != null) {
        outputHandler(str);
      }

      if (inherit) {
        stderr.write(str);
      }

      if (raf != null) {
        await raf.write("[${currentTimestamp}] ${str}");
      }
    });

    if (handler != null) {
      handler(process);
    }

    if (stdin != null) {
      if (stdin is Stream) {
        stdin.listen(process.stdin.add, onDone: process.stdin.close);
      } else if (stdin is List) {
        process.stdin.add(stdin);
      } else {
        process.stdin.write(stdin);
        await process.stdin.close();
      }
    } else if (inherit) {
      _stdin.listen(process.stdin.add, onDone: process.stdin.close);
    }

    var code = await process.exitCode;
    var pid = process.pid;

    if (raf != null) {
      await raf.writeln("[${currentTimestamp}] == Exited with status ${code} ==");
      await raf.flush();
      await raf.close();
    }

    return new BetterProcessResult(
        pid,
        code,
        ob.toString(),
        eb.toString(),
        buff.toString()
    );
  } finally {
    if (raf != null) {
      await raf.flush();
      await raf.close();
    }
  }
}

Future<String> findExecutable(String name) async {
  var paths = Platform.environment["PATH"].split(Platform.isWindows ? ";" : ":");
  var tryFiles = [name];

  if (Platform.isWindows) {
    tryFiles.addAll(["${name}.exe", "${name}.bat"]);
  }

  for (var p in paths) {
    if (Platform.environment.containsKey("HOME")) {
      p = p.replaceAll("~/", Platform.environment["HOME"]);
    }

    var dir = new Directory(pathlib.normalize(p));

    if (!(await dir.exists())) {
      continue;
    }

    for (var t in tryFiles) {
      var file = new File("${dir.path}/${t}");

      if (await file.exists()) {
        return file.path;
      }
    }
  }

  return null;
}

Future<bool> isPortOpen(int port, {String host: "0.0.0.0"}) async {
  try {
    ServerSocket server = await ServerSocket.bind(host, port);
    await server.close();
    return true;
  } catch (e) {
    return false;
  }
}

bool _canUseSmartUnzip;

Future<bool> canUseSmartUnzip() async {
  if (_canUseSmartUnzip != null) {
    return _canUseSmartUnzip;
  }

  _canUseSmartUnzip = (
      Platform.isLinux ||
      Platform.isMacOS
  ) && (await findExecutable("bsdtar") != null);
  return _canUseSmartUnzip;
}

Future extractArchiveSmart(List<int> bytes, Directory dir, {bool handleSingleDirectory: false}) async {
  if (await canUseSmartUnzip()) {
    var cmd = await findExecutable("bsdtar");
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    var args = ["-C", dir.path, "-xvf-"];

    if (handleSingleDirectory) {
      BetterProcessResult ml = await exec(cmd, args: ["-tf-"], handler: (Process process) {
        process.stdin.add(bytes);
        process.stdin.close();
      }, writeToBuffer: true);
      List<String> contents = ml.stdout.split("\n");
      contents.removeWhere((x) => x == null || x.isEmpty || x.endsWith("/"));
      if (contents.every((l) => l.split("/").length > 1)) {
        args.addAll(["--strip-components", "1"]);
      }
    }

    var result = await exec(cmd, args: args, handler: (Process process) {
      process.stdin.add(bytes);
      process.stdin.close();
    });

    if (result.exitCode != 0) {
      throw new Exception("Failed to extract archive.");
    }
  } else {
    var files = await decompressZipFiles(bytes);
    await extractArchive(files, dir, handleSingleDirectory: handleSingleDirectory);
  }
}

Future extractArchive(Stream<ArchiveFile> files, Directory dir, {bool handleSingleDirectory: false}) async {
  var allFiles = await files.toList();

  if (handleSingleDirectory && allFiles.every((f) => f.name.split("/").length >= 2)) {
    allFiles.forEach((file) {
      file.name = file.name.split("/").skip(1).join("/");
    });

    allFiles.removeWhere((x) => x.name == "" || x.name == "/");
  }

  for (ArchiveFile f in allFiles) {
    if (!f.isFile || f.name.endsWith("/")) continue;

    var file = new File(pathlib.join(dir.path, f.name));
    if (!(await file.exists())) {
      await file.create(recursive: true);
    }

    await file.writeAsBytes(f.content);
  }
}

Stream<ArchiveFile> decompressZipFiles(List<int> data) async* {
  var decoder = new ZipDecoder();
  var archive = decoder.decodeBytes(data);
  for (var file in archive.files) {
    if (file.isCompressed) {
      file.decompress();
    }
    yield file;
  }
}

Stream<ArchiveFile> decompressTarFiles(List<int> data) async* {
  var decoder = new TarDecoder();
  var archive = decoder.decodeBytes(data);
  for (var file in archive.files) {
    if (file.isCompressed) {
      file.decompress();
    }
    yield file;
  }
}

Future generateSnapshotFile(String target, String input) async {
  var result = await Process.run(getDartExecutable(), [
    "--snapshot=${target}",
    input
  ]);

  if (result.exitCode != 0) {
    throw new Exception("Failed to generate snapshot for ${input}.");
  }
}

String getDartExecutable() {
  String dartExe;
  try {
    dartExe = Platform.resolvedExecutable;
  } catch (e) {
    dartExe = Platform.executable.isNotEmpty ? Platform.executable : "dart";
  }
  return dartExe;
}

Future<List<int>> fetchUrl(String url) async {
  http.Response response = await http.get(url);
  if (response.statusCode != 200) {
    throw new Exception("Failed to fetch url: got status code ${response.statusCode}");
  }
  return response.bodyBytes;
}

Future forceKill(int pid) async {
  if (Platform.isWindows) {
    await Process.run("taskkill", ["/F", "/T", "/PID", pid.toString()]);
  } else {
    await Process.run("pkill", ["-TERM", "-P", pid.toString()]);
    await Process.run("kill", ["-TERM", pid.toString()]);
  }
}

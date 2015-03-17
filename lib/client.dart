library dslink.client;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';

import 'common.dart';
import 'requester.dart';
import 'responder.dart';
import 'utils.dart';
import 'src/crypto/pk.dart';
import 'src/http/websocket_conn.dart';

export 'src/crypto/pk.dart';

part 'src/http/client_link.dart';
part 'src/http/client_http_conn.dart';

class LinkHelper {
  static HttpClientLink create(List<String> args, String prefix, PrivateKey key, {
      ArgParser argp,
      String command: "link",
      bool isRequester: true,
      bool isResponder: true,
      NodeProvider provider
  }) {
    if (argp == null) {
      argp = new ArgParser();
    }

    if (provider == null) {
      provider = new SimpleNodeProvider();
    }

    if (!argp.options.containsKey("help")) {
      argp.addFlag("help", abbr: "h", help: "Displays this Help Message");
    }

    var opts = argp.parse(args);

    if (opts["help"] || opts.rest.length != 1) {
      print("Usage: ${command} [options] url");
      if (argp.usage.isNotEmpty) {
        print(argp.usage);
        exit(1);
      }
    }

    var link = new HttpClientLink(
      opts.rest[0],
      prefix,
      key,
      nodeProvider: provider,
      isRequester: isRequester,
      isResponder: isResponder
    );

    return link;
  }
}

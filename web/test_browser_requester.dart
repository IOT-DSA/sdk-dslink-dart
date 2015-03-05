// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'package:dslink/src/crypto/pk.dart';
import 'package:dslink/browser_client.dart';
import 'package:dslink/requester.dart';
import 'dart:async';

main() async {
  querySelector('#output').text = 'Your Dart app is running.';
  
  PrivateKey key = new PrivateKey.loadFromString('M6S41GAL0gH0I97Hhy7A2-icf8dHnxXPmYIRwem03HE');

  var link = new BrowserECDHLink('http://localhost:8080/conn', 'test-browser-responder-', key,
      isRequester:true);

  link.connect();
  Requester requester = link.requester;//await link.onRequesterReady;
  
  Stream<RequesterListUpdate> updates = requester.list('/conns/locker-a');
  await for (RequesterListUpdate update in updates) {
    print(update.changes);
  }
}

// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'package:dslink/src/crypto/pk.dart';
import 'package:dslink/browser_client.dart';
import '../test/sample_responder.dart';

void main() {
  querySelector('#output').text = 'Your Dart app is running.';
  
  PrivateKey key = new PrivateKey.loadFromString('M6S41GAL0gH0I97Hhy7A2-icf8dHnxXPmYIRwem03HE');

  var link = new BrowserECDHLink('http://localhost:8080/conn', 'test-browser-responder-', key,
      isResponder: true, nodeProvider: new TestNodeProvider());

  var f = link.init();
  
}

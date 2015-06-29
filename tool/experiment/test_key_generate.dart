import 'package:dslink/src/crypto/pk.dart';
import 'dart:io';
import '../../lib/utils.dart';

 main() async{
  String rslt;

  if (Platform.isWindows) {
    rslt = Process.runSync('getmac', []).stdout.toString();
  } else {
    rslt = Process.runSync('ifconfig', []).stdout.toString();
  }

  // randomize the PRNG with the system mac
  DSRandom.instance.addEntropy(rslt);

  var t1 = (new DateTime.now()).millisecondsSinceEpoch;
  PrivateKey key ;
  for (int i=0; i< 50; ++i)
  // generate private key
  key = await PrivateKey.generate();

  var t2 = (new DateTime.now()).millisecondsSinceEpoch;

  print('takes ${t2-t1} ms to generate key');
  print('dsaId: ${key.publicKey.getDsId('my-dsa-test-')}');
  print('saved key:\n${key.saveToString()}');
  print('public key:\n${key.publicKey.qBase64}');
  //test token encrypt, decrypt
}

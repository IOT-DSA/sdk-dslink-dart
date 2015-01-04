import 'package:dslink/src/crypto/ds_pk.dart';
import 'dart:io';


void main(){
  String rslt;
  if (Platform.isWindows) {
    rslt = Process.runSync('ipconfig', ['/all']).stdout.toString();
  } else {
    rslt = Process.runSync('ifconfig', []).stdout.toString();
  }
  DsaRandom.instance.randomize(rslt);
  
  var t1 = (new DateTime.now()).millisecondsSinceEpoch;
  // generate private key
  DsPrivateKey key = new DsPrivateKey.generate();
  var t2 = (new DateTime.now()).millisecondsSinceEpoch;
  
  print('takes ${t2-t1} ms to generate key');
  
  //test token encrypt, decrypt
  DsSecretToken token = new DsSecretToken.generate();
  String enctyptedTokenStr = key.publicKey.enctyptToke(token);
  var rsltToken = key.decryptToke(enctyptedTokenStr);
  
  print('original token:  ${token.toString()}');
  print('decrypted token: ${rsltToken.toString()}');
}
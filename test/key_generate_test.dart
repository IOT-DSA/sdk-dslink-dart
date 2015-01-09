import 'package:dslink/src/crypto/ds_pk.dart';
import 'dart:io';

void main() {
  String rslt;
  if (Platform.isWindows) {
    rslt = Process.runSync('getmac', []).stdout.toString();
  } else {
    rslt = Process.runSync('ifconfig', []).stdout.toString();
  }
  // randomize the PRNG with the system mac
  DsaRandom.instance.randomize(rslt);
  
  var t1 = (new DateTime.now()).millisecondsSinceEpoch;
  // generate private key
  DsPrivateKey key = new DsPrivateKey.generate();
  var t2 = (new DateTime.now()).millisecondsSinceEpoch;
  
  print('takes ${t2-t1} ms to generate key');
  print('dsaId: ${key.publicKey.getDsaId('my-dsa-test')}');
  print('public key: ${key.publicKey.modulusBase64}');
  //test token encrypt, decrypt
  DsSecretNonce token = new DsSecretNonce.generate();
  String enctyptedTokenStr = key.publicKey.encryptNonce(token);
  var rsltToken = key.decryptNonce(enctyptedTokenStr);
  
  print('original token:  ${token.toString()}');
  print('decrypted token: ${rsltToken.toString()}');
  
  
  String salt = "request 1";
  String saltHash = token.hashSalt(salt);
  print('token hash of "$salt": $saltHash,  verified: ${rsltToken.verifySalt(salt, saltHash)}');
}
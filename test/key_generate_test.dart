import 'package:dslink/src/crypto/pk.dart';
import 'dart:io';

void main() {
  String rslt;

  if (Platform.isWindows) {
    rslt = Process.runSync('getmac', []).stdout.toString();
  } else {
    rslt = Process.runSync('ifconfig', []).stdout.toString();
  }

  // randomize the PRNG with the system mac
  DSRandom.instance.randomize(rslt);

  var t1 = (new DateTime.now()).millisecondsSinceEpoch;
  // generate private key
  PrivateKey key = new PrivateKey.generate();
  var t2 = (new DateTime.now()).millisecondsSinceEpoch;

  print('takes ${t2-t1} ms to generate key');
  print('dsaId: ${key.publicKey.getDsId('my-dsa-test-')}');
  print('saved key:\n${key.saveToString()}');
  //test token encrypt, decrypt
  SecretNonce token = new SecretNonce.generate();
  String enctyptedTokenStr = key.publicKey.encryptNonce(token);
  var rsltToken = key.decryptNonce(enctyptedTokenStr);

  print('original token:  ${token.toString()}');
  print('decrypted token: ${rsltToken.toString()}');

  String salt = "request 1";
  String saltHash = token.hashSalt(salt);
  print(
      'token hash of "$salt": $saltHash,  verified: ${rsltToken.verifySalt(salt, saltHash)}');
}

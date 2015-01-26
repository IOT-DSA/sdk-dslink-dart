import 'package:dslink/src/crypto/pk.dart';
import 'package:bignum/bignum.dart';
import 'package:dslink/utils.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cipher/digests/sha256.dart';

String m =
    'jjxTpOaEQO4SlZQAGYlMHIEJvz6mDWQlxUW7uMOiSe2Dg60wu8I3pnQ0HDHYTQ35rP2i80WmEbaScTVz-oITO7Lh0470_epOtuwDWezEomdP2dheiGI4jageiJ0ratZ0VqQi63thfGOaBGpG15-TUaDNRUSyB8JQlGWJrojS5lIcVsnkq129mgBOFJCUzLWBp0fwbFBve1T3cYLrPoLQgIQPINiMnokw-iRjp-C9o8cqbh1WBBQOeSxg97AD4L-0mO6NgzhXZ_jjwaJG10e9BHQkvatwU-PFivnasH_fXbyXJqs-plWCQY462Ook2xer_94gCVT8gFubBalBjluw3Q';
String e =
    'eBMZkdZAxAe3jKrawrQTmuScc-TRjfCDqlxKM5qEQODP67Ojtn4pOM5Ux5CUx8gKhS3CCJk9rypvyj6T4GE7F2TWHCFNVaYeOXJZCetFvMx2rrNoar5we7X3wODeLF1K7XG3QRBxpe73sM5_a7x9Q6X6ZIWvvbkfCYgGiV9cm65nps4UTTmBnnh6GXcDFx9uPD5uPeMowtZh-bHzFfEYCj9dBaPfa9mQhHtqFODH8TpTOCDB8iPsJpl7loFmQQZzTRq6qr1UfPzRmfhJi_b_zdj8r5_gUEL8593StiXMIcPYlTnmUPRZtWjpFrlu3H4xEIMkPzowLqhp8KKotFGSCQ';
String salt = '0x100';
Uint8List nonceBytes = new Uint8List.fromList([
  0xd2,
  0x65,
  0x38,
  0xaa,
  0xbf,
  0x9a,
  0x97,
  0xbc,
  0xfd,
  0x8b,
  0xc0,
  0xdd,
  0x1a,
  0x72,
  0x7c,
  0x92
]);
String encryptedNonceCompare =
    'YM2x5wEChxriLalS8tD5l2hlV6MUU-MmqbUNyDz5dUl1x8sNt7cBdh0MLc7mSb8Ohx-Q2_tW-i9fA0WQNFdWIdDZfNziUF4snFtZjez77eOSXFns4j51ZMdGXeWGRrlF5F1pGtIorFfMaofbD-QjX-VIe-TD-6QJDHVL9larXxVS2lnxY5YDhS1niHY-MXCBVUMPt9b9OOz87GTUlTu1mZJbq004mU_Du81D8j7aRNbaSIKmYWPJpoqW00yNXkADQZmVL8xVxyEApMrDF9VQMo1cNle5Tyxtvn79fF7zNE6On0JDaRg0ozP_fjV2-V_afr-OkStIWh5K_zBHfH1Xyg';
String authCompare = 'MRxHkgT_dEszsB3kWe3HSu1Z8V1c1Z_uTvxP66-Nx0Y';
BigInteger modulus = new BigInteger.fromBytes(1, Base64.decode(m));
BigInteger privateExp = new BigInteger.fromBytes(1, Base64.decode(e));

void main() {
  testAlgorithm();
  testApi();
  print('All Tests Passed!');
}

void testAlgorithm() {

  /// Initialize connection , Client -> Server
  Uint8List modulusHash =
      new SHA256Digest().process(bigintToUint8List(modulus));
  String dsId = 'test-${Base64.encode(modulusHash)}';
  __assertEqual(
      dsId, 'test-pTrfpbVWb3NNAhMIXr_FpmV3oObtMVxPcNu2mDksp0M', 'dsId');

  /// Initialize connection , Server -> Client

  BigInteger A = new BigInteger.fromBytes(1, nonceBytes);
  BigInteger E = A.modPow(new BigInteger(65537), modulus);
  String encryptedNonce = Base64.encode(bigintToUint8List(E));
  __assertEqual(encryptedNonce, encryptedNonceCompare, 'encryptedNonce');

  /// Start Connection (http or ws), Client -> Server
  /// Decode

  BigInteger decodeE = new BigInteger.fromBytes(
      1, Base64.decode(encryptedNonce));
  __assertEqual(decodeE, E, 'decoded E');

  BigInteger decryptedA = E.modPow(privateExp, modulus);
  __assertEqual(decryptedA, A, 'decrypted A');

  Uint8List decryptedNonce = bigintToUint8List(decryptedA);
  __assertEqual(
      bytes2hex(decryptedNonce), bytes2hex(nonceBytes), 'decrypted Nonce');

  /// Make Auth

  List<int> authRaw = new Uint8List.fromList([]
    ..addAll(UTF8.encode(salt))
    ..addAll(decryptedNonce));
  __assertEqual(bytes2hex(authRaw),
      '3078313030d26538aabf9a97bcfd8bc0dd1a727c92', 'auth raw');

  Uint8List digest = new SHA256Digest().process(authRaw);
  String auth = Base64.encode(digest);
  __assertEqual(auth, authCompare, 'auth');
}

void testApi() {
  PrivateKey prikey = new PrivateKey(modulus, privateExp);
  PublicKey pubkey = prikey.publicKey;

  /// Initialize connection , Client -> Server

  String dsId = pubkey.getDsId('test-');
  __assertEqual(
      dsId, 'test-pTrfpbVWb3NNAhMIXr_FpmV3oObtMVxPcNu2mDksp0M', 'API dsId');

  /// Initialize connection , Server -> Client
  SecretNonce nonce = new SecretNonce(nonceBytes);
  String encryptedNonce = pubkey.encryptNonce(nonce);

  __assertEqual(encryptedNonce, encryptedNonceCompare, 'encryptedNonce');

  /// Start Connection (http or ws), Client -> Server
  /// Decode
  SecretNonce decryptedNonce = prikey.decryptNonce(encryptedNonce);
  __assertEqual(bytes2hex(decryptedNonce.bytes),
      bytes2hex(nonceBytes), 'API decrypted Nonce');

  /// Make Auth
  String auth = decryptedNonce.hashSalt(salt);
  __assertEqual(auth, authCompare, 'API auth');
}
void __assertEqual(a, b, String testName) {
  if (a != b) {
    print('$testName Test Failed\na: $a\nb: $b');
    throw 0;
  }
}

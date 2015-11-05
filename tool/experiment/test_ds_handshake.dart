import 'package:dslink/src/crypto/pk.dart';
import 'package:dslink/src/crypto/dart/pk.dart';

String clientPrivate = "M6S41GAL0gH0I97Hhy7A2-icf8dHnxXPmYIRwem03HE";
String clientPublic = "BEACGownMzthVjNFT7Ry-RPX395kPSoUqhQ_H_vz0dZzs5RYoVJKA16XZhdYd__ksJP0DOlwQXAvoDjSMWAhkg4";
String clientDsId = "test-s-R9RKdvC2VNkfRwpNDMMpmT_YWVbhPLfbIc-7g4cpc";
String serverTempPrivate = "rL23cF6HxmEoIaR0V2aORlQVq2LLn20FCi4_lNdeRkk";
String serverTempPublic = "BCVrEhPXmozrKAextseekQauwrRz3lz2sj56td9j09Oajar0RoVR5Uo95AVuuws1vVEbDzhOUu7freU0BXD759U";
String sharedSecret = "116128c016cf380933c4b40ffeee8ef5999167f5c3d49298ba2ebfd0502e74e3";
String hashedAuth = "V2P1nwhoENIi7SqkNBuRFcoc8daWd_iWYYDh_0Z01rs";

void main() {
  //testAlgorithm();
  testApi();
  print('All Tests Passed!');
}

//void testAlgorithm() {
//
//  /// Initialize connection , Client -> Server
//  Uint8List modulusHash = new SHA256Digest().process(bigintToUint8List(modulus));
//  String dsId = 'test-${Base64.encode(modulusHash)}';
//  __assertEqual(dsId, 'test-pTrfpbVWb3NNAhMIXr_FpmV3oObtMVxPcNu2mDksp0M', 'dsId');
//
//  /// Initialize connection , Server -> Client
//
//  BigInteger A = new BigInteger.fromBytes(1, nonceBytes);
//  BigInteger E = A.modPow(new BigInteger(65537), modulus);
//  String encryptedNonce = Base64.encode(bigintToUint8List(E));
//  __assertEqual(encryptedNonce, encryptedNonceCompare, 'encryptedNonce');
//
//  /// Start Connection (http or ws), Client -> Server
//  /// Decode
//
//  BigInteger decodeE = new BigInteger.fromBytes(1, Base64.decode(encryptedNonce));
//  __assertEqual(decodeE, E, 'decoded E');
//
//  BigInteger decryptedA = E.modPow(privateExp, modulus);
//  __assertEqual(decryptedA, A, 'decrypted A');
//
//  Uint8List decryptedNonce = bigintToUint8List(decryptedA);
//  __assertEqual(bytes2hex(decryptedNonce), bytes2hex(nonceBytes), 'decrypted Nonce');
//
//  /// Make Auth
//
//  List<int> authRaw = new Uint8List.fromList([]
//    ..addAll(UTF8.encode(salt))
//    ..addAll(decryptedNonce));
//  __assertEqual(bytes2hex(authRaw), '3078313030d26538aabf9a97bcfd8bc0dd1a727c92', 'auth raw');
//
//  Uint8List digest = new SHA256Digest().process(authRaw);
//  String auth = Base64.encode(digest);
//  __assertEqual(auth, authCompare, 'auth');
//}

testApi() async {
  PrivateKey prikey = new PrivateKey.loadFromString(clientPrivate);
  PublicKey pubkey = prikey.publicKey;

  __assertEqual(pubkey.qBase64, clientPublic, 'API public key');

  /// Initialize connection , Client -> Server

  String dsId = pubkey.getDsId('test-');
  __assertEqual(dsId, clientDsId, 'API dsId');

  /// Initialize connection , Server -> Client
  PrivateKey tPrikey = new PrivateKey.loadFromString(serverTempPrivate);
  PublicKey tPubkey = tPrikey.publicKey;

  __assertEqual(tPubkey.qBase64, serverTempPublic, 'API temp key');


  /// Start Connection (http or ws), Client -> Server
  /// Decode
  ECDHImpl clientEcdh = await prikey.getSecret(tPubkey.qBase64);
  ECDHImpl serverEcdh = await tPrikey.getSecret(pubkey.qBase64);

  __assertEqual(bytes2hex(clientEcdh.bytes), sharedSecret, 'API client ECDH');
  __assertEqual(bytes2hex(serverEcdh.bytes), sharedSecret, 'API server ECDH');

  /// Make Auth
  String auth = serverEcdh.hashSalt('0000');
  __assertEqual(auth, hashedAuth, 'API auth');
}
void __assertEqual(a, b, String testName) {
  if (a != b) {
    print('$testName Test Failed\na: $a\nb: $b');
    throw 0;
  }
}

library util.consts;

import 'dart:math' as Math;
import "dart:io";

import "package:bignum/bignum.dart";
const double_NAN = double.NAN;
const double_NEGATIVE_INFINITY = double.NEGATIVE_INFINITY;
const double_INFINITY = double.INFINITY;
const Math_PI = Math.PI;
const double_MAX_FINITE = double.MAX_FINITE;
const Math_E = Math.E;
const Math_LN2 = Math.LN2;
const Math_LN10 = Math.LN10;
const Math_LOG2E = Math.LOG2E;
const Math_LOG10E = Math.LOG10E;
const Math_SQRT2 = Math.SQRT2;
const Math_SQRT1_2 = Math.SQRT1_2;
const Duration_ZERO = Duration.ZERO;

void socketJoinMulticast(RawDatagramSocket socket, InternetAddress group, [NetworkInterface interface]) {
  socket.joinMulticast(group, interface: interface);
}

List<int> bigIntegerToByteArray(data) {
  return (data as BigInteger).toByteArray();
}

String bigIntegerToRadix(value, int radix) {
  return (value as BigInteger).toRadix(radix);
}

dynamic newBigInteger([a, b, c]) {
  return new BigInteger(a,b,c);
  }

dynamic newBigIntegerFromBytes(int signum, List<int> magnitude) {
  return new BigInteger.fromBytes(signum, magnitude);
}

/// A type representing values that are either `Future<T>` or `T`.
///
/// This class declaration is a public stand-in for an internal
/// future-or-value generic type. References to this class are resolved to the
/// internal type.
///
/// It is a compile-time error for any class to extend, mix in or implement
/// `FutureOr`.
///
/// Note: the `FutureOr<T>` type is interpreted as `dynamic` in non strong-mode.
///
/// # Examples
/// ``` dart
/// // The `Future<T>.then` function takes a callback [f] that returns either
/// // an `S` or a `Future<S>`.
/// Future<S> then<S>(FutureOr<S> f(T x), ...);
///
/// // `Completer<T>.complete` takes either a `T` or `Future<T>`.
/// void complete(FutureOr<T> value);
/// ```
///
/// # Advanced
/// The `FutureOr<int>` type is actually the "type union" of the types `int` and
/// `Future<int>`. This type union is defined in such a way that
/// `FutureOr<Object>` is both a super- and sub-type of `Object` (sub-type
/// because `Object` is one of the types of the union, super-type because
/// `Object` is a super-type of both of the types of the union). Together it
/// means that `FutureOr<Object>` is equivalent to `Object`.
///
/// As a corollary, `FutureOr<Object>` is equivalent to
/// `FutureOr<FutureOr<Object>>`, `FutureOr<Future<Object>>` is equivalent to
/// `Future<Object>`.
abstract class FutureOr<T> {
  // Private generative constructor, so that it is not subclassable, mixable, or
  // instantiable.
  FutureOr._() {
    throw new UnsupportedError("FutureOr can't be instantiated");
  }
}

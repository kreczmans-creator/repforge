import 'dart:convert';

/// SHA-256 (FIPS 180-4) of [data] as 64 lowercase hexadecimal characters.
///
/// Pure Dart, so the library domain needs no package (engineering standards
/// section 3). The same algorithm as the test helper in
/// `test/migration_v8/migration_digest.dart`; a test checks both against the
/// FIPS 180-4 examples and against each other. Each element of [data] is one
/// byte (0 to 255).
String sha256Hex(List<int> data) => (Sha256()..add(data)).closeHex();

/// SHA-256 of the UTF-8 encoding of [text] (as `sha256Hex(utf8.encode(text))`)
/// without a copy of the whole encoding: the text is encoded and hashed in
/// slices (WP 8 3b-10, Review C M-1: a backup of tens of megabytes).
String sha256HexOfUtf8(String text) {
  final hash = Sha256();
  final sink = utf8.encoder.startChunkedConversion(_HashSink(hash));
  const slice = 1 << 16;
  if (text.isEmpty) {
    sink.close();
  } else {
    for (var start = 0; start < text.length; start += slice) {
      final end = start + slice < text.length ? start + slice : text.length;
      // The encoder carries a surrogate pair split between two slices.
      sink.addSlice(text, start, end, end == text.length);
    }
  }
  return hash.closeHex();
}

final class _HashSink implements Sink<List<int>> {
  _HashSink(this.hash);

  final Sha256 hash;

  @override
  void add(List<int> data) => hash.add(data);

  @override
  void close() {}
}

/// Incremental SHA-256 (FIPS 180-4): [add] bytes in any number of parts,
/// then [closeHex] once. Holds one 64-byte block, never the whole input.
final class Sha256 {
  static const int _mask = 0xffffffff;

  final List<int> _h = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  final List<int> _block = List<int>.filled(64, 0);
  final List<int> _w = List<int>.filled(64, 0);
  int _blockLength = 0;
  int _byteLength = 0;
  bool _closed = false;

  /// Adds [data]; each element must be one byte (0 to 255).
  void add(List<int> data) {
    if (_closed) throw StateError('SHA-256 already closed');
    for (final b in data) {
      if (b < 0 || b > 255) {
        throw ArgumentError.value(b, 'data', 'every element must be a byte');
      }
      _block[_blockLength++] = b;
      if (_blockLength == 64) {
        _compress();
        _blockLength = 0;
      }
    }
    _byteLength += data.length;
  }

  /// Pads, finishes and returns the digest as 64 lowercase hexadecimal
  /// characters.
  String closeHex() {
    if (_closed) throw StateError('SHA-256 already closed');
    _closed = true;
    final bitLength = _byteLength * 8;
    _block[_blockLength++] = 0x80;
    if (_blockLength > 56) {
      while (_blockLength < 64) {
        _block[_blockLength++] = 0;
      }
      _compress();
      _blockLength = 0;
    }
    while (_blockLength < 56) {
      _block[_blockLength++] = 0;
    }
    for (var i = 7; i >= 0; i--) {
      _block[_blockLength++] = (bitLength >> (i * 8)) & 0xff;
    }
    _compress();
    return _h.map((x) => x.toRadixString(16).padLeft(8, '0')).join();
  }

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

  void _compress() {
    final w = _w;
    final block = _block;
    for (var i = 0; i < 16; i++) {
      final j = i * 4;
      w[i] =
          (block[j] << 24) |
          (block[j + 1] << 16) |
          (block[j + 2] << 8) |
          block[j + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & _mask;
    }
    final h = _h;
    var a = h[0];
    var b = h[1];
    var c = h[2];
    var d = h[3];
    var e = h[4];
    var f = h[5];
    var g = h[6];
    var hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & _mask) & g);
      final t1 = (hh + s1 + ch + _k[i] + w[i]) & _mask;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & _mask;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & _mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _mask;
    }
    h[0] = (h[0] + a) & _mask;
    h[1] = (h[1] + b) & _mask;
    h[2] = (h[2] + c) & _mask;
    h[3] = (h[3] + d) & _mask;
    h[4] = (h[4] + e) & _mask;
    h[5] = (h[5] + f) & _mask;
    h[6] = (h[6] + g) & _mask;
    h[7] = (h[7] + hh) & _mask;
  }
}

const List<int> _k = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

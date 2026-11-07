import 'package:repforge/domain/library/sha256_hex.dart';

/// Algorithm name recorded with a release hash (R-10).
const String releaseHashAlgorithm = 'sha256';

/// Encoding name recorded with a release hash (R-10).
const String releaseHashEncoding = 'hex-lower';

/// The content hash of a bundled file: SHA-256 over its exact bytes, lowercase
/// hex (64 characters). Nothing is parsed or re-serialised first (R-10).
String releaseContentHash(List<int> bytes) => sha256Hex(bytes);

final RegExp _hash = RegExp(r'^[0-9a-f]{64}$');

/// True for 64 lowercase hexadecimal characters.
bool isReleaseContentHash(String value) => _hash.hasMatch(value);

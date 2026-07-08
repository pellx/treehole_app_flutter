import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class PoWChallenge {
  final String challengeId;
  final String challenge;
  final int difficulty;

  const PoWChallenge({
    required this.challengeId,
    required this.challenge,
    required this.difficulty,
  });

  factory PoWChallenge.fromJson(Map<String, dynamic> json) {
    return PoWChallenge(
      challengeId: json['challenge_id'] as String,
      challenge: json['challenge'] as String,
      difficulty: json['difficulty'] as int,
    );
  }
}

class PoWService {
  static const _timeout = Duration(seconds: 30);
  static const _maxIterations = 200_000_000;

  /// 在后台 isolate 中暴力搜索 nonce，30 秒超时
  static Future<int?> solve(PoWChallenge c) async {
    debugPrint('[PoW] challenge="${c.challenge}", difficulty=${c.difficulty}');
    final sw = Stopwatch()..start();
    try {
      final result = await Isolate.run(() => _solveSync(c))
          .timeout(_timeout, onTimeout: () {
        debugPrint('[PoW] TIMEOUT after ${sw.elapsedMilliseconds}ms');
        return null;
      });
      sw.stop();
      if (result != null) {
        debugPrint('[PoW] Solved nonce=$result in ${sw.elapsedMilliseconds}ms');
      } else {
        debugPrint('[PoW] Failed (null) after ${sw.elapsedMilliseconds}ms');
      }
      return result;
    } catch (e) {
      sw.stop();
      debugPrint('[PoW] Exception after ${sw.elapsedMilliseconds}ms: $e');
      return null;
    }
  }

  static int? _solveSync(PoWChallenge c) {
    final inputBase = utf8.encode(c.challenge);
    int nonce = 0;
    while (nonce < _maxIterations) {
      final nonceStr = nonce.toString();
      final input = Uint8List(inputBase.length + nonceStr.length);
      input.setAll(0, inputBase);
      for (int i = 0; i < nonceStr.length; i++) {
        input[inputBase.length + i] = nonceStr.codeUnitAt(i);
      }
      final hash = sha256.convert(input).bytes;
      if (_checkDifficulty(hash, c.difficulty)) return nonce;
      nonce++;
    }
    return null; // 超限未找到
  }

  static bool _checkDifficulty(List<int> hash, int bits) {
    int fullBytes = bits ~/ 8;
    int remainingBits = bits % 8;
    for (int i = 0; i < fullBytes; i++) {
      if (hash[i] != 0) return false;
    }
    if (remainingBits > 0) {
      int mask = 0xFF << (8 - remainingBits);
      if ((hash[fullBytes] & mask) != 0) return false;
    }
    return true;
  }
}

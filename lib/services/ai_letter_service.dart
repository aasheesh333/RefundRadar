import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:refund_radar/data/models/dispute.dart';

/// Remaining free-tier AI drafting quota for the current moment.
class AiQuota {
  final int remainingToday;
  final int secondsUntilNextAllowed;

  const AiQuota({
    required this.remainingToday,
    required this.secondsUntilNextAllowed,
  });

  bool get canGenerate => remainingToday > 0 && secondsUntilNextAllowed <= 0;
}

/// Sealed-ish result for AI letter generation — match on the concrete type.
sealed class AiLetterResult {
  const AiLetterResult();
}

class Ok extends AiLetterResult {
  final String letterText;
  const Ok(this.letterText);
}

class RateLimited extends AiLetterResult {
  final Duration retryAfter;
  const RateLimited(this.retryAfter);
}

class Unavailable extends AiLetterResult {
  const Unavailable();
}

class Failed extends AiLetterResult {
  final String message;
  const Failed(this.message);
}

/// Gemini REST drafting service for ombudsman complaints.
///
/// Free-tier key is injected at build time via
/// `--dart-define GEMINI_API_KEY=...`; when absent the service reports
/// itself unavailable and callers should show a friendly offline note.
///
/// Quotas (persisted in SharedPreferences):
/// - max 10 generations per calendar day ('ai_letter_day' = 'yyyy-MM-dd:count')
/// - min 2 minutes between generations ('ai_letter_last_ts', epoch millis)
class AiLetterService {
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const int dailyLimit = 10;
  static const Duration minGap = Duration(minutes: 2);

  static const String _dayKey = 'ai_letter_day';
  static const String _lastTsKey = 'ai_letter_last_ts';
  static const String adGateFirstDoneKey = 'ai_letter_first_ad_done';

  bool get isAvailable => apiKey.isNotEmpty;

  Future<AiQuota> quota() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _dayString(now);

    var count = 0;
    final stored = prefs.getString(_dayKey);
    if (stored != null && stored.startsWith('$today:')) {
      count = int.tryParse(stored.split(':').last) ?? 0;
    }

    var wait = 0;
    final lastTs = prefs.getInt(_lastTsKey);
    if (lastTs != null) {
      final elapsed =
          (now.millisecondsSinceEpoch - lastTs) ~/ 1000;
      wait = (minGap.inSeconds - elapsed).clamp(0, minGap.inSeconds);
    }

    return AiQuota(
      remainingToday: (dailyLimit - count).clamp(0, dailyLimit),
      secondsUntilNextAllowed: wait,
    );
  }

  Future<AiLetterResult> generate(
    Dispute dispute, {
    required String merchantOrBankName,
  }) async {
    if (!isAvailable) return const Unavailable();

    final q = await quota();
    if (!q.canGenerate) {
      return RateLimited(Duration(seconds: q.secondsUntilNextAllowed));
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-3.6-flash:generateContent?key=$apiKey',
    );
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _buildPrompt(dispute, merchantOrBankName)},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.4},
    });

    String letter;
    try {
      final res = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              // Required by the Android-apps key restriction set in Google
              // Cloud console (package + release SHA-1 of our signing key).
              'X-Android-Package': 'com.dhanuk.refundradar',
              'X-Android-Cert':
                  '65E76FB3510E9B3A788CCADFACB8A68F40EC8AFF',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        return Failed('Gemini API error ${res.statusCode}');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      final content =
          candidates?.firstOrNull?['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      letter = (parts?.firstOrNull?['text'] as String?)?.trim() ?? '';
      if (letter.isEmpty) return const Failed('Empty response from Gemini');
    } catch (e) {
      debugPrint('AiLetterService: generate failed: $e');
      return const Failed('Could not reach the AI service. Try again later.');
    }

    // Count only successful generations towards quotas.
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _dayString(now);
    final stored = prefs.getString(_dayKey);
    final count = (stored != null && stored.startsWith('$today:'))
        ? (int.tryParse(stored.split(':').last) ?? 0)
        : 0;
    await prefs.setString(_dayKey, '$today:${count + 1}');
    await prefs.setInt(_lastTsKey, now.millisecondsSinceEpoch);

    return Ok(letter);
  }

  String _dayString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _buildPrompt(Dispute dispute, String merchantOrBankName) {
    final l1Date = dispute.filedDates['l1'] ?? dispute.createdAt;
    final l1Ticket = dispute.ticketNumbers['l1'] ?? 'ticket number pending';
    return '''
You are helping an Indian consumer draft a complaint to the Reserve Bank of India (RBI) Banking Ombudsman under the Integrated Ombudsman Scheme (RB-IOS, 2021/2026).

Write a professional, formal complaint letter (under 500 words) addressed to the Banking Ombudsman against "$merchantOrBankName" (the bank / payment system participant).

Known facts (weave them in naturally — do not invent others):
- Transaction date: ${_fmtDate(dispute.txnDate)}
- Dispute type: ${dispute.type.id.toUpperCase()} failed transaction / wrong deduction
- Amount debited: Rs. ${dispute.amount.toStringAsFixed(0)}
- Transaction / UTR reference: ${dispute.txnId.isEmpty ? '[Transaction ID]' : dispute.txnId}
- Entity: ${dispute.entityName ?? merchantOrBankName}
- A complaint was filed with the entity on ${_fmtDate(l1Date)} (complaint no: $l1Ticket) with no satisfactory resolution.
- Current status: ${dispute.status.value}
${dispute.description != null && dispute.description!.isNotEmpty ? '- Additional notes from the complainant: ${dispute.description}' : ''}

Structure the letter as:
1. Subject line.
2. Complainant details with fill-in placeholders like [Your Name], [Account No.], [Address], [Email], [Phone] for information the app does not have — keep the placeholders so the user can fill them in before sending.
3. Facts in numbered chronological points using the dates, amounts and references above.
4. Grounds: deficiency in service under the RBI Integrated Ombudsman Scheme; reference RBI's TAT Harmonisation circular for failed transactions (Rs. 100/day compensation where applicable).
5. Relief sought: refund of Rs. ${dispute.amount.toStringAsFixed(0)} plus statutory compensation.
6. List of enclosures (transaction proof, complaint acknowledgement).
7. Formal closing with [Your Name] placeholder.

Rules:
- Under 500 words, formal but plain English.
- Do NOT claim to give legal advice or guarantee any outcome.
- Do NOT invent facts, dates, amounts, or complaint numbers beyond those given; use [bracketed placeholders] for missing details.
''';
  }
}

/// App-wide singleton, mirroring [adsServiceProvider].
final aiLetterServiceProvider =
    Provider<AiLetterService>((ref) => AiLetterService());

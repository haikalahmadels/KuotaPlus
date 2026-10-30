import '../../../core/api_client.dart';
import '../../../core/format.dart';
import '../../auth/data/auth_repository.dart';

/// Satu pilihan jumlah di `GET /quota-transfers/quote`. Pilihan yang tidak boleh tetap dikirim dengan [reason] (FR-14.3).
class ShareOption {
  const ShareOption({
    required this.bytes,
    required this.pointsCost,
    required this.allowed,
    this.reason,
    this.recipientExpiresAt,
    this.senderRemainingAfter,
  });

  factory ShareOption.fromJson(Map<String, dynamic> json) => ShareOption(
        bytes: json['bytes'] as int,
        pointsCost: json['points_cost'] as int,
        allowed: json['allowed'] as bool,
        reason: json['reason'] as String?,
        recipientExpiresAt:
            json['recipient_expires_at'] == null ? null : DateTime.parse(json['recipient_expires_at'] as String),
        senderRemainingAfter: json['sender_main_remaining_after'] as int?,
      );

  final int bytes;
  final int pointsCost;
  final bool allowed;
  final String? reason;
  final DateTime? recipientExpiresAt;
  final int? senderRemainingAfter;
}

/// `GET /quota-transfers/quote` (FR-14.2–14.8).
class ShareQuote {
  const ShareQuote({
    required this.recipientMasked,
    required this.recipientHasAccount,
    required this.limitBytes,
    required this.usedBytes,
    required this.remainingBytes,
    required this.recoversAt,
    required this.senderRemainingBytes,
    required this.pointsBalance,
    required this.options,
  });

  factory ShareQuote.fromJson(Map<String, dynamic> json) {
    final allowance = json['allowance'] as Map<String, dynamic>;
    final recipient = json['recipient'] as Map<String, dynamic>;
    return ShareQuote(
      recipientMasked: recipient['msisdn_masked'] as String,
      recipientHasAccount: recipient['has_account'] as bool,
      limitBytes: allowance['limit_bytes'] as int,
      usedBytes: allowance['used_30d_bytes'] as int,
      remainingBytes: allowance['remaining_bytes'] as int,
      recoversAt: allowance['recovers_at'] == null ? null : parseDate(allowance['recovers_at'] as String),
      senderRemainingBytes: json['sender_main_remaining_bytes'] as int,
      pointsBalance: json['points_balance'] as int,
      options: [for (final o in json['options'] as List) ShareOption.fromJson(o as Map<String, dynamic>)],
    );
  }

  final String recipientMasked;
  final bool recipientHasAccount;
  final int limitBytes;
  final int usedBytes;

  /// Sisa jatah berbagi 30 hari.
  final int remainingBytes;

  /// Tanggal transfer tertua keluar dari jendela 30 hari; null jika belum pernah berbagi.
  final DateTime? recoversAt;
  final int senderRemainingBytes;
  final int pointsBalance;
  final List<ShareOption> options;
}

/// Item `POST /quota-transfers` dan `GET /quota-transfers`.
class QuotaTransfer {
  const QuotaTransfer({
    required this.id,
    required this.recipientMasked,
    required this.bytes,
    required this.pointsSpent,
    required this.recipientExpiresAt,
    required this.status,
    this.completedAt,
    this.senderRemainingAfter,
  });

  factory QuotaTransfer.fromJson(Map<String, dynamic> json) => QuotaTransfer(
        id: json['id'] as int,
        recipientMasked: json['recipient_msisdn_masked'] as String,
        bytes: json['bytes'] as int,
        pointsSpent: json['points_spent'] as int,
        recipientExpiresAt: DateTime.parse(json['recipient_expires_at'] as String),
        status: json['status'] as String,
        completedAt: json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
        senderRemainingAfter: json['sender_main_remaining_after'] as int?,
      );

  final int id;
  final String recipientMasked;
  final int bytes;
  final int pointsSpent;
  final DateTime recipientExpiresAt;

  /// completed | failed
  final String status;
  final DateTime? completedAt;

  /// Hanya di respons POST.
  final int? senderRemainingAfter;
}

class QuotaTransferPage {
  const QuotaTransferPage(this.items, {required this.hasMore});

  final List<QuotaTransfer> items;
  final bool hasMore;
}

class ShareRepository {
  ShareRepository(this._api);

  final ApiClient _api;

  Future<ShareQuote> quote(String recipientMsisdn) async {
    final body = await _api.get('/quota-transfers/quote', query: {'recipient_msisdn': recipientMsisdn});
    return ShareQuote.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// OTP dikirim ke nomor pengirim dan terikat ke penerima + jumlah (FR-14.10).
  Future<OtpChallenge> requestOtp(String recipientMsisdn, int bytes) async {
    final body = await _api.post('/quota-transfers/otp', data: {'recipient_msisdn': recipientMsisdn, 'bytes': bytes});
    final data = body['data'] as Map<String, dynamic>;
    return OtpChallenge(
      msisdn: recipientMsisdn,
      expiresAt: DateTime.parse(data['expires_at'] as String),
      resendAvailableAt: DateTime.parse(data['resend_available_at'] as String),
      demoOtp: data['demo_otp'] as String?,
    );
  }

  /// [idempotencyKey] dibuat sekali per niat berbagi dan dipakai ulang untuk setiap percobaan ulang (FR-14.11).
  Future<QuotaTransfer> execute({
    required String recipientMsisdn,
    required int bytes,
    required String otpCode,
    required String idempotencyKey,
  }) async {
    final body = await _api.post(
      '/quota-transfers',
      idempotencyKey: idempotencyKey,
      data: {'recipient_msisdn': recipientMsisdn, 'bytes': bytes, 'otp_code': otpCode},
    );
    return QuotaTransfer.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<QuotaTransferPage> list({int page = 1}) async {
    final body = await _api.get('/quota-transfers', query: {'page': page}) as Map<String, dynamic>;
    final meta = body['meta'] as Map<String, dynamic>;
    return QuotaTransferPage(
      [for (final t in body['data'] as List) QuotaTransfer.fromJson(t as Map<String, dynamic>)],
      hasMore: (meta['current_page'] as int) < (meta['last_page'] as int),
    );
  }
}

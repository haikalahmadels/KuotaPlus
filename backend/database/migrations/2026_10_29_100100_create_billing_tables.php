<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Satu baris per nomor per tujuan: kirim ulang memperbarui baris yang sama, jadi hitungan salah tidak ter-reset.
        Schema::create('otp_codes', function (Blueprint $table) {
            $table->id();
            $table->string('msisdn', 15);
            $table->string('purpose', 16); // login | quota_transfer
            $table->json('context')->nullable();
            $table->string('code_hash')->nullable(); // null setelah dipakai
            $table->timestamp('sent_at');
            $table->timestamp('expires_at');
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->timestamp('locked_until')->nullable();
            $table->timestamps();

            $table->unique(['msisdn', 'purpose']);
        });

        // Satu-satunya pintu masuk perubahan pulsa dan paket.
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->string('type', 16); // package | topup
            $table->foreignId('package_id')->nullable()->constrained();
            $table->unsignedInteger('topup_amount')->nullable();
            $table->unsignedInteger('gross_amount');
            $table->unsignedInteger('discount_amount')->default(0);
            $table->unsignedInteger('points_used')->default(0);
            $table->unsignedInteger('net_amount');
            $table->string('payment_method', 16); // pulsa | ewallet | va | qris
            $table->string('status', 16); // pending | paid | failed | expired
            $table->uuid('idempotency_key');
            $table->char('request_hash', 64);
            $table->unsignedBigInteger('recommendation_id')->nullable(); // FK ditambahkan setelah tabel recommendations ada
            $table->string('external_ref', 32)->unique();
            $table->json('payment_payload')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'idempotency_key']);
            $table->index(['status', 'expires_at']);
        });

        // Log mentah semua callback, termasuk yang ditolak.
        Schema::create('payment_callbacks', function (Blueprint $table) {
            $table->id();
            $table->string('external_ref', 64)->index();
            $table->json('payload');
            $table->boolean('signature_valid');
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();
        });

        // Paket milik nomor (bukan akun), supaya penerima berbagi kuota tanpa akun Kuota+ tetap punya paket.
        Schema::create('subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('subscriber_id')->constrained();
            $table->string('source', 16)->default('purchase'); // purchase | shared
            $table->foreignId('package_id')->nullable()->constrained();
            $table->foreignId('transaction_id')->nullable()->constrained();
            $table->unsignedBigInteger('main_total');
            $table->unsignedBigInteger('main_used')->default(0);
            $table->unsignedBigInteger('app_total')->default(0);
            $table->unsignedBigInteger('app_used')->default(0);
            $table->string('app_category', 16)->nullable(); // disalin dari paket saat dibeli
            $table->timestamp('started_at');
            $table->timestamp('expires_at');
            $table->string('status', 16)->default('active'); // active | exhausted | expired
            $table->timestamps();

            $table->index(['subscriber_id', 'status', 'expires_at']);
        });

        // Saldo poin = SUM(delta). remaining dipakai untuk FIFO kedaluwarsa pada baris earn.
        Schema::create('point_ledger', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->integer('delta');
            $table->string('type', 16); // earn_daily | earn_streak | redeem_hold | redeem_release | spend_share | expire
            $table->string('ref_type', 32)->nullable();
            $table->unsignedBigInteger('ref_id')->nullable();
            $table->integer('remaining')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
        });

        Schema::create('quota_transfers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sender_user_id')->constrained('users');
            $table->foreignId('recipient_subscriber_id')->constrained('subscribers');
            $table->unsignedBigInteger('bytes');
            $table->unsignedInteger('points_spent');
            $table->foreignId('recipient_subscription_id')->nullable()->constrained('subscriptions');
            $table->timestamp('expires_at');
            $table->uuid('idempotency_key');
            $table->char('request_hash', 64);
            $table->string('status', 16); // completed | failed
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->unique(['sender_user_id', 'idempotency_key']);
            $table->index(['sender_user_id', 'completed_at']);
        });

        Schema::create('quota_transfer_sources', function (Blueprint $table) {
            $table->id();
            $table->foreignId('quota_transfer_id')->constrained();
            $table->foreignId('subscription_id')->constrained();
            $table->unsignedBigInteger('bytes');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('quota_transfer_sources');
        Schema::dropIfExists('quota_transfers');
        Schema::dropIfExists('point_ledger');
        Schema::dropIfExists('subscriptions');
        Schema::dropIfExists('payment_callbacks');
        Schema::dropIfExists('transactions');
        Schema::dropIfExists('otp_codes');
    }
};

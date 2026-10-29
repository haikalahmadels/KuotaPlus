<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('usage_records', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->foreignId('app_id')->constrained();
            $table->date('usage_date');
            $table->unsignedBigInteger('bytes_mobile');
            $table->unsignedBigInteger('bytes_applied')->default(0); // sudah dipotong dari kuota, dasar hitung delta
            $table->string('source', 16); // device | demo
            $table->timestamp('synced_at');
            $table->timestamps();

            $table->unique(['user_id', 'app_id', 'usage_date']);
            $table->index(['user_id', 'usage_date']);
        });

        // Baris terbaru = prediksi aktif.
        Schema::create('forecasts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->timestamp('computed_at');
            $table->unsignedBigInteger('avg_daily_bytes')->nullable();
            $table->unsignedBigInteger('remaining_bytes')->nullable();
            $table->timestamp('predicted_empty_at')->nullable();
            $table->timestamp('main_expires_at'); // paket utama yang dipakai untuk status dan jatah harian
            $table->unsignedBigInteger('daily_budget_bytes')->nullable();
            $table->string('confidence', 8); // high | low | none
            $table->string('status', 8)->nullable(); // safe | risk
            $table->timestamps();

            $table->index(['user_id', 'computed_at']);
        });

        Schema::create('daily_evaluations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->date('eval_date');
            $table->unsignedBigInteger('usage_bytes');
            $table->unsignedBigInteger('budget_bytes');
            $table->string('result', 8); // hemat | boros | no_data
            $table->unsignedInteger('streak_after');
            $table->timestamps();

            $table->unique(['user_id', 'eval_date']);
        });

        // Satu batch per perhitungan, dikenali dari computed_at.
        Schema::create('recommendations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->timestamp('computed_at');
            $table->foreignId('package_id')->constrained();
            $table->unsignedTinyInteger('rank');
            $table->unsignedBigInteger('need_bytes');
            $table->unsignedInteger('cost_30d');
            $table->integer('saving_30d')->nullable();
            $table->unsignedBigInteger('leftover_bytes');
            $table->text('reason');
            $table->timestamp('shown_at')->nullable();
            $table->timestamp('clicked_at')->nullable();
            $table->foreignId('purchased_transaction_id')->nullable()->constrained('transactions');
            $table->timestamps();

            $table->index(['user_id', 'computed_at']);
        });

        Schema::table('transactions', function (Blueprint $table) {
            $table->foreign('recommendation_id')->references('id')->on('recommendations');
        });

        // Batas 1 notifikasi per jenis per hari.
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->string('kind', 32);
            $table->date('notified_on');
            $table->json('payload');
            $table->timestamp('delivered_at')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'kind', 'notified_on']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropForeign(['recommendation_id']);
        });
        Schema::dropIfExists('recommendations');
        Schema::dropIfExists('daily_evaluations');
        Schema::dropIfExists('forecasts');
        Schema::dropIfExists('usage_records');
    }
};

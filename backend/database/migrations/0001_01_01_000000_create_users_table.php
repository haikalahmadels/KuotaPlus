<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Data "milik operator". Satu nomor = satu subscriber.
        Schema::create('subscribers', function (Blueprint $table) {
            $table->id();
            $table->string('msisdn', 15)->unique();
            $table->unsignedInteger('pulsa_balance')->default(0);
            $table->date('active_until');
            $table->date('grace_until')->nullable();
            $table->string('status', 16)->default('active'); // active | grace | terminated
            $table->timestamps();
        });

        // Akun aplikasi, dibuat saat login pertama.
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->foreignId('subscriber_id')->unique()->constrained();
            $table->string('name')->nullable();
            $table->timestamp('last_login_at')->nullable();
            $table->string('platform', 16)->nullable(); // android | web
            $table->boolean('usage_access_granted')->default(false);
            $table->timestamp('usage_access_checked_at')->nullable();
            $table->timestamps();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sessions');
        Schema::dropIfExists('users');
        Schema::dropIfExists('subscribers');
    }
};

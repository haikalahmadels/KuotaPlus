<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admins', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password');
            $table->rememberToken();
            $table->timestamp('last_login_at')->nullable();
            $table->timestamps();
        });

        Schema::create('settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->json('value');
            $table->bigInteger('min')->nullable();
            $table->bigInteger('max')->nullable();
            $table->boolean('is_system')->default(false);
            $table->foreignId('updated_by_admin_id')->nullable()->constrained('admins');
            $table->timestamps();
        });

        // Hanya bisa ditambah. Tidak ada updated_at karena baris tidak pernah diubah.
        Schema::create('admin_audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('admin_id')->constrained();
            $table->string('action', 16); // create | update | delete
            $table->string('entity_type');
            $table->unsignedBigInteger('entity_id');
            $table->json('before')->nullable();
            $table->json('after')->nullable();
            $table->string('ip', 45)->nullable();
            $table->timestamp('created_at')->useCurrent();
        });

        Schema::create('apps', function (Blueprint $table) {
            $table->id();
            $table->string('package_name')->unique();
            $table->string('label');
            $table->string('category', 16); // video | sosmed | game | belajar | umum | sistem
            $table->boolean('is_reviewed')->default(false);
            $table->timestamps();
        });

        Schema::create('packages', function (Blueprint $table) {
            $table->id();
            $table->string('code', 16)->unique();
            $table->string('name');
            $table->string('type', 16); // harian | mingguan | bulanan | aplikasi
            $table->unsignedInteger('price');
            $table->unsignedBigInteger('main_quota');
            $table->unsignedBigInteger('app_quota')->default(0);
            $table->string('app_category', 16)->nullable();
            $table->unsignedSmallInteger('validity_days');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('packages');
        Schema::dropIfExists('apps');
        Schema::dropIfExists('admin_audit_logs');
        Schema::dropIfExists('settings');
        Schema::dropIfExists('admins');
    }
};

<?php

namespace App\Support;

/** Format angka untuk kalimat yang dibaca pengguna (insight, alasan rekomendasi). */
final class Format
{
    private const MB = 1048576;

    private const GB = 1073741824;

    /** 950 MB, 1,5 GB, 15 GB (1 GB = 1024 MB). */
    public static function bytes(int $bytes): string
    {
        return $bytes < self::GB ? round($bytes / self::MB).' MB' : self::decimal($bytes / self::GB).' GB';
    }

    /** Selalu dalam GB: 0,5 GB, 1,5 GB. Untuk jumlah berbagi kuota yang berkelipatan setengah GB (FR-14.3). */
    public static function gb(int $bytes): string
    {
        return self::decimal($bytes / self::GB).' GB';
    }

    /** 52,1 / 40 (tanpa ,0). */
    public static function decimal(float $value): string
    {
        return rtrim(rtrim(number_format($value, 1, ',', '.'), '0'), ',');
    }

    public static function rupiah(int $amount): string
    {
        return 'Rp'.number_format($amount, 0, ',', '.');
    }
}

<?php

namespace App\Http\Resources;

/** Item `GET /transactions`: tanpa objek payment dan subscription_id (docs/API-KuotaPlus.md). */
class TransactionSummaryResource extends TransactionResource
{
    protected bool $withPayment = false;
}

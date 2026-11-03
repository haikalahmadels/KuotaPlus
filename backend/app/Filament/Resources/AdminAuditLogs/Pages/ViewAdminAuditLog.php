<?php

namespace App\Filament\Resources\AdminAuditLogs\Pages;

use App\Filament\Resources\AdminAuditLogs\AdminAuditLogResource;
use Filament\Resources\Pages\ViewRecord;

class ViewAdminAuditLog extends ViewRecord
{
    protected static string $resource = AdminAuditLogResource::class;
}

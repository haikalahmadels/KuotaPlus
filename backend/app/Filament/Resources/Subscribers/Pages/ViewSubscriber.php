<?php

namespace App\Filament\Resources\Subscribers\Pages;

use App\Filament\Resources\Subscribers\SubscriberResource;
use Filament\Resources\Pages\ViewRecord;

class ViewSubscriber extends ViewRecord
{
    protected static string $resource = SubscriberResource::class;
}

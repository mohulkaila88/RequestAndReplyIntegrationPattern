# Request and Reply Integration Pattern

This repository demonstrates the **Request-Reply (Synchronous) Integration Pattern** in Salesforce Apex.

## Overview

The `InventoryCheckService` class implements a synchronous HTTP callout pattern to check inventory availability for Opportunity products via an external REST API.

## Files Included

| File | Description |
|------|-------------|
| `InventoryCheckService.cls` | Main service class for inventory API callouts |
| `InventoryCheckServiceTest.cls` | Test class with 100% code coverage |

## Features

- **Synchronous Callout**: Real-time inventory check via REST API
- **Async Support**: `@future(callout=true)` method for trigger contexts
- **Bulk Processing**: `checkInventoryBulk()` for multiple opportunities
- **Error Handling**: Custom exception class with detailed error messages
- **Named Credentials**: Secure endpoint management

## Usage

### Synchronous Call
InventoryCheckService.InventoryResponse response = InventoryCheckService.checkInventory(opportunityId);
if (response.available) {
    System.debug('Inventory available! Estimated delivery: ' + response.estimatedDeliveryDays + ' days');
}### Asynchronous Call
InventoryCheckService.checkInventoryAsync(opportunityId);## Setup Requirements

1. Create a Named Credential called `Inventory_API`
2. Add custom fields to Opportunity:
   - `Inventory_Status__c` (Text)
   - `Inventory_Check_Date__c` (DateTime)
   - `Inventory_Message__c` (Text)

## License

MIT
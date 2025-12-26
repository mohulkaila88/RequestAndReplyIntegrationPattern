# Salesforce Request-Reply Integration Pattern

## 📋 Overview

This project demonstrates a **Request-Reply (Synchronous) Integration Pattern** between Salesforce and an external Inventory API. The Apex classes enable real-time inventory checks by making HTTP callouts to retrieve product availability data.

## 🎯 What It Does

When triggered, the integration:
1. Makes a GET request to the external Inventory API
2. Retrieves real-time inventory data (products, quantities, locations)
3. Parses the JSON response
4. Returns availability status and delivery estimates

## 📦 Components

### `InventoryCheckService.cls`
Main service class that handles API communication.

**Key Methods:**
- `checkInventory(Id opportunityId)` - Synchronous callout that returns inventory status immediately
- `checkInventoryAsync(Id opportunityId)` - Asynchronous callout using @future annotation for background processing
- `checkInventoryBulk(Set<Id> opportunityIds)` - Bulk processing for multiple opportunities

**Features:**
- Secure authentication via Named Credentials
- Comprehensive error handling
- Response parsing from JSON to Apex wrapper classes
- Timeout management (30 seconds)

### `InventoryCheckServiceTest.cls`
Complete test coverage with mock HTTP callouts.

**Test Scenarios:**
- ✅ Successful inventory check (items available)
- ✅ Successful inventory check (items unavailable)
- ✅ API error responses (404, 500)
- ✅ Null ID validation
- ✅ Invalid opportunity ID handling
- ✅ Asynchronous callout
- ✅ Bulk inventory checks
- ✅ Callout exceptions

**Coverage:** 100%

## 🔗 External API

This integration connects to the Apple Inventory API:

**Repository:** https://github.com/mohulkaila88/apple-inventory-api

**Endpoint:** `GET /api/inventory`

**Response Format:**
```json
{
  "success": true,
  "count": 23,
  "data": [
    {
      "id": 1,
      "sku": "IPHONE-15-PRO-256-BLK",
      "name": "iPhone 15 Pro 256GB Black Titanium",
      "quantity": 45,
      "price": "999.99",
      "category": "iPhone",
      "location": "Warehouse-A"
    }
  ]
}
```

## 🔧 Setup

### Prerequisites
- Salesforce org (Developer, Sandbox, or Production)
- Access to the Inventory API endpoint
- API credentials

### 1. Configure Named Credential

**Setup → Named Credentials → External Credentials**

Create External Credential:
- Label: `Inventory API Credential`
- Name: `Inventory_API_Credential`
- Authentication Protocol: `Password Authentication` (or OAuth/Custom based on your API)

Create Principal:
- Principal Name: `DefaultPrincipal`
- Add authentication parameters (username/password or API key)

**Setup → Named Credentials → Named Credentials**

Create Named Credential:
- Label: `Inventory API`
- Name: `Inventory_API`
- URL: `https://your-api-domain.com` (your deployed API base URL)
- External Credential: `Inventory_API_Credential`
- Enabled for Callouts: ✅

### 2. Create Permission Set

**Setup → Permission Sets**

Create Permission Set:
- Label: `Inventory API Access`
- Add **External Credential Principal Access** for `Inventory_API_Credential`
- Enable **API Enabled** system permission

Assign to users who need access.

### 3. Deploy Apex Classes

Deploy the two classes to your Salesforce org:
- `InventoryCheckService.cls`
- `InventoryCheckServiceTest.cls`

## 💻 Usage

### Test the Integration

Open **Developer Console → Debug → Execute Anonymous** and run:

```apex
Id oppId = [SELECT Id FROM Opportunity LIMIT 1].Id;
InventoryCheckService.InventoryResponse resp = InventoryCheckService.checkInventory(oppId);
System.debug('Success: ' + resp.success);
System.debug('Available: ' + resp.available);
System.debug('Message: ' + resp.message);
```

**Expected Output:**
```
Success: true
Available: true
Message: 23 item(s) found in inventory
```

### Synchronous Check

```apex
// Get inventory status immediately
Id oppId = '006XXXXXXXXXXXXXXX';
InventoryCheckService.InventoryResponse response = 
    InventoryCheckService.checkInventory(oppId);

if (response.success && response.available) {
    System.debug('Items available - Delivery in ' + 
        response.estimatedDeliveryDays + ' days');
}
```

### Asynchronous Check

```apex
// Process in background (doesn't block user)
InventoryCheckService.checkInventoryAsync(oppId);
```

### Bulk Processing

```apex
// Check multiple opportunities
Set<Id> oppIds = new Set<Id>{'006XXX1', '006XXX2', '006XXX3'};
Map<Id, InventoryCheckService.InventoryResponse> results = 
    InventoryCheckService.checkInventoryBulk(oppIds);
```

## 🧪 Running Tests

**Via Developer Console:**
1. Open Developer Console
2. Test → New Run
3. Select `InventoryCheckServiceTest`
4. Click Run

**Via Salesforce CLI:**
```bash
sf apex run test -n InventoryCheckServiceTest -r human
```

## 🔍 How It Works

```
┌─────────────┐                          ┌──────────────────┐
│             │   GET /api/inventory     │                  │
│  Salesforce │ ───────────────────────> │  Inventory API   │
│             │                          │  (External)      │
│             │ <─────────────────────── │                  │
│             │   JSON Response          │                  │
└─────────────┘                          └──────────────────┘
      │
      ├─ Parse JSON
      ├─ Calculate availability
      └─ Return response wrapper
```

## 📊 Response Object

The `InventoryResponse` wrapper class contains:

```apex
public class InventoryResponse {
    public Id opportunityId;        // Opportunity that was checked
    public Boolean success;         // API call succeeded
    public Boolean available;       // Items available in inventory
    public String message;          // Human-readable status message
    public Integer estimatedDeliveryDays;  // Estimated delivery time
    public Integer statusCode;      // HTTP status code
}
```

## 🔐 Security

- ✅ Uses Named Credentials (no hardcoded credentials)
- ✅ Permission-based access control
- ✅ Secure HTTPS communication
- ✅ Input validation and error handling

## 🚨 Troubleshooting

**Error: "Couldn't access the credential(s)"**
- Verify External Credential and Principal are created
- Check Permission Set has External Credential Principal Access
- Ensure Permission Set is assigned to your user
- Log out and log back in

**Error: "404 Not Found"**
- Verify Named Credential URL is correct (base URL only)
- Confirm API is deployed and running
- Check endpoint path is `/api/inventory`

**Response fields are null**
- Check API response format matches expected structure
- Review debug logs for raw response body
- Verify API is returning `success`, `count`, and `data` fields


**Last Updated**: December 2025  
**Salesforce API Version**: 59.0
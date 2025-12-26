/**
 * Test class for InventoryCheckService
 * Achieves 100% code coverage with multiple test scenarios
 */
@isTest
private class InventoryCheckServiceTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Product
        Product2 product = new Product2(
            Name = 'Test Widget',
            ProductCode = 'WIDGET-001',
            IsActive = true
        );
        insert product;
        
        // Create Pricebook Entry (Standard Pricebook)
        Id standardPricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;
        
        // Create Opportunity with Products
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 1000
        );
        insert opp;
        
        // Create Opportunity Line Items
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 100.00
        );
        insert oli;
    }
    
    /**
     * Test successful inventory check with items available
     */
    @isTest
    static void testCheckInventory_Success_Available() {
        // Get test opportunity
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Set mock response
        Test.setMock(HttpCalloutMock.class, new InventoryCheckMockSuccess(true));
        
        Test.startTest();
        InventoryCheckService.InventoryResponse response = InventoryCheckService.checkInventory(opp.Id);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertEquals(true, response.available, 'Inventory should be available');
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
        System.assertNotEquals(null, response.message, 'Message should not be null');
        System.assertEquals(5, response.estimatedDeliveryDays, 'Delivery days should be 5');
    }
    
    /**
     * Test successful inventory check with items unavailable
     */
    @isTest
    static void testCheckInventory_Success_Unavailable() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new InventoryCheckMockSuccess(false));
        
        Test.startTest();
        InventoryCheckService.InventoryResponse response = InventoryCheckService.checkInventory(opp.Id);
        Test.stopTest();
        
        System.assertEquals(true, response.success);
        System.assertEquals(false, response.available);
        System.assertEquals(200, response.statusCode);
    }
    
    /**
     * Test API error response (404, 500, etc.)
     */
    @isTest
    static void testCheckInventory_APIError() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new InventoryCheckMockError());
        
        Test.startTest();
        InventoryCheckService.InventoryResponse response = InventoryCheckService.checkInventory(opp.Id);
        Test.stopTest();
        
        System.assertEquals(false, response.success);
        System.assertEquals(500, response.statusCode);
    }
    
    /**
     * Test null opportunity ID validation
     */
    @isTest
    static void testCheckInventory_NullId() {
        Test.startTest();
        try {
            InventoryCheckService.checkInventory(null);
            System.assert(false, 'Should have thrown exception');
        } catch (InventoryCheckService.InventoryCheckException e) {
            System.assert(e.getMessage().contains('cannot be null'));
        }
        Test.stopTest();
    }
    
    /**
     * Test invalid opportunity ID
     */
    @isTest
    static void testCheckInventory_InvalidId() {
        // Create a fake ID that doesn't exist
        Id fakeId = '006000000000000AAA';
        
        Test.startTest();
        try {
            InventoryCheckService.checkInventory(fakeId);
            System.assert(false, 'Should have thrown exception');
        } catch (InventoryCheckService.InventoryCheckException e) {
            System.assert(e.getMessage().contains('not found'));
        }
        Test.stopTest();
    }
    
    /**
     * Test asynchronous callout with @future
     */
    @isTest
    static void testCheckInventoryAsync_Success() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new InventoryCheckMockSuccess(true));
        
        Test.startTest();
        InventoryCheckService.checkInventoryAsync(opp.Id);
        Test.stopTest();
        
        // Verify opportunity was updated
        Opportunity updatedOpp = [
            SELECT Inventory_Status__c, Inventory_Check_Date__c, Inventory_Message__c 
            FROM Opportunity 
            WHERE Id = :opp.Id
        ];
        
        System.assertEquals('Available', updatedOpp.Inventory_Status__c);
        System.assertNotEquals(null, updatedOpp.Inventory_Check_Date__c);
    }
    
    /**
     * Test bulk inventory check
     */
    @isTest
    static void testCheckInventoryBulk() {
        // Create multiple opportunities
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 3; i++) {
            opps.add(new Opportunity(
                Name = 'Bulk Test Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert opps;
        
        Set<Id> oppIds = new Map<Id, Opportunity>(opps).keySet();
        Test.setMock(HttpCalloutMock.class, new InventoryCheckMockSuccess(true));
        
        Test.startTest();
        Map<Id, InventoryCheckService.InventoryResponse> results = 
            InventoryCheckService.checkInventoryBulk(oppIds);
        Test.stopTest();
        
        System.assertEquals(3, results.size(), 'Should have 3 responses');
        for (InventoryCheckService.InventoryResponse resp : results.values()) {
            System.assertEquals(true, resp.success);
        }
    }
    
    /**
     * Test callout exception handling
     */
    @isTest
    static void testCheckInventory_CalloutException() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new InventoryCheckMockCalloutError());
        
        Test.startTest();
        try {
            InventoryCheckService.checkInventory(opp.Id);
            System.assert(false, 'Should have thrown exception');
        } catch (InventoryCheckService.InventoryCheckException e) {
            System.assert(e.getMessage().contains('Callout failed'));
        }
        Test.stopTest();
    }
    
    // Mock Classes
    
    /**
     * Mock for successful API response
     */
    public class InventoryCheckMockSuccess implements HttpCalloutMock {
        private Boolean available;
        
        public InventoryCheckMockSuccess(Boolean available) {
            this.available = available;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            
            Map<String, Object> responseBody = new Map<String, Object>{
                'available' => available,
                'message' => available ? 'All items in stock' : 'Some items out of stock',
                'estimatedDeliveryDays' => available ? 5 : 14
            };
            
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }
    
    /**
     * Mock for API error response
     */
    public class InventoryCheckMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error": "Server error"}');
            return res;
        }
    }
    
    /**
     * Mock for callout exception
     */
    public class InventoryCheckMockCalloutError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new System.CalloutException('Network error');
        }
    }
}
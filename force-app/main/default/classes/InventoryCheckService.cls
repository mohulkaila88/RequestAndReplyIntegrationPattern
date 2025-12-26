/**
 * Service class to check inventory via REST API callout
 * Implements Request-Reply pattern for synchronous communication
 */
public class InventoryCheckService {
    
    // Named Credential for secure endpoint management
    private static final String NAMED_CREDENTIAL = 'callout:Inventory_API';
    private static final String ENDPOINT_PATH = '/api/inventory';
    private static final Integer TIMEOUT = 30000; // 30 seconds
    
    /**
     * Synchronous method to check inventory for an Opportunity
     * @param opportunityId - Id of the Opportunity record
     * @return InventoryResponse wrapper with availability details
     */
    public static InventoryResponse checkInventory(Id opportunityId) {
        // Validate input
        if (opportunityId == null) {
            throw new InventoryCheckException('Opportunity ID cannot be null');
        }
        
        // Query Opportunity and related Product details
        Opportunity opp = getOpportunityDetails(opportunityId);
        
        // Make the HTTP callout
        HttpRequest req = buildRequest(opp);
        Http http = new Http();
        HttpResponse res;
        
        try {
            res = http.send(req);
            return parseResponse(res, opportunityId);
        } catch (Exception e) {
            throw new InventoryCheckException('Callout failed: ' + e.getMessage());
        }
    }
    
    /**
     * Asynchronous method using @future for governor limit management
     * Updates Opportunity with inventory status
     */
    @future(callout=true)
    public static void checkInventoryAsync(Id opportunityId) {
        try {
            InventoryResponse response = checkInventory(opportunityId);
            updateOpportunity(opportunityId, response);
        } catch (Exception e) {
            // Log error - you might want to create an Error_Log__c record
            System.debug(LoggingLevel.ERROR, 'Async inventory check failed: ' + e.getMessage());
        }
    }
    
    /**
     * Batch method to check inventory for multiple opportunities
     */
    public static Map<Id, InventoryResponse> checkInventoryBulk(Set<Id> opportunityIds) {
        Map<Id, InventoryResponse> results = new Map<Id, InventoryResponse>();
        
        for (Id oppId : opportunityIds) {
            try {
                results.put(oppId, checkInventory(oppId));
            } catch (Exception e) {
                System.debug('Error checking inventory for ' + oppId + ': ' + e.getMessage());
            }
        }
        
        return results;
    }
    
    // Private helper methods
    
    private static Opportunity getOpportunityDetails(Id opportunityId) {
        List<Opportunity> opps = [
            SELECT Id, Name, Amount, 
                   (SELECT Product2.ProductCode, Product2.Name, Quantity 
                    FROM OpportunityLineItems)
            FROM Opportunity 
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        
        if (opps.isEmpty()) {
            throw new InventoryCheckException('Opportunity not found: ' + opportunityId);
        }
        
        return opps[0];
    }
    
    private static HttpRequest buildRequest(Opportunity opp) {
        HttpRequest req = new HttpRequest();
        
        // Build query parameters for GET request
        String queryParams = '?opportunityId=' + EncodingUtil.urlEncode(String.valueOf(opp.Id), 'UTF-8');
        
        // Add product codes as query parameters if needed
        if (!opp.OpportunityLineItems.isEmpty()) {
            List<String> productCodes = new List<String>();
            for (OpportunityLineItem oli : opp.OpportunityLineItems) {
                if (oli.Product2.ProductCode != null) {
                    productCodes.add(oli.Product2.ProductCode);
                }
            }
            if (!productCodes.isEmpty()) {
                queryParams += '&productCodes=' + EncodingUtil.urlEncode(String.join(productCodes, ','), 'UTF-8');
            }
        }
        
        req.setEndpoint(NAMED_CREDENTIAL + ENDPOINT_PATH + queryParams);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(TIMEOUT);
        
        return req;
    }
    
    private static List<Map<String, Object>> buildProductList(List<OpportunityLineItem> lineItems) {
        List<Map<String, Object>> products = new List<Map<String, Object>>();
        
        for (OpportunityLineItem oli : lineItems) {
            products.add(new Map<String, Object>{
                'productCode' => oli.Product2.ProductCode,
                'productName' => oli.Product2.Name,
                'quantity' => oli.Quantity
            });
        }
        
        return products;
    }
    
    private static InventoryResponse parseResponse(HttpResponse res, Id opportunityId) {
        InventoryResponse response = new InventoryResponse();
        response.opportunityId = opportunityId;
        response.statusCode = res.getStatusCode();
        
        if (res.getStatusCode() == 200) {
            String responseBody = res.getBody();
            
            try {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                
                // Parse the response structure: {"success": true, "count": 23, "data": [...]}
                response.success = (Boolean) jsonResponse.get('success');
                Integer itemCount = (Integer) jsonResponse.get('count');
                List<Object> inventoryData = (List<Object>) jsonResponse.get('data');
                
                // Check if inventory is available
                if (itemCount != null && itemCount > 0) {
                    response.available = true;
                    response.message = itemCount + ' item(s) found in inventory';
                    
                    // Calculate total quantity across all items
                    Integer totalQty = 0;
                    for (Object item : inventoryData) {
                        Map<String, Object> inventoryItem = (Map<String, Object>) item;
                        Integer qty = (Integer) inventoryItem.get('quantity');
                        if (qty != null) {
                            totalQty += qty;
                        }
                    }
                    
                    // Estimate delivery days based on quantity
                    if (totalQty > 50) {
                        response.estimatedDeliveryDays = 3;
                    } else if (totalQty > 20) {
                        response.estimatedDeliveryDays = 5;
                    } else if (totalQty > 0) {
                        response.estimatedDeliveryDays = 7;
                    } else {
                        response.available = false;
                        response.message = 'Items found but out of stock';
                        response.estimatedDeliveryDays = 14;
                    }
                } else {
                    response.available = false;
                    response.message = 'No items found in inventory';
                    response.estimatedDeliveryDays = null;
                }
                
                System.debug('Parsed - Success: ' + response.success);
                System.debug('Parsed - Available: ' + response.available);
                System.debug('Parsed - Message: ' + response.message);
                System.debug('Parsed - Item Count: ' + itemCount);
                
            } catch (Exception e) {
                System.debug('ERROR parsing response: ' + e.getMessage());
                response.success = false;
                response.available = false;
                response.message = 'Failed to parse response: ' + e.getMessage();
            }
        } else {
            response.success = false;
            response.available = false;
            response.message = 'API returned status: ' + res.getStatus();
        }
        
        return response;
    }
    
    private static void updateOpportunity(Id opportunityId, InventoryResponse response) {
        Opportunity opp = new Opportunity(
            Id = opportunityId,
            Inventory_Status__c = response.available ? 'Available' : 'Unavailable',
            Inventory_Check_Date__c = System.now(),
            Inventory_Message__c = response.message
        );
        
        update opp;
    }
    
    // Wrapper classes
    
    public class InventoryResponse {
        public Id opportunityId;
        public Boolean success;
        public Boolean available;
        public String message;
        public Integer estimatedDeliveryDays;
        public Integer statusCode;
    }
    
    public class InventoryCheckException extends Exception {}
}
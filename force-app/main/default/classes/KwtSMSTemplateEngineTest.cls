@IsTest
private class KwtSMSTemplateEngineTest {

    @TestSetup
    static void setup() {
        // Create templates
        List<SMS_Template__c> templates = new List<SMS_Template__c>();
        templates.add(new SMS_Template__c(
            Name = 'Order Created (EN)',
            Event_Type__c = 'Order_Created',
            Language__c = 'en',
            Body__c = 'Hi {{customer_name}}, your order {{order_number}} has been placed. Total: {{order_total}}. - {{company_name}}',
            Default_Body__c = 'Hi {{customer_name}}, your order {{order_number}} has been placed. Total: {{order_total}}. - {{company_name}}'
        ));
        templates.add(new SMS_Template__c(
            Name = 'Case Created (EN)',
            Event_Type__c = 'Case_Created',
            Language__c = 'en',
            Body__c = 'Hi {{customer_name}}, case {{case_number}} created: {{case_subject}}. - {{company_name}}',
            Default_Body__c = 'Hi {{customer_name}}, case {{case_number}} created: {{case_subject}}. - {{company_name}}'
        ));
        insert templates;

        // Create Account and Contact
        Account acc = new Account(Name = 'Test Company');
        insert acc;
        Contact con = new Contact(FirstName = 'Ahmed', LastName = 'Ali', AccountId = acc.Id, Phone = '96598765432');
        insert con;

        // Create Order (requires Account and Pricebook)
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            BillToContactId = con.Id,
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert ord;

        // Create Case
        Case cs = new Case(
            Subject = 'Login issue',
            Status = 'New',
            ContactId = con.Id,
            AccountId = acc.Id
        );
        insert cs;
    }

    @IsTest
    static void testResolve_orderPlaceholders() {
        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        String result = KwtSMSTemplateEngine.resolve('Order_Created', ord.Id, 'en');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null for a known order template');
        System.assert(result.contains('Ahmed Ali'), 'Should contain customer name');
    }

    @IsTest
    static void testResolve_casePlaceholders() {
        Case cs = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        String result = KwtSMSTemplateEngine.resolve('Case_Created', cs.Id, 'en');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null for a known case template');
        System.assert(result.contains('Ahmed Ali'), 'Should contain customer name');
        System.assert(result.contains('Login issue'), 'Should contain case subject');
    }

    @IsTest
    static void testResolve_nullFieldReplacedEmpty() {
        // Create an order without a BillToContact so customer_name is empty
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order ord2 = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert ord2;

        Test.startTest();
        String result = KwtSMSTemplateEngine.resolve('Order_Created', ord2.Id, 'en');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        // customer_name placeholder replaced with empty string, so no literal placeholder remains
        System.assert(!result.contains('{{customer_name}}'), 'Placeholder should be replaced');
    }

    @IsTest
    static void testResolve_languageFallbackArToEn() {
        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        // No Arabic template exists, should fall back to English
        String result = KwtSMSTemplateEngine.resolve('Order_Created', ord.Id, 'ar');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should fall back to English template when Arabic is missing');
    }

    @IsTest
    static void testResolve_missingTemplateReturnsNull() {
        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        String result = KwtSMSTemplateEngine.resolve('Unknown_Event', ord.Id, 'en');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when no template exists for the event');
    }

    @IsTest
    static void testResolve_nullRecordIdReturnsEmpty() {
        Test.startTest();
        String result = KwtSMSTemplateEngine.resolve('Order_Created', null, 'en');
        Test.stopTest();

        // Template is found but no record to query, placeholders resolve to empty
        System.assertNotEquals(null, result, 'Should return a result even with null recordId');
        System.assert(!result.contains('{{customer_name}}'), 'Placeholders should be replaced with empty when recordId is null');
    }

    @IsTest
    static void testResolve_messageCleanedAfter() {
        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        String result = KwtSMSTemplateEngine.resolve('Order_Created', ord.Id, 'en');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        // cleanMessage trims and normalises whitespace; verify no leading/trailing whitespace
        System.assertEquals(result, result.trim(), 'Message should be cleaned (no leading/trailing whitespace)');
    }

    @IsTest
    static void testGetPlaceholdersForEvent_order() {
        Test.startTest();
        List<String> placeholders = KwtSMSTemplateEngine.getPlaceholdersForEvent('Order_Created');
        Test.stopTest();

        System.assert(placeholders.contains('{{customer_name}}'), 'Should include customer_name');
        System.assert(placeholders.contains('{{order_number}}'), 'Should include order_number');
        System.assert(placeholders.contains('{{order_total}}'), 'Should include order_total');
        System.assert(placeholders.contains('{{company_name}}'), 'Should include company_name');
    }

    @IsTest
    static void testGetPlaceholdersForEvent_case() {
        Test.startTest();
        List<String> placeholders = KwtSMSTemplateEngine.getPlaceholdersForEvent('Case_Created');
        Test.stopTest();

        System.assert(placeholders.contains('{{customer_name}}'), 'Should include customer_name');
        System.assert(placeholders.contains('{{case_number}}'), 'Should include case_number');
        System.assert(placeholders.contains('{{case_subject}}'), 'Should include case_subject');
        System.assert(placeholders.contains('{{company_name}}'), 'Should include company_name');
    }

    @IsTest
    static void testGetPlaceholdersForEvent_unknown() {
        Test.startTest();
        List<String> placeholders = KwtSMSTemplateEngine.getPlaceholdersForEvent('Unknown_Event');
        Test.stopTest();

        System.assertEquals(1, placeholders.size(), 'Should return only company_name for unknown event');
        System.assertEquals('{{company_name}}', placeholders[0]);
    }
}

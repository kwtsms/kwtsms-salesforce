public with sharing class KwtSMSTemplateEngine {

    // Placeholder to Salesforce field mapping for Order events
    private static final Map<String, String> ORDER_FIELDS = new Map<String, String>{
        '{{customer_name}}' => 'BillToContact.Name',
        '{{customer_first_name}}' => 'BillToContact.FirstName',
        '{{order_number}}' => 'OrderNumber',
        '{{order_status}}' => 'Status',
        '{{order_total}}' => 'TotalAmount'
    };

    // Placeholder to Salesforce field mapping for Case events
    private static final Map<String, String> CASE_FIELDS = new Map<String, String>{
        '{{customer_name}}' => 'Contact.Name',
        '{{case_number}}' => 'CaseNumber',
        '{{case_status}}' => 'Status',
        '{{case_subject}}' => 'Subject'
    };

    /**
     * Resolve a template for an event type and record.
     * Returns the final SMS message text with placeholders replaced.
     * Returns null if no template found.
     */
    public static String resolve(String eventType, Id recordId, String language) {
        // 1. Get template
        SMS_Template__c template = getTemplate(eventType, language);
        if (template == null && language == 'ar') {
            template = getTemplate(eventType, 'en'); // fallback
        }
        if (template == null) return null;

        // 2. Get field values
        Map<String, String> values = getFieldValues(eventType, recordId);

        // 3. Replace placeholders (null -> empty string)
        String result = template.Body__c;
        for (String placeholder : values.keySet()) {
            String value = values.get(placeholder);
            result = result.replace(placeholder, value != null ? value : '');
        }

        // 4. Clean message
        result = KwtSMSMessageUtils.cleanMessage(result);
        return result;
    }

    /**
     * Get list of available placeholders for an event type (for UI display).
     */
    public static List<String> getPlaceholdersForEvent(String eventType) {
        List<String> placeholders = new List<String>();
        Map<String, String> fieldMap = getFieldMap(eventType);
        if (fieldMap != null) {
            placeholders.addAll(fieldMap.keySet());
        }
        // company_name is available for all events
        if (!placeholders.contains('{{company_name}}')) {
            placeholders.add('{{company_name}}');
        }
        placeholders.sort();
        return placeholders;
    }

    private static SMS_Template__c getTemplate(String eventType, String language) {
        List<SMS_Template__c> templates = [
            SELECT Body__c, Default_Body__c
            FROM SMS_Template__c
            WHERE Event_Type__c = :eventType AND Language__c = :language
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0];
    }

    private static Map<String, String> getFieldValues(String eventType, Id recordId) {
        Map<String, String> values = new Map<String, String>();
        Map<String, String> fieldMap = getFieldMap(eventType);

        if (fieldMap == null || recordId == null) return values;

        // Determine object type and query
        String objectType = getObjectType(eventType);
        if (objectType == 'Order') {
            values = queryOrderValues(recordId, fieldMap);
        } else if (objectType == 'Case') {
            values = queryCaseValues(recordId, fieldMap);
        }

        // Add company name (org name)
        values.put('{{company_name}}', UserInfo.getOrganizationName());

        return values;
    }

    private static Map<String, String> getFieldMap(String eventType) {
        if (eventType != null && (eventType.contains('Order') || eventType.contains('order'))) {
            return ORDER_FIELDS;
        } else if (eventType != null && (eventType.contains('Case') || eventType.contains('case'))) {
            return CASE_FIELDS;
        }
        return null;
    }

    private static String getObjectType(String eventType) {
        if (eventType != null && (eventType.contains('Order') || eventType.contains('order'))) {
            return 'Order';
        } else if (eventType != null && (eventType.contains('Case') || eventType.contains('case'))) {
            return 'Case';
        }
        return null;
    }

    private static Map<String, String> queryOrderValues(Id recordId,
            Map<String, String> fieldMap) {
        Map<String, String> values = new Map<String, String>();
        List<Order> orders = [
            SELECT OrderNumber, Status, TotalAmount,
                   BillToContact.Name, BillToContact.FirstName,
                   Account.Phone
            FROM Order
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (orders.isEmpty()) return values;
        Order o = orders[0];

        values.put('{{customer_name}}', o.BillToContact != null ? o.BillToContact.Name : '');
        values.put('{{customer_first_name}}', o.BillToContact != null ? o.BillToContact.FirstName : '');
        values.put('{{order_number}}', o.OrderNumber);
        values.put('{{order_status}}', o.Status);
        values.put('{{order_total}}', o.TotalAmount != null ? String.valueOf(o.TotalAmount) : '');
        return values;
    }

    private static Map<String, String> queryCaseValues(Id recordId,
            Map<String, String> fieldMap) {
        Map<String, String> values = new Map<String, String>();
        List<Case> cases = [
            SELECT CaseNumber, Status, Subject,
                   Contact.Name, Contact.Phone
            FROM Case
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (cases.isEmpty()) return values;
        Case c = cases[0];

        values.put('{{customer_name}}', c.Contact != null ? c.Contact.Name : '');
        values.put('{{case_number}}', c.CaseNumber);
        values.put('{{case_status}}', c.Status);
        values.put('{{case_subject}}', c.Subject != null ? c.Subject : '');
        return values;
    }
}

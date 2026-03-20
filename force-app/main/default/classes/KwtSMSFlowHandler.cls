public with sharing class KwtSMSFlowHandler {

    public class FlowRequest {
        @InvocableVariable(label='Record ID' required=true)
        public Id recordId;

        @InvocableVariable(label='Event Type' required=true)
        public String eventType;

        @InvocableVariable(label='Object Type' required=true)
        public String objectType;
    }

    @InvocableMethod(
        label='Handle kwtSMS Event'
        description='Processes an SMS event: checks config, resolves template, sends SMS'
        category='Messaging'
        callout=true
    )
    public static void handleEvent(List<FlowRequest> requests) {
        for (FlowRequest req : requests) {
            // 1. Check event config
            List<KwtSMS_Event_Config__c> configs = [
                SELECT Enabled__c, Notify_Customer__c, Notify_Admin__c
                FROM KwtSMS_Event_Config__c
                WHERE Event_Name__c = :req.eventType
                WITH SECURITY_ENFORCED LIMIT 1
            ];
            if (configs.isEmpty() || !configs[0].Enabled__c) continue;

            KwtSMS_Config__c settings = KwtSMSSettingsService.getConfig();
            String language = settings.Default_Language__c != null ? settings.Default_Language__c : 'en';

            // 2. Send to customer
            if (configs[0].Notify_Customer__c) {
                String phone = getCustomerPhone(req.recordId, req.objectType);
                if (String.isNotBlank(phone)) {
                    String message = KwtSMSTemplateEngine.resolve(req.eventType, req.recordId, language);
                    if (String.isNotBlank(message)) {
                        KwtSMSEngine.send(new List<String>{phone}, message, null);
                    }
                }
            }

            // 3. Send to admins
            if (configs[0].Notify_Admin__c) {
                String adminEventType = 'Admin_' + req.eventType;
                String adminMessage = KwtSMSTemplateEngine.resolve(adminEventType, req.recordId, 'en');
                if (String.isNotBlank(adminMessage)) {
                    List<Admin_Alert_Recipient__c> recipients = [
                        SELECT Phone__c FROM Admin_Alert_Recipient__c
                        WHERE Active__c = true WITH SECURITY_ENFORCED
                    ];
                    List<String> adminPhones = new List<String>();
                    for (Admin_Alert_Recipient__c r : recipients) {
                        adminPhones.add(r.Phone__c);
                    }
                    if (!adminPhones.isEmpty()) {
                        KwtSMSEngine.send(adminPhones, adminMessage, null);
                    }
                }
            }
        }
    }

    private static String getCustomerPhone(Id recordId, String objectType) {
        if (objectType == 'Order') {
            List<Order> orders = [SELECT BillToContact.Phone, Account.Phone
                FROM Order WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1];
            if (orders.isEmpty()) return null;
            Order o = orders[0];
            if (o.BillToContact != null && String.isNotBlank(o.BillToContact.Phone)) return o.BillToContact.Phone;
            if (o.Account != null && String.isNotBlank(o.Account.Phone)) return o.Account.Phone;
            return null;
        } else if (objectType == 'Case') {
            List<Case> cases = [SELECT Contact.Phone FROM Case
                WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1];
            return (cases.isEmpty() || cases[0].Contact == null) ? null : cases[0].Contact.Phone;
        }
        return null;
    }
}

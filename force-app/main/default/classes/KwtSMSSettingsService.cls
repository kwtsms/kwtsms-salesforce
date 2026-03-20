public with sharing class KwtSMSSettingsService {

    /**
     * Get org-wide config. No SOQL needed (Custom Setting getInstance).
     */
    public static KwtSMS_Config__c getConfig() {
        KwtSMS_Config__c config = KwtSMS_Config__c.getOrgDefaults();
        if (config == null) {
            config = new KwtSMS_Config__c();
        }
        return config;
    }

    /**
     * Save config changes via standard DML.
     */
    public static void saveConfig(KwtSMS_Config__c config) {
        upsert config;
    }

    /**
     * Check if all gateway guards pass: enabled, connected, balance > 0.
     */
    public static Boolean isGatewayReady() {
        KwtSMS_Config__c config = getConfig();
        return config.Gateway_Enabled__c &&
               config.Gateway_Connected__c &&
               config.Cached_Balance__c != null &&
               config.Cached_Balance__c > 0;
    }

    /**
     * Read credentials from CMDT.
     * Returns Map with keys 'username' and 'password'.
     */
    public static Map<String, String> getCredentials() {
        Map<String, String> creds = new Map<String, String>();
        List<KwtSMS_Credentials__mdt> records = [
            SELECT Username__c, Password__c
            FROM KwtSMS_Credentials__mdt
            LIMIT 1
        ];
        if (!records.isEmpty()) {
            creds.put('username', records[0].Username__c);
            creds.put('password', records[0].Password__c);
        }
        return creds;
    }

    /**
     * Save credentials via Metadata API (async deployment).
     * Returns the deployment job ID.
     */
    public static Id saveCredentials(String username, String password) {
        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        customMetadata.fullName = 'KwtSMS_Credentials__mdt.Default';
        customMetadata.label = 'Default';

        Metadata.CustomMetadataValue usernameField = new Metadata.CustomMetadataValue();
        usernameField.field = 'Username__c';
        usernameField.value = username;
        customMetadata.values.add(usernameField);

        Metadata.CustomMetadataValue passwordField = new Metadata.CustomMetadataValue();
        passwordField.field = 'Password__c';
        passwordField.value = password;
        customMetadata.values.add(passwordField);

        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(customMetadata);

        // Deploy asynchronously
        Id jobId = Metadata.Operations.enqueueDeployment(container, null);
        return jobId;
    }

    /**
     * Clear credentials on logout.
     */
    public static Id clearCredentials() {
        return saveCredentials(null, null);
    }

    /**
     * Parse cached sender IDs from JSON array string.
     */
    public static List<String> getSenderIds() {
        KwtSMS_Config__c config = getConfig();
        if (String.isBlank(config.Cached_Sender_IDs__c)) {
            return new List<String>{ 'KWT-SMS' };
        }
        return (List<String>) JSON.deserialize(
            config.Cached_Sender_IDs__c, List<String>.class);
    }

    /**
     * Parse cached coverage from JSON array string.
     */
    public static List<String> getCoverage() {
        KwtSMS_Config__c config = getConfig();
        if (String.isBlank(config.Cached_Coverage__c)) {
            return new List<String>{ '965' };
        }
        return (List<String>) JSON.deserialize(
            config.Cached_Coverage__c, List<String>.class);
    }

    /**
     * Update cached balance after a send.
     */
    public static void updateBalance(Decimal newBalance) {
        KwtSMS_Config__c config = getConfig();
        config.Cached_Balance__c = newBalance;
        saveConfig(config);
    }
}

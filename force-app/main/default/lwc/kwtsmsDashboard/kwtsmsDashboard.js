import { LightningElement, wire, track } from 'lwc';
import getDashboardData from '@salesforce/apex/KwtSMSController.getDashboardData';

const RECENT_LOG_COLUMNS = [
    {
        label: 'Date',
        fieldName: 'CreatedDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    { label: 'Phone', fieldName: 'Phone__c', type: 'text' },
    { label: 'Message', fieldName: 'Message__c', type: 'text', wrapText: false, cellAttributes: { class: 'kwtsms-truncate' } },
    { label: 'Points', fieldName: 'Points_Charged__c', type: 'number' },
    { label: 'Error', fieldName: 'Error_Message__c', type: 'text' },
    { label: 'Event', fieldName: 'Event_Type__c', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' }
];

export default class KwtsmsDashboard extends LightningElement {
    @track data = {};
    @track eventConfigs = [];
    @track adminRecipients = [];
    @track recentLogs = [];
    isLoading = true;
    hasError = false;
    errorMessage = '';

    recentLogColumns = RECENT_LOG_COLUMNS;

    @wire(getDashboardData)
    wiredDashboard({ error, data }) {
        if (data) {
            this.data = data;
            this.eventConfigs = this._mapEventConfigs(data.eventConfigs || []);
            this.adminRecipients = data.adminRecipients || [];
            this.recentLogs = data.recentLogs || [];
            this.isLoading = false;
            this.hasError = false;
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : 'Failed to load dashboard data.';
            this.isLoading = false;
            this.hasError = true;
        }
    }

    _mapEventConfigs(configs) {
        return configs.map(ec => ({
            ...ec,
            statusLabel: ec.Enabled__c ? 'Enabled' : 'Disabled',
            statusBadgeClass: ec.Enabled__c ? 'slds-badge kwtsms-badge_green' : 'slds-badge kwtsms-badge_gray',
            customerLabel: ec.Notify_Customer__c ? 'Yes' : 'No',
            customerBadgeClass: ec.Notify_Customer__c ? 'slds-badge kwtsms-badge_green' : 'slds-badge kwtsms-badge_gray',
            adminLabel: ec.Notify_Admin__c ? 'Yes' : 'No',
            adminBadgeClass: ec.Notify_Admin__c ? 'slds-badge kwtsms-badge_green' : 'slds-badge kwtsms-badge_gray'
        }));
    }

    get isReady() {
        return !this.isLoading && !this.hasError;
    }

    get formattedBalance() {
        const val = this.data.balance;
        if (val == null) return '0';
        return new Intl.NumberFormat('en-US').format(val);
    }

    get testModeLabel() {
        return this.data.testMode ? 'ON' : 'OFF';
    }

    get testModeBadgeClass() {
        return this.data.testMode
            ? 'slds-badge kwtsms-badge_green'
            : 'slds-badge kwtsms-badge_gray';
    }

    get gatewayLabel() {
        return this.data.gatewayConnected ? 'Connected' : 'Disconnected';
    }

    get gatewayBadgeClass() {
        return this.data.gatewayConnected
            ? 'slds-badge kwtsms-badge_green'
            : 'slds-badge kwtsms-badge_red';
    }

    get enabledLabel() {
        return this.data.gatewayEnabled ? 'Enabled' : 'Disabled';
    }

    get enabledBadgeClass() {
        return this.data.gatewayEnabled
            ? 'slds-badge kwtsms-badge_green'
            : 'slds-badge kwtsms-badge_red';
    }

    get hasEventConfigs() {
        return this.eventConfigs && this.eventConfigs.length > 0;
    }

    get hasAdminRecipients() {
        return this.adminRecipients && this.adminRecipients.length > 0;
    }

    get hasRecentLogs() {
        return this.recentLogs && this.recentLogs.length > 0;
    }

    handleViewAllLogs() {
        this.dispatchEvent(new CustomEvent('viewlogs'));
    }
}

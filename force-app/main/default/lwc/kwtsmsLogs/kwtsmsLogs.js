import { LightningElement, track } from 'lwc';
import getLogs from '@salesforce/apex/KwtSMSController.getLogs';
import clearLogs from '@salesforce/apex/KwtSMSController.clearLogs';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class KwtsmsLogs extends LightningElement {
    @track logs = [];
    isLoading = true;
    statusFilter = 'All';
    eventFilter = 'All';
    logLevelFilter = 'All';
    searchTerm = '';
    selectedLog;
    showDetail = false;
    showClearConfirm = false;
    offset = 0;
    pageSize = 50;

    columns = [
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
        { label: 'Message', fieldName: 'Message__c', type: 'text', wrapText: true },
        { label: 'Points', fieldName: 'Points_Charged__c', type: 'number' },
        { label: 'Error', fieldName: 'Error_Message__c', type: 'text' },
        { label: 'Event', fieldName: 'Event_Type__c', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [{ label: 'View Detail', name: 'view_detail' }]
            }
        }
    ];

    get statusOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Sent', value: 'Sent' },
            { label: 'Failed', value: 'Failed' },
            { label: 'Skipped', value: 'Skipped' }
        ];
    }

    get eventOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'SMS Send', value: 'SMS_SEND' },
            { label: 'Gateway Test', value: 'Gateway_Test' },
            { label: 'Login', value: 'LOGIN' },
            { label: 'Logout', value: 'LOGOUT' },
            { label: 'Sync', value: 'SYNC' },
            { label: 'Guard', value: 'GUARD' },
            { label: 'Install', value: 'INSTALL' }
        ];
    }

    get logLevelOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Error', value: 'ERROR' },
            { label: 'Warning', value: 'WARN' },
            { label: 'Info', value: 'INFO' },
            { label: 'Debug', value: 'DEBUG' }
        ];
    }

    get noResults() {
        return !this.isLoading && (!this.logs || this.logs.length === 0);
    }

    connectedCallback() {
        this.loadLogs();
    }

    async loadLogs() {
        this.isLoading = true;
        try {
            const result = await getLogs({
                statusFilter: this.statusFilter,
                eventFilter: this.eventFilter,
                logLevelFilter: this.logLevelFilter,
                searchTerm: this.searchTerm,
                limitCount: this.pageSize,
                offsetCount: this.offset
            });
            if (this.offset === 0) {
                this.logs = result;
            } else {
                this.logs = [...this.logs, ...result];
            }
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error loading logs',
                message: error.body ? error.body.message : 'An error occurred.',
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    handleStatusChange(event) {
        this.statusFilter = event.detail.value;
    }

    handleEventChange(event) {
        this.eventFilter = event.detail.value;
    }

    handleLogLevelChange(event) {
        this.logLevelFilter = event.detail.value;
    }

    handleSearch(event) {
        this.searchTerm = event.detail.value;
    }

    handleApplyFilters() {
        this.offset = 0;
        this.loadLogs();
    }

    handleResetFilters() {
        this.statusFilter = 'All';
        this.eventFilter = 'All';
        this.logLevelFilter = 'All';
        this.searchTerm = '';
        this.offset = 0;
        this.loadLogs();
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        if (actionName === 'view_detail') {
            this.selectedLog = event.detail.row;
            this.showDetail = true;
        }
    }

    handleCloseDetail() {
        this.showDetail = false;
        this.selectedLog = null;
    }

    handleClearLogs() {
        this.showClearConfirm = true;
    }

    handleCancelClear() {
        this.showClearConfirm = false;
    }

    async handleConfirmClear() {
        this.showClearConfirm = false;
        this.isLoading = true;
        try {
            await clearLogs();
            this.offset = 0;
            await this.loadLogs();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Logs Cleared',
                message: 'All SMS log entries have been deleted.',
                variant: 'success'
            }));
        } catch (error) {
            this.isLoading = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error clearing logs',
                message: error.body ? error.body.message : 'An error occurred.',
                variant: 'error'
            }));
        }
    }

    handleLoadMore() {
        this.offset += this.pageSize;
        this.loadLogs();
    }
}

import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveGlobalSettings from '@salesforce/apex/KwtSMSController.saveGlobalSettings';
import getEventConfigs from '@salesforce/apex/KwtSMSController.getEventConfigs';
import saveEventConfig from '@salesforce/apex/KwtSMSController.saveEventConfig';
import getTemplatesForEvent from '@salesforce/apex/KwtSMSController.getTemplatesForEvent';
import getAdminRecipients from '@salesforce/apex/KwtSMSController.getAdminRecipients';
import addAdminRecipient from '@salesforce/apex/KwtSMSController.addAdminRecipient';
import deleteAdminRecipient from '@salesforce/apex/KwtSMSController.deleteAdminRecipient';
import toggleAdminRecipient from '@salesforce/apex/KwtSMSController.toggleAdminRecipient';
import getGatewayConfig from '@salesforce/apex/KwtSMSController.getGatewayConfig';

export default class KwtsmsSettings extends LightningElement {
    @track gatewayEnabled = false;
    @track defaultLanguage = 'en';
    @track eventConfigs = [];
    @track adminRecipients = [];
    @track isLoadingEvents = false;
    @track showTemplateModal = false;
    @track activeTemplate = {};

    newRecipientName = '';
    newRecipientPhone = '';

    languageOptions = [
        { label: 'English', value: 'en' },
        { label: 'Arabic', value: 'ar' }
    ];

    connectedCallback() {
        this.loadGatewayConfig();
        this.loadEventConfigs();
        this.loadAdminRecipients();
    }

    async loadGatewayConfig() {
        try {
            const config = await getGatewayConfig();
            if (config) {
                this.gatewayEnabled = config.isEnabled;
                this.defaultLanguage = config.defaultLanguage || 'en';
            }
        } catch (e) {
            this.showToast('Error', 'Failed to load gateway config', 'error');
        }
    }

    async loadEventConfigs() {
        this.isLoadingEvents = true;
        try {
            const configs = await getEventConfigs();
            this.eventConfigs = configs ? configs.map(c => ({ ...c })) : [];
        } catch (e) {
            this.showToast('Error', 'Failed to load event configs', 'error');
        } finally {
            this.isLoadingEvents = false;
        }
    }

    async loadAdminRecipients() {
        try {
            const recipients = await getAdminRecipients();
            this.adminRecipients = recipients
                ? recipients.map(r => ({ ...r, confirmDelete: false }))
                : [];
        } catch (e) {
            this.showToast('Error', 'Failed to load admin recipients', 'error');
        }
    }

    // Global Settings handlers
    handleGatewayToggle(event) {
        this.gatewayEnabled = event.target.checked;
    }

    handleLanguageChange(event) {
        this.defaultLanguage = event.detail.value;
    }

    async handleSaveGlobalSettings() {
        try {
            await saveGlobalSettings({
                isEnabled: this.gatewayEnabled,
                defaultLanguage: this.defaultLanguage
            });
            this.showToast('Success', 'Global settings saved', 'success');
        } catch (e) {
            this.showToast('Error', 'Failed to save global settings', 'error');
        }
    }

    // Event config handlers
    async handleEventToggle(event) {
        const eventType = event.target.dataset.eventType;
        const isActive = event.target.checked;
        this.updateEventConfigLocal(eventType, { isActive });
        await this.persistEventConfig(eventType);
    }

    async handleEventCheckbox(event) {
        const eventType = event.target.dataset.eventType;
        const field = event.target.dataset.field;
        const value = event.target.checked;
        this.updateEventConfigLocal(eventType, { [field]: value });
        await this.persistEventConfig(eventType);
    }

    updateEventConfigLocal(eventType, updates) {
        this.eventConfigs = this.eventConfigs.map(c => {
            if (c.eventType === eventType) {
                return { ...c, ...updates };
            }
            return c;
        });
    }

    async persistEventConfig(eventType) {
        const config = this.eventConfigs.find(c => c.eventType === eventType);
        if (!config) return;
        try {
            await saveEventConfig({ config });
        } catch (e) {
            this.showToast('Error', 'Failed to save event config', 'error');
        }
    }

    // Template modal handlers
    async handleEditTemplate(event) {
        const eventType = event.target.dataset.eventType;
        const language = event.target.dataset.language;
        const eventConfig = this.eventConfigs.find(c => c.eventType === eventType);
        try {
            const templates = await getTemplatesForEvent({ eventType });
            const template = templates
                ? templates.find(t => t.language === language)
                : null;
            this.activeTemplate = {
                id: template ? template.id : null,
                name: eventConfig ? eventConfig.label : eventType,
                eventType,
                language,
                body: template ? template.body : '',
                defaultBody: template ? template.defaultBody : ''
            };
            this.showTemplateModal = true;
        } catch (e) {
            this.showToast('Error', 'Failed to load template', 'error');
        }
    }

    handleModalClose() {
        this.showTemplateModal = false;
        this.activeTemplate = {};
    }

    handleModalSave() {
        this.showTemplateModal = false;
        this.activeTemplate = {};
        this.showToast('Success', 'Template saved', 'success');
    }

    // Admin recipient handlers
    handleNewRecipientName(event) {
        this.newRecipientName = event.target.value;
    }

    handleNewRecipientPhone(event) {
        this.newRecipientPhone = event.target.value;
    }

    async handleAddRecipient() {
        const name = this.newRecipientName.trim();
        const phone = this.newRecipientPhone.trim();
        if (!name || !phone) {
            this.showToast('Error', 'Name and phone are required', 'error');
            return;
        }
        try {
            await addAdminRecipient({ name, phone });
            this.newRecipientName = '';
            this.newRecipientPhone = '';
            await this.loadAdminRecipients();
            this.showToast('Success', 'Recipient added', 'success');
        } catch (e) {
            this.showToast('Error', 'Failed to add recipient', 'error');
        }
    }

    async handleToggleRecipient(event) {
        const recipientId = event.target.dataset.recipientId;
        const isActive = event.target.checked;
        try {
            await toggleAdminRecipient({ recipientId, isActive });
            await this.loadAdminRecipients();
        } catch (e) {
            this.showToast('Error', 'Failed to update recipient', 'error');
        }
    }

    handleDeleteRecipient(event) {
        const recipientId = event.target.dataset.recipientId;
        this.adminRecipients = this.adminRecipients.map(r => ({
            ...r,
            confirmDelete: r.id === recipientId ? true : r.confirmDelete
        }));
    }

    handleCancelDelete(event) {
        const recipientId = event.target.dataset.recipientId;
        this.adminRecipients = this.adminRecipients.map(r => ({
            ...r,
            confirmDelete: r.id === recipientId ? false : r.confirmDelete
        }));
    }

    async handleConfirmDelete(event) {
        const recipientId = event.target.dataset.recipientId;
        try {
            await deleteAdminRecipient({ recipientId });
            await this.loadAdminRecipients();
            this.showToast('Success', 'Recipient deleted', 'success');
        } catch (e) {
            this.showToast('Error', 'Failed to delete recipient', 'error');
        }
    }

    get hasRecipients() {
        return this.adminRecipients && this.adminRecipients.length > 0;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

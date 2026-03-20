import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import login from '@salesforce/apex/KwtSMSController.login';
import logout from '@salesforce/apex/KwtSMSController.logout';
import reload from '@salesforce/apex/KwtSMSController.reload';
import saveGatewaySettings from '@salesforce/apex/KwtSMSController.saveGatewaySettings';
import sendTestSMS from '@salesforce/apex/KwtSMSController.sendTestSMS';
import getGatewayConfig from '@salesforce/apex/KwtSMSController.getGatewayConfig';
import getAdminRecipients from '@salesforce/apex/KwtSMSController.getAdminRecipients';

import labelGatewayLogin from '@salesforce/label/c.KwtSMS_Tab_Gateway';
import labelUsername from '@salesforce/label/c.KwtSMS_Label_Username';
import labelPassword from '@salesforce/label/c.KwtSMS_Label_Password';
import labelLogin from '@salesforce/label/c.KwtSMS_Btn_Login';
import labelLogout from '@salesforce/label/c.KwtSMS_Btn_Logout';
import labelReload from '@salesforce/label/c.KwtSMS_Btn_Reload';
import labelSave from '@salesforce/label/c.KwtSMS_Btn_Save';
import labelBalance from '@salesforce/label/c.KwtSMS_Label_Balance';
import labelLastSync from '@salesforce/label/c.KwtSMS_Label_LastSync';
import labelSenderId from '@salesforce/label/c.KwtSMS_Label_SenderID';
import labelDefaultCountryCode from '@salesforce/label/c.KwtSMS_Label_DefaultCountryCode';
import labelTestMode from '@salesforce/label/c.KwtSMS_Label_TestMode';
import labelDebugLogging from '@salesforce/label/c.KwtSMS_Label_DebugLogging';
import labelPhone from '@salesforce/label/c.KwtSMS_Label_Phone';
import labelMessage from '@salesforce/label/c.KwtSMS_Label_Message';
import labelSendTestSms from '@salesforce/label/c.KwtSMS_Btn_SendTestSMS';
import labelGatewayTestTitle from '@salesforce/label/c.KwtSMS_GatewayTest_Title';
import labelTestSuccess from '@salesforce/label/c.KwtSMS_GatewayTest_Success';
import labelLoginFailed from '@salesforce/label/c.KwtSMS_Error_LoginFailed';
import labelSendFailed from '@salesforce/label/c.KwtSMS_Error_SendFailed';

export default class KwtsmsGateway extends LightningElement {
    label = {
        gatewayLogin: labelGatewayLogin,
        username: labelUsername,
        password: labelPassword,
        login: labelLogin,
        logout: labelLogout,
        reload: labelReload,
        save: labelSave,
        balance: labelBalance,
        lastSync: labelLastSync,
        senderId: labelSenderId,
        defaultCountryCode: labelDefaultCountryCode,
        testMode: labelTestMode,
        debugLogging: labelDebugLogging,
        phone: labelPhone,
        message: labelMessage,
        sendTestSms: labelSendTestSms,
        gatewayTestTitle: labelGatewayTestTitle,
        testSuccess: labelTestSuccess,
        loginFailed: labelLoginFailed,
        sendFailed: labelSendFailed
    };

    // Expose labels as individual getters for template binding
    get labelGatewayLogin() { return labelGatewayLogin; }
    get labelUsername() { return labelUsername; }
    get labelPassword() { return labelPassword; }
    get labelLogin() { return labelLogin; }
    get labelLogout() { return labelLogout; }
    get labelReload() { return labelReload; }
    get labelSave() { return labelSave; }
    get labelBalance() { return labelBalance; }
    get labelLastSync() { return labelLastSync; }
    get labelSenderId() { return labelSenderId; }
    get labelDefaultCountryCode() { return labelDefaultCountryCode; }
    get labelTestMode() { return labelTestMode; }
    get labelDebugLogging() { return labelDebugLogging; }
    get labelPhone() { return labelPhone; }
    get labelMessage() { return labelMessage; }
    get labelSendTestSms() { return labelSendTestSms; }
    get labelGatewayTestTitle() { return labelGatewayTestTitle; }

    // State
    @track isConnected = false;
    @track isLoading = true;
    @track username = '';
    @track password = '';
    @track balance = 0;
    @track lastSync;
    @track senderIdOptions = [];
    @track selectedSenderId;
    @track countryCodeOptions = [];
    @track selectedCountryCode;
    @track testMode = true;
    @track debugLogging = true;

    // Test SMS
    @track testPhone = '';
    @track testMessage = '';
    @track testResult;
    @track testSuccess = false;
    @track loginError;

    connectedCallback() {
        this.testMessage = this.defaultTestMessage;
        this.loadConfig();
    }

    async loadConfig() {
        this.isLoading = true;
        try {
            const config = await getGatewayConfig();
            if (config && config.isConnected) {
                this.isConnected = true;
                this.balance = config.balance || 0;
                this.lastSync = config.lastSync || '';
                this.selectedSenderId = config.selectedSenderId;
                this.selectedCountryCode = config.selectedCountryCode;
                this.testMode = config.testMode !== undefined ? config.testMode : true;
                this.debugLogging = config.debugLogging !== undefined ? config.debugLogging : true;

                if (config.senderIds && config.senderIds.length > 0) {
                    this.senderIdOptions = config.senderIds.map(id => ({ label: id, value: id }));
                }
                if (config.countryCodes && config.countryCodes.length > 0) {
                    this.countryCodeOptions = config.countryCodes.map(cc => ({
                        label: cc.label || cc.value,
                        value: cc.value
                    }));
                }

                try {
                    const recipients = await getAdminRecipients();
                    if (recipients && recipients.length > 0) {
                        this.testPhone = recipients[0].phone || '';
                    }
                } catch (recipientError) {
                    // Non-critical, leave testPhone empty
                }
            } else {
                this.isConnected = false;
            }
        } catch (error) {
            this.isConnected = false;
        } finally {
            this.isLoading = false;
        }
    }

    get formattedBalance() {
        return new Intl.NumberFormat().format(this.balance || 0);
    }

    get defaultTestMessage() {
        return 'kwtSMS Gateway Test - ' + new Date().toISOString().replace('T', ' ').substring(0, 19);
    }

    get testResultClass() {
        return this.testSuccess
            ? 'kwtsms-test-result kwtsms-test-result--success'
            : 'kwtsms-test-result kwtsms-test-result--error';
    }

    async handleLogin() {
        this.isLoading = true;
        this.loginError = null;
        try {
            const result = await login({ username: this.username, password: this.password });
            if (result && result.success) {
                this.isConnected = true;
                this.balance = result.balance || 0;
                this.lastSync = result.lastSync || '';
                this.selectedSenderId = result.selectedSenderId;
                this.selectedCountryCode = result.selectedCountryCode;
                this.testMode = result.testMode !== undefined ? result.testMode : true;
                this.debugLogging = result.debugLogging !== undefined ? result.debugLogging : true;
                if (result.senderIds && result.senderIds.length > 0) {
                    this.senderIdOptions = result.senderIds.map(id => ({ label: id, value: id }));
                }
                if (result.countryCodes && result.countryCodes.length > 0) {
                    this.countryCodeOptions = result.countryCodes.map(cc => ({
                        label: cc.label || cc.value,
                        value: cc.value
                    }));
                }
                this.dispatchEvent(new ShowToastEvent({
                    title: labelGatewayLogin,
                    message: labelTestSuccess,
                    variant: 'success'
                }));
            } else {
                this.loginError = (result && result.errorMessage) ? result.errorMessage : labelLoginFailed;
            }
        } catch (error) {
            this.loginError = (error && error.body && error.body.message) ? error.body.message : labelLoginFailed;
        } finally {
            this.isLoading = false;
        }
    }

    async handleLogout() {
        this.isLoading = true;
        try {
            await logout();
            this.isConnected = false;
            this.username = '';
            this.password = '';
            this.balance = 0;
            this.lastSync = null;
            this.senderIdOptions = [];
            this.selectedSenderId = null;
            this.countryCodeOptions = [];
            this.selectedCountryCode = null;
            this.testMode = true;
            this.debugLogging = true;
            this.loginError = null;
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: labelLogout,
                message: (error && error.body && error.body.message) ? error.body.message : labelSendFailed,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    async handleReload() {
        this.isLoading = true;
        try {
            const result = await reload();
            if (result) {
                this.balance = result.balance || this.balance;
                this.lastSync = result.lastSync || this.lastSync;
                if (result.senderIds && result.senderIds.length > 0) {
                    this.senderIdOptions = result.senderIds.map(id => ({ label: id, value: id }));
                }
                if (result.countryCodes && result.countryCodes.length > 0) {
                    this.countryCodeOptions = result.countryCodes.map(cc => ({
                        label: cc.label || cc.value,
                        value: cc.value
                    }));
                }
            }
            this.dispatchEvent(new ShowToastEvent({
                title: labelReload,
                message: labelTestSuccess,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: labelReload,
                message: (error && error.body && error.body.message) ? error.body.message : labelSendFailed,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    async handleSaveSettings() {
        this.isLoading = true;
        try {
            await saveGatewaySettings({
                senderId: this.selectedSenderId,
                countryCode: this.selectedCountryCode,
                testMode: this.testMode,
                debugLogging: this.debugLogging
            });
            this.dispatchEvent(new ShowToastEvent({
                title: labelSave,
                message: labelTestSuccess,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: labelSave,
                message: (error && error.body && error.body.message) ? error.body.message : labelSendFailed,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    async handleSendTestSMS() {
        this.isLoading = true;
        this.testResult = null;
        this.testSuccess = false;
        try {
            const result = await sendTestSMS({
                phone: this.testPhone,
                message: this.testMessage || this.defaultTestMessage
            });
            if (result && result.success) {
                this.testSuccess = true;
                this.testResult = labelTestSuccess + (result.msgId ? ' (ID: ' + result.msgId + ')' : '');
            } else {
                this.testSuccess = false;
                this.testResult = labelSendFailed + (result && result.errorCode ? ' (Code: ' + result.errorCode + ')' : '');
            }
        } catch (error) {
            this.testSuccess = false;
            this.testResult = (error && error.body && error.body.message) ? error.body.message : labelSendFailed;
        } finally {
            this.isLoading = false;
        }
    }

    // Input handlers
    handleUsernameChange(event) { this.username = event.target.value; }
    handlePasswordChange(event) { this.password = event.target.value; }
    handleSenderIdChange(event) { this.selectedSenderId = event.detail.value; }
    handleCountryCodeChange(event) { this.selectedCountryCode = event.detail.value; }
    handleTestModeChange(event) { this.testMode = event.target.checked; }
    handleDebugLoggingChange(event) { this.debugLogging = event.target.checked; }
    handleTestPhoneChange(event) { this.testPhone = event.target.value; }
    handleTestMessageChange(event) { this.testMessage = event.target.value; }
}

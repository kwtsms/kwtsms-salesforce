import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import KWTSMS_LOGO from '@salesforce/resourceUrl/kwtsmsLogo';
import labelAppTitle from '@salesforce/label/c.KwtSMS_Help_Welcome';
import labelTabDashboard from '@salesforce/label/c.KwtSMS_Tab_Dashboard';
import labelTabSettings from '@salesforce/label/c.KwtSMS_Tab_Settings';
import labelTabGateway from '@salesforce/label/c.KwtSMS_Tab_Gateway';
import labelTabLogs from '@salesforce/label/c.KwtSMS_Tab_Logs';
import labelTabHelp from '@salesforce/label/c.KwtSMS_Tab_Help';

export default class KwtsmsApp extends LightningElement {
    logoUrl = KWTSMS_LOGO + '/kwtsms_logo_100.png';

    label = {
        appTitle: labelAppTitle,
        tabDashboard: labelTabDashboard,
        tabSettings: labelTabSettings,
        tabGateway: labelTabGateway,
        tabLogs: labelTabLogs,
        tabHelp: labelTabHelp
    };
}

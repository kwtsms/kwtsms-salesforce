import { LightningElement } from 'lwc';
import KWTSMS_LOGO from '@salesforce/resourceUrl/kwtsmsLogo';
import labelWelcome from '@salesforce/label/c.KwtSMS_Help_Welcome';
import labelDescription from '@salesforce/label/c.KwtSMS_Help_Description';
import labelStep1 from '@salesforce/label/c.KwtSMS_Help_Step1';
import labelStep2 from '@salesforce/label/c.KwtSMS_Help_Step2';
import labelStep3 from '@salesforce/label/c.KwtSMS_Help_Step3';
import labelStep4 from '@salesforce/label/c.KwtSMS_Help_Step4';
import labelStep5 from '@salesforce/label/c.KwtSMS_Help_Step5';
import labelStep6 from '@salesforce/label/c.KwtSMS_Help_Step6';
import labelTestModeInfo from '@salesforce/label/c.KwtSMS_Help_TestModeInfo';
import labelSenderIdInfo from '@salesforce/label/c.KwtSMS_Help_SenderIDInfo';
import labelArabicInfo from '@salesforce/label/c.KwtSMS_Help_ArabicInfo';
import labelVersion from '@salesforce/label/c.KwtSMS_Help_Version';
import labelTestModeLabel from '@salesforce/label/c.KwtSMS_Label_TestMode';
import labelSenderIdLabel from '@salesforce/label/c.KwtSMS_Label_SenderID';
import labelArabicLabel from '@salesforce/label/c.KwtSMS_Template_EncodingArabic';

export default class KwtsmsHelp extends LightningElement {
    logoUrl = KWTSMS_LOGO + '/kwtsms_logo_100.png';

    label = {
        welcome: labelWelcome,
        description: labelDescription,
        step1: labelStep1,
        step2: labelStep2,
        step3: labelStep3,
        step4: labelStep4,
        step5: labelStep5,
        step6: labelStep6,
        testModeInfo: labelTestModeInfo,
        senderIdInfo: labelSenderIdInfo,
        arabicInfo: labelArabicInfo,
        version: labelVersion,
        testModeLabel: labelTestModeLabel,
        senderIdLabel: labelSenderIdLabel,
        arabicLabel: labelArabicLabel
    };

    handleWebsite() {
        window.open('https://kwtsms.com', '_blank');
    }

    handleApiDocs() {
        window.open('https://kwtsms.com/developers.html', '_blank');
    }

    handleSupport() {
        window.open('https://kwtsms.com/support.html', '_blank');
    }

    handleSenderIdHelp() {
        window.open('https://kwtsms.com/sender-id-help.html', '_blank');
    }

    handleFaq() {
        window.open('https://kwtsms.com/faq/', '_blank');
    }
}

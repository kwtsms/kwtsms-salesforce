import { LightningElement, api, track } from 'lwc';
import saveTemplate from '@salesforce/apex/KwtSMSController.saveTemplate';
import resetTemplate from '@salesforce/apex/KwtSMSController.resetTemplate';
import getPlaceholdersForEvent from '@salesforce/apex/KwtSMSController.getPlaceholdersForEvent';

export default class KwtsmsTemplateModal extends LightningElement {
    @api templateId;
    @api templateName;
    @api eventType;
    @api language;
    @api body;
    @api defaultBody;

    @track editedBody = '';
    @track placeholders = [];
    @track pageInfo = {
        encoding: 'English',
        charCount: 0,
        pageCount: 0,
        charsRemaining: 160
    };

    connectedCallback() {
        this.editedBody = this.body || '';
        this.loadPlaceholders();
        this.updatePageInfo();
    }

    async loadPlaceholders() {
        try {
            const result = await getPlaceholdersForEvent({ eventType: this.eventType });
            this.placeholders = result ? result : [];
        } catch (e) {
            this.placeholders = [];
        }
    }

    handleBodyChange(event) {
        this.editedBody = event.target.value;
        this.updatePageInfo();
    }

    handlePlaceholderClick(event) {
        const placeholder = event.currentTarget.dataset.placeholder;
        const textarea = this.template.querySelector('.template-textarea');
        const start = (textarea && textarea.selectionStart != null)
            ? textarea.selectionStart
            : this.editedBody.length;
        const end = (textarea && textarea.selectionEnd != null)
            ? textarea.selectionEnd
            : this.editedBody.length;
        this.editedBody =
            this.editedBody.substring(0, start) +
            placeholder +
            this.editedBody.substring(end);
        this.updatePageInfo();
        // Re-focus textarea after insertion
        if (textarea) {
            const newPos = start + placeholder.length;
            setTimeout(() => {
                textarea.setSelectionRange(newPos, newPos);
                textarea.focus();
            }, 0);
        }
    }

    handleBackdropClick() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    updatePageInfo() {
        const msg = this.editedBody || '';
        const isArabic = /[\u0600-\u06FF]/.test(msg);
        const encoding = isArabic ? 'Arabic' : 'English';
        const firstPageLimit = isArabic ? 70 : 160;
        const subsequentPageLimit = isArabic ? 67 : 153;
        const charCount = msg.length;
        let pageCount = 0;
        let charsRemaining = firstPageLimit;

        if (charCount > 0) {
            if (charCount <= firstPageLimit) {
                pageCount = 1;
                charsRemaining = firstPageLimit - charCount;
            } else {
                pageCount =
                    1 +
                    Math.ceil(
                        (charCount - firstPageLimit) / subsequentPageLimit
                    );
                const usedInLast =
                    (charCount - firstPageLimit) % subsequentPageLimit;
                charsRemaining =
                    usedInLast === 0 ? 0 : subsequentPageLimit - usedInLast;
            }
        }

        this.pageInfo = { encoding, charCount, pageCount, charsRemaining };
    }

    get counterText() {
        const { charCount, pageCount, encoding } = this.pageInfo;
        const limit =
            pageCount <= 1
                ? encoding === 'Arabic' ? 70 : 160
                : encoding === 'Arabic' ? 67 : 153;
        return `Characters: ${charCount}/${limit} | Pages: ${pageCount} | Encoding: ${encoding}`;
    }

    get languageLabel() {
        return this.language === 'ar' ? 'Arabic' : 'English';
    }

    get hasPlaceholders() {
        return this.placeholders && this.placeholders.length > 0;
    }

    async handleSave() {
        try {
            await saveTemplate({
                templateId: this.templateId,
                body: this.editedBody
            });
            this.dispatchEvent(new CustomEvent('save'));
            this.dispatchEvent(new CustomEvent('close'));
        } catch (e) {
            // bubble up to parent for toast
            this.dispatchEvent(
                new CustomEvent('saveerror', { detail: e.body ? e.body.message : 'Save failed' })
            );
        }
    }

    async handleReset() {
        try {
            await resetTemplate({ templateId: this.templateId });
            this.editedBody = this.defaultBody || '';
            this.updatePageInfo();
        } catch (e) {
            this.dispatchEvent(
                new CustomEvent('saveerror', { detail: e.body ? e.body.message : 'Reset failed' })
            );
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}

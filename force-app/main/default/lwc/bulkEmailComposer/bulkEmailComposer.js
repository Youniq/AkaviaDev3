import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, deleteRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import LightningConfirm from 'lightning/confirm';
import sendBulkEmail from '@salesforce/apex/BulkEmailController.sendBulkEmail';
//import getFileSize from '@salesforce/apex/BulkEmailController.getFileSize';

// Fields
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import ACCOUNT_ID_FIELD from '@salesforce/schema/Account.Id';

export default class BulkEmailComposer extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api accountId; // For flow usage
    
    // Data properties
    @track selectedRecipients = [];
    @track emailSubject = '';
    @track emailBody = '';
    // COMMENTED OUT: Attachment logic temporarily disabled due to duplicate errors in Salesforce
    // @track attachmentIds = [];
    // @track uploadedFiles = []; // Array of {id, name, size} objects
    @track attachmentIds = [];
    @track uploadedFiles = [];
    
    // UI state properties
    isLoading = false; // Data loading is now handled by child component
    isSending = false;
    errorMessage = '';
    successMessage = '';
    validationWarning = '';
    
    // Validation limits
    MAX_SUBJECT_LENGTH = 100;
    MAX_BODY_LENGTH = 25000;
    // COMMENTED OUT: Attachment logic temporarily disabled
    // MAX_ATTACHMENT_SIZE_MB = 8;
    // MAX_ATTACHMENT_SIZE_BYTES = 8 * 1024 * 1024; // 8MB in bytes
    
    // Rich text editor allowed formats
    allowedFormats = [
        'font',
        'size',
        'bold',
        'italic',
        'underline',
        'strike',
        'list',
        'align',
        'link',
        'clean',
        'table',
        'header',
        'color',
        'background'
    ];
    
    // Wired properties
    @wire(getRecord, { recordId: '$recordId', fields: [ACCOUNT_NAME_FIELD, ACCOUNT_ID_FIELD] })
    account;
    

    // Lifecycle hook
    connectedCallback() {
        
        // Add keyboard event listener for Escape key
        this.keydownHandler = this.handleKeydown.bind(this);
        document.addEventListener('keydown', this.keydownHandler);
    }


    disconnectedCallback() {
        // Remove keyboard event listener
        if (this.keydownHandler) {
            document.removeEventListener('keydown', this.keydownHandler);
        }
    }

    handleKeydown(event) {
        if (event.key === 'Escape') {
            this.handleCancel();
        }
    }
    
    // Computed properties
    
    get accountName() {
        return this.account.data ? this.account.data.fields.Name.value : '';
    }
    
    get hasSelectedEmployees() {
        return this.selectedRecipients.length > 0;
    }
    
    get effectiveAccountId() {
        
        // For record actions, recordId should be the Account ID
        if (this.recordId) {
            return this.recordId;
        }
        
        // For flows, use the provided accountId
        if (this.accountId) {
            return this.accountId;
        }
        
        console.log('No valid accountId found, returning null');
        return null;
    }
    
    get canSendEmail() {
        return this.hasSelectedEmployees && 
               this.emailSubject.trim() !== '' && 
               this.emailBody.trim() !== '' && 
               !this.isSending &&
               this.isSubjectValid &&
               this.isBodyValid;
               // COMMENTED OUT: Attachment validation temporarily disabled
               // && this.isAttachmentSizeValid;
    }
    
    get isSubjectValid() {
        return this.emailSubject.length <= this.MAX_SUBJECT_LENGTH;
    }
    
    get isBodyValid() {
        return this.emailBody.length <= this.MAX_BODY_LENGTH;
    }
    
    // COMMENTED OUT: Attachment logic temporarily disabled
    /*
    get isAttachmentSizeValid() {
        return this.totalAttachmentSize <= this.MAX_ATTACHMENT_SIZE_BYTES;
    }
    
    get totalAttachmentSize() {
        return this.uploadedFiles.reduce((total, file) => total + (file.size || 0), 0);
    }
    
    get attachmentSizeMB() {
        return (this.totalAttachmentSize / (1024 * 1024)).toFixed(2);
    }
    */
    get isAttachmentSizeValid() {
        return true; // Always valid since attachments are disabled
    }
    
    get totalAttachmentSize() {
        return 0;
    }
    
    get attachmentSizeMB() {
        return '0';
    }
    
    get isSendEmailDisabled() {
        return this.isSending || this.selectedRecipients.length === 0;
    }
    
    // COMMENTED OUT: Attachment logic temporarily disabled
    /*
    get hasUploadedFiles() {
        return this.uploadedFiles && this.uploadedFiles.length > 0;
    }
    */
    get hasUploadedFiles() {
        return false; // Always false since attachments are disabled
    }
    
    get confirmationMessage() {
        return `Du kommer att skicka meddelandet (med ämne: ${this.emailSubject}) till ${this.selectedRecipients.length} bcc mottagare. Utskicket kan inte svaras på. Vill du fortsätta?`;
    }
    
    // Event handlers
    handleRecipientSelectionChange(event) {
        this.selectedRecipients = event.detail.selectedRecipients;
        this.validationWarning = ''; // Clear validation warning when recipients are selected
    }
    
    
    handleSubjectChange(event) {
        this.emailSubject = event.target.value;
        this.validationWarning = ''; // Clear validation warning when user types
    }
    
    handleBodyChange(event) {
        this.emailBody = event.detail.value;
        this.validationWarning = ''; // Clear validation warning when user types
    }
    
    // COMMENTED OUT: Attachment logic temporarily disabled
    /*
    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        
        // Add new files to the uploadedFiles array
        for (const file of uploadedFiles) {
            try {
                // Get file size from Salesforce
                const fileSize = await this.getFileSize(file.documentId);
                
                this.uploadedFiles.push({
                    id: file.documentId,
                    name: file.name,
                    size: fileSize
                });
            } catch (error) {
                console.error('Error getting file size:', error);
                // Add file without size info
                this.uploadedFiles.push({
                    id: file.documentId,
                    name: file.name,
                    size: 0
                });
            }
        }
        
        // Update attachmentIds array
        this.attachmentIds = this.uploadedFiles.map(file => file.id);
        
        // Check if total size exceeds limit
        if (!this.isAttachmentSizeValid) {
            this.validationWarning = `Bifogade filer är för stora (${this.attachmentSizeMB}MB/${this.MAX_ATTACHMENT_SIZE_MB}MB)`;
        }
    }
    
    async getFileSize(documentId) {
        try {
            const result = await getFileSize({ documentId: documentId });
            return result;
        } catch (error) {
            console.error('Error getting file size:', error);
            return 0;
        }
    }
    
    async handleRemoveFile(event) {
        const fileId = event.target.dataset.fileId;
        
        try {
            // Delete file from Salesforce
            await deleteRecord(fileId);
            
            // Remove file from uploadedFiles array
            this.uploadedFiles = this.uploadedFiles.filter(file => file.id !== fileId);
            
            // Update attachmentIds array
            this.attachmentIds = this.uploadedFiles.map(file => file.id);
            
            // Clear validation warning if size is now valid
            if (this.isAttachmentSizeValid) {
                this.validationWarning = '';
            }
            
            this.showToast('Borttagen', 'Filen har tagits bort', 'success');
        } catch (error) {
            console.error('Error deleting file:', error);
            this.showToast('Error', 'Fel vid borttagning av fil', 'error');
        }
    }
    */
    
    
    async sendEmail() {
        // Clear previous validation warnings
        this.validationWarning = '';
        
        // Check validation limits
        if (!this.hasSelectedEmployees) {
            this.validationWarning = 'Vänligen välj minst en mottagare';
            return;
        }
        
        if (this.emailSubject.trim() === '') {
            this.validationWarning = 'Ämne är obligatoriskt';
            return;
        }
        
        if (this.emailBody.trim() === '') {
            this.validationWarning = 'Meddelande är obligatoriskt';
            return;
        }
        
        if (!this.isSubjectValid) {
            this.validationWarning = `Ämnet är för långt (${this.subjectCharacterCount}/${this.MAX_SUBJECT_LENGTH} tecken)`;
            return;
        }
        
        if (!this.isBodyValid) {
            this.validationWarning = `Meddelandet är för långt (${this.bodyCharacterCount}/${this.MAX_BODY_LENGTH} tecken)`;
            return;
        }
        
        // COMMENTED OUT: Attachment validation temporarily disabled
        /*
        if (!this.isAttachmentSizeValid) {
            this.validationWarning = `Bifogade filer är för stora (${this.attachmentSizeMB}MB/${this.MAX_ATTACHMENT_SIZE_MB}MB)`;
            return;
        }
        */
        
        // Show confirmation dialog using LightningConfirm
        const result = await LightningConfirm.open({
            message: this.confirmationMessage,
            variant: 'header',
            label: 'Bekräfta utskick',
            theme: 'warning'
        });
        
        if (result) {
            // User confirmed, proceed with sending
            this.isSending = true;
            this.errorMessage = '';
            this.successMessage = '';
            
            try {
                const emailResult = await sendBulkEmail({
                accountId: this.effectiveAccountId,
                recipients: this.selectedRecipients,
                subject: this.emailSubject,
                body: this.emailBody,
                attachmentIds: null // COMMENTED OUT: Attachment logic temporarily disabled
                // attachmentIds: this.attachmentIds
            });
            
            if (emailResult.success) {
                this.successMessage = emailResult.message;
                this.showToast('Skickat', emailResult.message, 'success');
                
                // Close the modal after a short delay
                setTimeout(() => {
                    this.dispatchEvent(new CloseActionScreenEvent());
                }, 2000);
            } else {
                this.errorMessage = emailResult.message;
                // No toast for errors - only show error banner
            }
        } catch (error) {
            console.error('Error sending email:', error);
            this.errorMessage = 'Något gick fel när meddelandet skulle skickas. Det har inte levererats till någon av mottagarna.';
            // No toast for errors - only show error banner
            } finally {
                this.isSending = false;
            }
        }
    }
    
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}
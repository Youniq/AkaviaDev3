import { LightningElement, api, track } from 'lwc';
import exportMembersToExcel from '@salesforce/apex/MemberExportController.exportMembersToExcel';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MemberExport extends LightningElement {
    @api employerId; // Prio 1: if provided, export members for the specified employer.
    @api associationId; // Prio 2: If provided, export members for all employers connected to the association.
    @track isLoading = false;

    /**
     * Handles the export button click
     */
    handleExportClick() {
        if (!this.associationId && !this.employerId) {
            this.showToast('Error', 'Kan inte exportera medlemslista. Saknar uppgift om förening eller arbetsgivare.', 'error');
            return;
        }

        this.isLoading = true;
        if (this.employerId) {
        
            exportMembersToExcel({ employerId: this.employerId, associationId: null })
                .then(result => {
                    this.generateAndDownloadExcel(result);
                    this.showToast('Success', 'Member data exported successfully', 'success');
                })
                .catch(error => {
                    console.error('Export error:', error);
                    this.showToast('Error', error.body?.message || 'An error occurred during export', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else {
            exportMembersToExcel({ employerId: null, associationId: this.associationId })
                .then(result => {
                    this.generateAndDownloadExcel(result);
                    this.showToast('Success', 'Member data exported successfully', 'success');
                })
                .catch(error => {
                    console.error('Export error:', error);
                    this.showToast('Error', error.body?.message || 'An error occurred during export', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    /**
     * Generates and downloads Excel file from JSON data
     * @param {string} jsonData - JSON string of member data
     */
    generateAndDownloadExcel(jsonData) {
        try {
            const memberData = JSON.parse(jsonData);

            if(memberData.length === 0) {
                this.showToast('Error', 'Inga medlemmar hittades för den angivna arbetsgivaren', 'error');
                return;
            }
            
            // Create CSV content
            const headers = [
                'Medlemsnummer',
                'Förnamn',
                'Efternamn',
                'E-post',
                'Mobil',
                'Aktuell arbetsgivare',
                'Arbetsställenamn',
                'Arbetsställets ort',
                'Arbetsställenummer',
                'Senaste medlemsdatum',
                'Medlemskategori',
                'Senaste anställningens Startdatum'
            ];
            
            // Add BOM (Byte Order Mark) for proper UTF-8 encoding in Excel
            let csvContent = '\uFEFF' + headers.join(';') + '\n';
            
            memberData.forEach(member => {
                const row = [
                    this.escapeCsvValue(member.medlemsnummer || ''),
                    this.escapeCsvValue(member.fornamn || ''),
                    this.escapeCsvValue(member.efternamn || ''),
                    this.escapeCsvValue(member.epost || ''),
                    this.escapeCsvValue(member.mobil || ''),
                    this.escapeCsvValue(member.aktuellArbetsgivare || ''),
                    this.escapeCsvValue(member.arbetsstallenamn || ''),
                    this.escapeCsvValue(member.arbetsstalletsOrt || ''),
                    this.escapeCsvValue(member.arbetsstallenummer || ''),
                    this.escapeCsvValue(member.senasteMedlemsdatum || ''),
                    this.escapeCsvValue(member.medlemskategori || ''),
                    this.escapeCsvValue(member.senasteAnstallningensStartdatum || '')
                ];
                csvContent += row.join(';') + '\n';
            });
            
            // Create and download file using data URI (LWC compatible)
            const csvBlob = new Blob([csvContent], { type: 'text/plain;charset=utf-8' });
            const reader = new FileReader();
            
            reader.onload = function(e) {
                const dataUri = e.target.result;
                const link = document.createElement('a');
                link.href = dataUri;
                link.download = 'Medlemmar_Export_' + new Date().toISOString().split('T')[0] + '.txt';
                link.style.display = 'none';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
            };
            
            reader.readAsDataURL(csvBlob);
            
        } catch (error) {
            console.error('Excel generation error:', error);
            this.showToast('Error', 'Failed to generate Excel file', 'error');
        }
    }

    /**
     * Escapes CSV values to handle commas and quotes
     * @param {string} value - Value to escape
     * @return {string} Escaped value
     */
    escapeCsvValue(value) {
        if (value === null || value === undefined) {
            return '';
        }
        const stringValue = String(value);
        if (stringValue.includes(';') || stringValue.includes('"') || stringValue.includes('\n')) {
            return '"' + stringValue.replace(/"/g, '""') + '"';
        }
        return stringValue;
    }

    /**
     * Shows a toast message
     * @param {string} title - Toast title
     * @param {string} message - Toast message
     * @param {string} variant - Toast variant (success, error, warning, info)
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        dispatchEvent(event);
    }
}
import { LightningElement, api, track } from 'lwc';
import getActiveEmployeesPaginated from '@salesforce/apex/BulkEmailController.getActiveEmployeesPaginated';

export default class BulkEmailRecipientSelector extends LightningElement {
    _accountId;
    
    @api
    get accountId() {
        return this._accountId;
    }
    
    set accountId(value) {
        this._accountId = value;
        if (value && !this.isLoading) {
            this.loadRecipients();
        }
    }
    
    // Data properties
    @track availableRecipients = [];
    @track selectedRecipients = [];
    @track selectedRowKeys = [];
    @track filterValue = '';
    @track selectionFilter = 'all';
    @track isLoading = false;
    @track errorMessage = '';
    
    // Search debouncing and client-side filtering
    searchTimeout;
    debounceDelay = 300; // 300ms delay for client-side filtering
    allLoadedRecipients = []; // Store all loaded data for client-side filtering
    currentSearchTerm = ''; // Track current search term
    
    // Client-side pagination properties
    @track filteredRecipients = []; // All filtered results
    @track paginatedRecipients = []; // Current page results for display
    @track totalFilteredRecords = 0; // Total filtered count
    
    // Pagination properties
    @track currentPage = 1;
    @track pageSize = 25;
    @track totalPages = 0;
    @track hasNextPage = false;
    @track hasPreviousPage = false;
    
    // Sorting properties
    @track sortField = 'workplace'; // Default to workplace name (client-side field name). It is initially sirted on backend
    @track sortDirection = 'asc';
    
    // Selection state
    @track allSelectedRecipients = new Set();

    // Column definitions for lightning-datatable
    get columns() {
        // Force reactivity by accessing tracked properties
        const currentSortField = this.sortField;
        const currentSortDirection = this.sortDirection;
        
        return [
            {
                label: 'Namn',
                fieldName: 'name',
                type: 'text',
                sortable: true,
                sortDirection: currentSortField === 'name' ? currentSortDirection : 'none',
                cellAttributes: { class: 'slds-text-body_regular' }
            },
            {
                label: 'Email',
                fieldName: 'email',
                type: 'email',
                sortable: true,
                sortDirection: currentSortField === 'email' ? currentSortDirection : 'none',
                cellAttributes: { class: 'slds-text-body_regular' }
            },
            {
                label: 'Arbetsplats',
                fieldName: 'workplace',
                type: 'text',
                sortable: true,
                sortDirection: currentSortField === 'workplace' ? currentSortDirection : 'none',
                cellAttributes: { class: 'slds-text-body_small slds-text-color_weak' }
            }
        ];
    }

    get isSelectAllDisabled() {
        return this.availableRecipients.length === 0;
    }
    
    get isClearAllDisabled() {
        return this.selectedRecipients.length === 0;
    }

    // Datatable configuration properties
    get hideCheckboxColumn() {
        return false;
    }

    get showRowNumberColumn() {
        return false;
    }

    get resizeColumns() {
        return true;
    }

    get enableInfiniteLoading() {
        return this.infiniteScrollMode;
    }
    
    get infiniteScrollMode() {
        return false; // Disable infinite scroll to prevent DOM performance issues
    }

    get maxRowSelection() {
        return 1000;
    }

    get maxRowCount() {
        return this.pageSize; // Use pageSize instead of fixed limit
    }
    
    get selectionFilterOptions() {
        return [
            { label: 'Alla mottagare', value: 'all' },
            { label: 'Endast valda', value: 'selected' },
            { label: 'Ej valda', value: 'unselected' }
        ];
    }
    
    get pageSizeOptions() {
        return [
            { label: '25 per sida', value: 25 },
            { label: '50 per sida', value: 50 },
            { label: '100 per sida', value: 100 }
        ];
    }
    
    get isPreviousDisabled() {
        return !this.hasPreviousPage || this.isLoading;
    }
    
    get isNextDisabled() {
        return !this.hasNextPage || this.isLoading;
    }

    // Lifecycle hook
    connectedCallback() {
        // Note: Data loading is now handled by the accountId setter
    }
    
    // Load all recipients upfront for client-side filtering
    async loadRecipients() {
        if (!this.accountId) {
            console.log('loadRecipients called but no accountId');
            return;
        }
        
        this.isLoading = true;
        this.errorMessage = '';
        
        try {            
            const result = await getActiveEmployeesPaginated({
                accountId: this.accountId,
                pageSize: 5000, // Load all records upfront
                pageNumber: 1,
                searchTerm: null, // No search filter
                sortDirection: this.sortDirection
            });
            
            
            if (result) {
                this.allLoadedRecipients = result.records || [];
                
                // Initialize filtered recipients with all data
                this.filteredRecipients = [...this.allLoadedRecipients];
                this.totalFilteredRecords = this.filteredRecipients.length;
                
                // Apply current search filter if any
                if (this.currentSearchTerm) {
                    this.performClientSideSearch(this.currentSearchTerm);
                } else {
                    this.updatePagination();
                }
                
                this.updateSelectedRowKeys();
            }
            
        } catch (error) {
            console.error('Error loading recipients:', error);
            this.errorMessage = 'Fel vid hämtning av mottagare: ' + error.body.message;
            this.allLoadedRecipients = [];
            this.filteredRecipients = [];
        } finally {
            this.isLoading = false;
        }
    }

    // Event handlers
    handleFilterChange(event) {
        this.filterValue = event.target.value;
        this.currentSearchTerm = this.filterValue.trim();
        
        // Clear existing timeout
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        
        // Debounced client-side search
        this.searchTimeout = setTimeout(() => {
            this.performClientSideSearch(this.currentSearchTerm);
        }, this.debounceDelay);
    }
    
    // Client-side search for instant results
    performClientSideSearch(searchTerm) {
        
        // Start with selection-filtered data
        let baseData = [...this.allLoadedRecipients];
        
        // Apply selection filter first
        if (this.selectionFilter === 'selected') {
            baseData = baseData.filter(recipient => 
                this.allSelectedRecipients.has(recipient.id)
            );
        } else if (this.selectionFilter === 'unselected') {
            baseData = baseData.filter(recipient => 
                !this.allSelectedRecipients.has(recipient.id)
            );
        }
        
        // Then apply search filter
        if (searchTerm.length === 0) {
            this.filteredRecipients = baseData;
        } else {
            this.filteredRecipients = baseData.filter(recipient => 
                recipient.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                recipient.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
                recipient.workplace.toLowerCase().includes(searchTerm.toLowerCase())
            );
        }
        
        // Update filtered count and pagination
        this.totalFilteredRecords = this.filteredRecipients.length;
        this.currentPage = 1; // Reset to first page
        this.updatePagination();
        
        this.updateSelectedRowKeys();
    }
    
    // Update pagination for client-side data
    updatePagination() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        
        this.paginatedRecipients = this.filteredRecipients.slice(startIndex, endIndex);
        this.totalPages = Math.ceil(this.totalFilteredRecords / this.pageSize);
        this.hasNextPage = this.currentPage < this.totalPages;
        this.hasPreviousPage = this.currentPage > 1;
        
        // Update availableRecipients for datatable display
        this.availableRecipients = this.paginatedRecipients;

    }
    
    handleSelectionFilterChange(event) {
        this.selectionFilter = event.detail.value;
        
        // Apply selection filter to the filtered recipients
        this.applySelectionFilter();
    }
    
    // Apply selection filter based on current selection filter value
    applySelectionFilter() {
        
        if (this.selectionFilter === 'all') {
            // Show all filtered recipients
            this.filteredRecipients = [...this.allLoadedRecipients];
        } else if (this.selectionFilter === 'selected') {
            // Show only selected recipients
            this.filteredRecipients = this.allLoadedRecipients.filter(recipient => 
                this.allSelectedRecipients.has(recipient.id)
            );
        } else if (this.selectionFilter === 'unselected') {
            // Show only unselected recipients
            this.filteredRecipients = this.allLoadedRecipients.filter(recipient => 
                !this.allSelectedRecipients.has(recipient.id)
            );
        }
        
        // Apply current search filter if any
        if (this.currentSearchTerm) {
            this.performClientSideSearch(this.currentSearchTerm);
        } else {
            // Update filtered count and pagination
            this.totalFilteredRecords = this.filteredRecipients.length;
            this.currentPage = 1; // Reset to first page
            this.updatePagination();
        }
        
        this.updateSelectedRowKeys();
    }
    
    // Pagination handlers
    handlePreviousPage() {
        if (this.hasPreviousPage) {
            this.currentPage--;
            this.updatePagination();
            this.updateSelectedRowKeys();
        }
    }

    handleNextPage() {
        if (this.hasNextPage) {
            this.currentPage++;
            this.updatePagination();
            this.updateSelectedRowKeys();
        }
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value);
        this.currentPage = 1; // Reset to first page
        this.updatePagination();
        this.updateSelectedRowKeys();
    }
    
    // Infinite loading handler (now just moves to next page)
    handleLoadMore(event) {
        if (this.hasNextPage && !this.isLoading) {
            this.currentPage++;
            this.updatePagination();
            this.updateSelectedRowKeys();
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        const selectedRowKeys = event.detail.selectedRows.map(row => row.id);
        
        // Get currently visible recipient IDs
        const visibleRecipientIds = this.availableRecipients.map(r => r.id);
        
        // Remove all visible recipients from the persistent selection
        visibleRecipientIds.forEach(id => {
            this.allSelectedRecipients.delete(id);
        });
        
        // Add back the currently selected visible recipients
        selectedRows.forEach(row => {
            this.allSelectedRecipients.add(row.id);
        });
        
        // Update the UI
        this.updateSelectedRecipients();
        this.selectedRowKeys = selectedRowKeys;
        this.dispatchSelectionChange();
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
                
        // Determine the new sort direction
        let newSortDirection = sortDirection;
        
        // If clicking the same column, toggle the sort direction
        if (this.sortField === fieldName) {
            newSortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        }
                
        this.sortField = fieldName;
        this.sortDirection = newSortDirection;
        
        // Sort the filtered recipients
        this.filteredRecipients.sort((a, b) => {
            let aValue = a[fieldName] || '';
            let bValue = b[fieldName] || '';
            
            // Handle different data types
            if (typeof aValue === 'string') {
                aValue = aValue.toLowerCase();
                bValue = bValue.toLowerCase();
            }
            
            if (newSortDirection === 'asc') {
                return aValue > bValue ? 1 : -1;
            } else {
                return aValue < bValue ? 1 : -1;
            }
        });
        
        // Reset to first page and update pagination
        this.currentPage = 1;
        this.updatePagination();
        this.updateSelectedRowKeys();
    }

    selectAllRecipients() {
        
        // Add ALL loaded recipients to the selection set (not just current page)
        this.allLoadedRecipients.forEach(recipient => {
            this.allSelectedRecipients.add(recipient.id);
        });
        
        // Update the UI
        this.updateSelectedRecipients();
        this.selectedRowKeys = this.availableRecipients.map(recipient => recipient.id);
        this.dispatchSelectionChange();
    }

    clearAllRecipients() {
        this.allSelectedRecipients.clear();
        this.selectedRecipients = [];
        this.selectedRowKeys = [];
        this.dispatchSelectionChange();
    }

    // Update selectedRowKeys for current page
    updateSelectedRowKeys() {
        this.selectedRowKeys = this.availableRecipients
            .filter(recipient => this.allSelectedRecipients.has(recipient.id))
            .map(recipient => recipient.id);
    }
    
    // Update selectedRecipients array to include all selected recipients
    updateSelectedRecipients() {
        
        // Get all selected recipients from allLoadedRecipients (not just current page)
        this.selectedRecipients = Array.from(this.allSelectedRecipients).map(id => {
            // Find the recipient in allLoadedRecipients (not just current page)
            const recipient = this.allLoadedRecipients.find(r => r.id === id);
            if (recipient) {
                return {
                    id: recipient.id,
                    name: recipient.name,
                    email: recipient.email,
                    firstName: recipient.firstName || '',
                    lastName: recipient.lastName || '',
                    workplace: recipient.workplace || ''
                };
            }
            console.warn('Selected recipient not found in allLoadedRecipients:', id);
            return null;
        }).filter(recipient => recipient !== null); // Remove any null entries
    }

    // Dispatch selection change event to parent
    dispatchSelectionChange() {
        const selectionChangeEvent = new CustomEvent('selectionchange', {
            detail: {
                selectedRecipients: this.selectedRecipients
            }
        });
        this.dispatchEvent(selectionChangeEvent);
    }


    // Public method to get selected recipients
    @api
    getSelectedRecipients() {
        return this.selectedRecipients;
    }

    // Public method to set account ID and load recipients
    @api
    setAccountId(accountId) {
        this.accountId = accountId;
        this.allSelectedRecipients.clear();
        this.selectedRecipients = [];
        this.selectedRowKeys = [];
        this.currentPage = 1;
        this.filterValue = '';
        if (accountId) {
            this.loadRecipients();
        }
    }
}
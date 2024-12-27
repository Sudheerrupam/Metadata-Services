    import { LightningElement, track } from 'lwc';
    import { ShowToastEvent } from 'lightning/platformShowToastEvent';
    import getObjects from '@salesforce/apex/PageLayoutController.getObjects';
    import getObjectLayout from '@salesforce/apex/PageLayoutController.getObjectLayout';
    import getLayoutFields from '@salesforce/apex/PageLayoutController.getLayoutFields';
    import getAllLayoutsWithFields from '@salesforce/apex/PageLayoutController.getAllLayoutsWithFields';
    import getRecordTypes from '@salesforce/apex/PageLayoutController.getRecordTypes';
    //import generateCSV from '@salesforce/apex/PageLayoutController.generateCSV';

    export default class PageLayoutExplorer extends LightningElement {
        @track objects = [];
        @track layouts = [];
        @track fields = [];
        @track selectedObject = '';
        @track selectedLayout = '';
        @track selectedRecordType = '';
        @track isLoading = false;
        @track error = null;
        @track showRecordTypeModal = false;

        get isDisabled() {
            return !this.selectedObject || this.isLoading;
        }

        
        static TOAST_TITLES = {
            ERROR: 'Error',
            WARNING: 'Warning',
            SUCCESS: 'Success'
        };

        connectedCallback() {
            this.loadObjects();
        }

        async loadObjects() {
            try {
                this.setLoading(true);
                const result = await getObjects();
                this.objects = result || [];
                
                if (!result?.length) {
                    this.showToast('No objects found', 'No accessible objects were found.', 'warning');
                }
            } catch (error) {
                this.handleError('Error loading objects', error);
            } finally {
                this.setLoading(false);
            }
        }

        async handleObjectChange(event) {
            try {
                this.resetSelections();
                this.selectedObject = event.detail.value;

                if (!this.selectedObject) {
                    return;
                }

                this.setLoading(true);
                const result = await getObjectLayout({ objectName: this.selectedObject });
                this.layouts = result || [];

                if (!result?.length) {
                    this.showToast('No layouts', `No page layouts found for ${this.selectedObject}`, 'warning');
                }
            } catch (error) {
                this.handleError('Error loading layouts', error);
            } finally {
                this.setLoading(false);
            }
        }

        async handleLayoutChange(event) {
            try {
                this.selectedLayout = event.detail.value;
                this.fields = [];

                if (!this.selectedObject || !this.selectedLayout) {
                    return;
                }

                this.setLoading(true);
                const result = await getLayoutFields({
                    objectName: this.selectedObject,
                    layout: this.selectedLayout
                });

                if (result) {
                    this.fields = Object.entries(result).map(([section, fields]) => ({
                        sectionName: section,
                        fields: fields,
                        key: `${section}-${Date.now()}` 
                    }));
                } else {
                    this.showToast('No fields', 'No fields found in the selected layout', 'warning');
                }
            } catch (error) {
                this.handleError('Error loading fields', error);
            } finally {
                this.setLoading(false);
            }
        }
        async loadRecordTypes() {
            if (!this.selectedObject) return;
            
            try {
                this.setLoading(true);
                const result = await getRecordTypes({ objectName: this.selectedObject });
                this.recordTypes = result || [];
                
                if (this.recordTypes.length > 0) {
                    this.showRecordTypeModal = true;
                } else {
                
                    this.downloadAllLayouts();
                }
            } catch (error) {
                this.handleError('Error loading record types', error);
            } finally {
                this.setLoading(false);
            }
        }
    
        async handleDownloadAll() {
            if (!this.selectedObject) {
                this.showToast('Error', 'Please select an object first.', 'error');
                return;
            }
            
            await this.loadRecordTypes();
        }
        
        handleRecordTypeSelect(event) {
            this.selectedRecordType = event.detail.value;
        }
        
        closeRecordTypeModal() {
            this.showRecordTypeModal = false;
            this.selectedRecordType = '';
        }
        
        async confirmRecordTypeSelection() {
            this.showRecordTypeModal = false;
            await this.downloadAllLayouts();
        }
    
        async downloadAllLayouts() {
            try {
                this.setLoading(true);
                const allLayouts = await getAllLayoutsWithFields({ 
                    objectName: this.selectedObject,
                    recordTypeId: this.selectedRecordType 
                });
                const csvContent = this.generateCSVContentForAll(allLayouts);
                
                const downloadElement = document.createElement('a');
                const encodedContent = encodeURIComponent(csvContent);
                downloadElement.href = 'data:text/csv;charset=utf-8,' + encodedContent;
                
                const recordTypeSuffix = this.selectedRecordType ? 
                    `_RT_${this.getRecordTypeName(this.selectedRecordType)}` : '';
                downloadElement.download = `${this.selectedObject}${recordTypeSuffix}_AllLayouts_${this.getTimestamp()}.csv`;
                
                downloadElement.style.display = 'none';
                document.body.appendChild(downloadElement);
                downloadElement.click();
                document.body.removeChild(downloadElement);
                
                this.showToast('Success', 'CSV file generated successfully', 'success');
            } catch (error) {
                this.handleError('Error downloading layouts', error);
            } finally {
                this.setLoading(false);
            }
        }
        
            get recordTypeOptions() {
                return [
                    { label: 'All Record Types', value: '' },
                    ...this.recordTypes.map(rt => ({
                        label: rt.name,
                        value: rt.recordTypeId
                    }))
                ];
            }
        
            getRecordTypeName(recordTypeId) {
                const recordType = this.recordTypes.find(rt => rt.recordTypeId === recordTypeId);
                return recordType ? recordType.developerName : '';
            }
        generateCSVContentForAll(allLayouts) {
            const header = 'Object Name,Page Layout Name,Section,Field\n';
            let csvContent = header;
            
            for (const [layoutName, sections] of Object.entries(allLayouts)) {
                for (const [sectionName, fields] of Object.entries(sections)) {
                    for (const field of fields) {
                        if (field.includes(' -> ')) {
                            
                            const [lookupField, relatedObject] = field.split(' -> ');
                            
                            
                            csvContent += `${this.selectedObject},${layoutName},${sectionName},${lookupField}\n`;
                            
                            
                            const [relObj, relField] = relatedObject.split('.');
                            csvContent += `${relObj},${layoutName},${sectionName},${relField}\n`;
                        } else {
                            
                            csvContent += `${this.selectedObject},${layoutName},${sectionName},${field}\n`;
                        }
                    }
                }
            }
            
            return csvContent;
        }
        
        getTimestamp() {
            const now = new Date();
            return now.toISOString()
                .replace(/[:-]/g, '')
                .replace(/\..+/, '')
                .replace('T', '_');
        }
        
        handleError(title, error) {
            console.error(title, error);
            const message = error.body?.message || error.message || 'An unexpected error occurred';
            this.showToast(title, message, 'error');
        }
        
        showToast(title, message, variant) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title,
                    message,
                    variant
                })
            );
        }
        
        getFileName(type) {
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            return `${this.selectedObject}_${type === 'all' ? 'AllLayouts' : this.selectedLayout}_${timestamp}.csv`;
        }

        downloadCSV() {
            const csvContent = 'data:text/csv;charset=utf-8,' + encodeURIComponent(this.generateCSVContent());
            const downloadElement = document.createElement('a');
            downloadElement.href = csvContent;
            downloadElement.download = 'layouts.csv'; 
            downloadElement.click();
            downloadElement.remove();
        }
        
        
        generateCSVContent() {
            let csvString = 'Field Name,Field Label,Data Type\n'; 
            this.fields.forEach(field => {
                csvString += `${field.apiName},${field.label},${field.dataType}\n`; 
            });
            return csvString;
        }
        

        setLoading(isLoading) {
            this.isLoading = isLoading;
        }

        showToast(title, message, variant) {
            const toastEvent = new ShowToastEvent({
                title,
                message,
                variant,
            });
            this.dispatchEvent(toastEvent);
        }

        handleError(title, error) {
            console.error(error);
            this.showToast(title, error?.body?.message || error.message, 'error');
        }



        async handleDownload() {
            if (!this.validateDownload()) {
                return;
            }
        
            try {
                this.setLoading(true);
                const csvContent = this.generateCSVContent();
                const encodedContent = encodeURIComponent(csvContent);
                const dataUrl = 'data:text/csv;charset=utf-8,' + encodedContent;
                const downloadElement = document.createElement('a');
                downloadElement.href = dataUrl;
                downloadElement.target = '_self'; 
                downloadElement.download = this.getFileName();
                downloadElement.click();
                this.showToast('Success', 'CSV file downloaded successfully', 'success');
            } catch (error) {
                this.handleError('Error generating CSV', error);
            } finally {
                this.setLoading(false);
            }
        }

        validateDownload() {
            if (!this.selectedObject || !this.selectedLayout) {
                this.showToast('Missing Selection', 'Please select both an Object and a Layout', 'warning');
                return false;
            }

            if (!this.fields?.length) {
                this.showToast('No Data', 'No fields available for the selected Layout', 'warning');
                return false;
            }

            return true;
        }

        generateCSVContent() {
            const csvData = [['Object Name', 'Page Layout Name', 'Section', 'Fields']];

            this.fields.forEach(({ sectionName, fields }) => {
                fields.forEach(field => {
                    if(field.includes(' -> ')){

                        const lookupField = field.split(' -> ')[0];
                        const relatedObject = field.split(' -> ')[1];
                        csvData.push([
                            this.selectedObject,
                            this.selectedLayout,
                            sectionName,
                            lookupField
                        ]);
                        csvData.push([
                            relatedObject.split('.')[0],
                            this.selectedLayout,
                            sectionName,
                            relatedObject
                        ]);
                    }
                    else {
                        csvData.push([
                            this.selectedObject,
                            this.selectedLayout,
                            sectionName,
                            field
                        ]);
                    }
                });
            });

            return csvData.map(row => 
                row.map(cell => 
                    this.formatCSVCell(cell)
                ).join(',')
            ).join('\n');
        }

        formatCSVCell(cell) {
            if (!cell) return '""';
            const escaped = cell.toString().replace(/"/g, '""');
            return /[,"\n]/.test(escaped) ? `"${escaped}"` : escaped;
        }

        downloadCSV(content, fileName) {
            const link = document.createElement('a');
            const csvData = new Blob([content], { type: 'text/csv;charset=utf-8;' }); 
            const url = window.URL.createObjectURL(csvData);  
            link.href = url;
            link.setAttribute('download', fileName);
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            window.URL.revokeObjectURL(url);
        }

        getFileName() {
            return `${this.selectedObject}_${this.selectedLayout}_PageLayout_${this.getTimestamp()}.csv`;
        }

        getTimestamp() {
            return new Date().toISOString().replace(/[:.]/g, '-');
        }

        
        get objectOptions() {
            return this.objects.map(obj => ({
                label: obj,
                value: obj
            }));
        }

        get layoutOptions() {
            return this.layouts.map(layout => ({
                label: layout,
                value: layout
            }));
        }

    
        setLoading(loading) {
            this.isLoading = loading;
        }

        resetSelections() {
            this.layouts = [];
            this.fields = [];
            this.selectedLayout = '';
            this.error = null;
        }

        showToast(title, message, variant) {
            this.dispatchEvent(new ShowToastEvent({
                title,
                message,
                variant: variant || 'info'
            }));
        }

        handleError(title, error) {
            console.error(title, error);
            this.error = error;
            this.showToast(
                title,
                error.message || 'An unexpected error occurred',
                'error'
            );
        }
    }
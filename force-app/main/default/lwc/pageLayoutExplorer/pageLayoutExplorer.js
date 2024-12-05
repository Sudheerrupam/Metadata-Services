import { LightningElement, track } from 'lwc';
import getObjects from '@salesforce/apex/PageLayoutController.getObjects';
import getObjectLayout from '@salesforce/apex/PageLayoutController.getObjectLayout';
import getLayoutFields from '@salesforce/apex/PageLayoutController.getLayoutFields';
import generateCSV from '@salesforce/apex/PageLayoutController.generateCSV';

export default class PageLayoutExplorer extends LightningElement {
    @track objects = [];
    @track layouts = [];
    @track fields = [];
    @track selectedObject = '';
    @track selectedLayout = '';
    @track isLoading = false;

    connectedCallback() {
        this.loadObjects();
    }

    loadObjects() {
        this.isLoading = true;
        getObjects()
            .then(result => {
                if (result) {
                    this.objects = result;
                } else {
                    console.warn('No objects returned.');
                    this.objects = [];
                }
            })
            .catch(error => {
                console.error('Error loading objects:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.layouts = [];
        this.fields = [];
        this.selectedLayout = '';

        if (this.selectedObject) {
            this.isLoading = true;
            getObjectLayout({ objectName: this.selectedObject })
                .then(result => {
                    if (result) {
                        this.layouts = result;
                    } else {
                        console.warn('No layouts returned.');
                        this.layouts = [];
                    }
                })
                .catch(error => {
                    console.error('Error loading layouts:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    handleLayoutChange(event) {
        this.selectedLayout = event.detail.value;
    
        if (this.selectedObject && this.selectedLayout) {
            this.isLoading = true;
            getLayoutFields({
                objectName: this.selectedObject,
                layout: this.selectedLayout
            })
                .then(result => {
                    if (result) {
                        console.log('Fields by Section:', result);
                        this.fields = Object.entries(result).map(([section, fields]) => ({
                            sectionName: section,
                            fields: fields
                        }));
                    } else {
                        console.warn('No fields returned.');
                        this.fields = [];
                    }
                })
                .catch(error => {
                    console.error('Error loading fields:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }
    

    handleDownload() {
        console.log('Download button clicked.');
        if (!this.selectedObject || !this.selectedLayout) {
            alert('Please select an Object and a Layout before downloading.');
            return;
        }
    
        if (!this.fields || this.fields.length === 0) {
            alert('No fields available for the selected Layout.');
            return;
        }
    
        this.generateCSVFile();
    }
    
    generateCSVFile() {
        console.log('Generating CSV for Object:', this.selectedObject, 'Layout:', this.selectedLayout);
    
        const csvData = [
            ['Object Name', 'Page Layout Name', 'Section', 'Fields']
        ];
    
        this.fields.forEach((section) => {
            const sectionName = section.sectionName;    
            section.fields.forEach((field) => {
                csvData.push([this.selectedObject, this.selectedLayout, sectionName, field]);
            });
        });
    
        const csvContent = csvData.map(row => row.join(',')).join('\n');
        this.downloadCSV(csvContent, `${this.selectedObject}_${this.selectedLayout}_PageLayout.csv`);
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

    get fieldColumns() {
        return [
            { label: 'Field Name', fieldName: 'field', type: 'text' }
        ];
    }

    get fieldTableData() {
        return this.fields.map((field, index) => ({
            id: index,
            field: field
        }));
    }

    downloadCSV(csvContent, fileName) {
        console.log('Downloading CSV file:', fileName);
    
        try {
            const csvData = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
    
            const link = document.createElement('a');
            link.setAttribute('href', csvData);
            link.setAttribute('download', fileName);
            link.style.visibility = 'hidden';
    
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
    
            console.log('CSV file download triggered successfully.');
        } catch (error) {
            console.error('Error generating CSV:', error);
            alert('An error occurred while downloading the file. Check the console for details.');
        }
    }
    
    
}

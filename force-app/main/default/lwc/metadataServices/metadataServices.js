import { LightningElement, wire, track } from 'lwc';
import getObjects from '@salesforce/apex/PageLayoutController.getObjects';
import getObjectLayout from '@salesforce/apex/PageLayoutController.getObjectLayout';
import getLayoutFields from '@salesforce/apex/PageLayoutController.getLayoutFields';
//import getFieldsInLayoutSection from '@salesforce/apex/MetadataController.getFieldsInLayoutSection';

export default class MetadataServices extends LightningElement {
    @track objectOptions = [];
    @track layoutOptions = [];
    @track sectionOptions = [];
    @track fieldOptions = [];

    @track selectedObject = '';
    @track selectedLayout = '';
    @track selectedSection = '';
    @track selectedField = '';

    @wire(getObjects)
    wiredObjectOptions({ data, error }) {
        if (data) {
            this.objectOptions = [
                { label: 'Select an Object', value: '' },
                ...data.map(item => ({ label: item, value: item }))
            ];
            console.log('Objects :' , JSON.stringify(this.objectOptions));
        } else if (error) {
            console.error('Error fetching objects:', error);
        }
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedLayout = '';
        this.selectedSection = '';
        this.selectedField = '';
        
        // Reset dependent fields
        this.layoutOptions = [];
        this.sectionOptions = [];
        this.fieldOptions = [];

        if (this.selectedObject) {
            this.fetchLayouts();
        }
    }

    fetchLayouts() {
        getObjectLayout({ objectName: this.selectedObject })
            .then(result => {
                console.log('result: ', JSON.stringify(result));
                
                this.layoutOptions = [
                    { label: 'Select a Layout', value: '' },
                    ...result.map(item => ({ label: item, value: item }))
                ];
                console.log('Layouts :' , JSON.stringify(this.layoutOptions));
            })
            .catch(error => {
                console.error('Error fetching layouts:', error);
            });
    }

    handleLayoutChange(event) {
        this.selectedLayout = event.detail.value;
        this.selectedSection = '';
        this.selectedField = '';

        // Reset dependent fields
        this.sectionOptions = [];
        this.fieldOptions = [];

        if (this.selectedLayout) {
            this.fetchSections();
        }
    }

    fetchSections() {
        getLayoutFields({ 
            objectName: this.selectedObject, 
            layoutName: this.selectedLayout 
        })
        .then(result => {
            this.sectionOptions = [
                { label: 'Select a Section', value: '' },
                ...result.map(item => ({ label: item, value: item }))
            ];
        })
        .catch(error => {
            console.error('Error fetching sections:', error);
        });
    }

    handleSectionChange(event) {
        this.selectedSection = event.detail.value;
        this.selectedField = '';

        // Reset field options
        this.fieldOptions = [];

        if (this.selectedSection) {
            this.fetchFields();
        }
    }

    fetchFields() {
        getLayoutFields({ 
            objectName: this.selectedObject, 
            layoutName: this.selectedLayout,
            sectionName: this.selectedSection
        })
        .then(result => {
            this.fieldOptions = [
                { label: 'Select a Field', value: '' },
                ...result.map(item => ({ label: item, value: item }))
            ];
        })
        .catch(error => {
            console.error('Error fetching fields:', error);
        });
    }

    handleFieldChange(event) {
        this.selectedField = event.detail.value;
    }
}
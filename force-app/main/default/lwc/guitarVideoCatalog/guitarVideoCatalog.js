import { LightningElement, track, wire } from 'lwc';
import getVideos from '@salesforce/apex/GuitarVideoController.getVideos';

export default class GuitarVideoCatalog extends LightningElement {
    @track selectedLevel = '';
    @track selectedCategory = '';

    @wire(getVideos, { level: '$selectedLevel', category: '$selectedCategory' })
    wiredVideos;

    get videos() {
        return this.wiredVideos?.data;
    }

    get hasVideos() {
        return this.wiredVideos?.data?.length > 0;
    }

    get isEmpty() {
        return this.wiredVideos?.data?.length === 0;
    }

    get hasError() {
        return !!this.wiredVideos?.error;
    }

    handleLevelChange(event) {
        this.selectedLevel = event.target.value;
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.target.value;
    }
}

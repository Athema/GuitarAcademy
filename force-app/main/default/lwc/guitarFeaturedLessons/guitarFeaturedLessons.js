import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getFeaturedVideos from '@salesforce/apex/GuitarVideoController.getFeaturedVideos';

export default class GuitarFeaturedLessons extends NavigationMixin(LightningElement) {
    @wire(getFeaturedVideos)
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

    get errorMessage() {
        return JSON.stringify(this.wiredVideos?.error);
    }

    handleBrowseAll() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/catalog' }
        });
    }
}

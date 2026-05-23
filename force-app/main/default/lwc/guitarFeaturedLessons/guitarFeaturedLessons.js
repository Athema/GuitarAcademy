import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getFeaturedVideos from '@salesforce/apex/GuitarVideoController.getFeaturedVideos';
import getMyAccess from '@salesforce/apex/GuitarVideoController.getMyAccess';

export default class GuitarFeaturedLessons extends NavigationMixin(LightningElement) {
    @wire(getFeaturedVideos)
    wiredVideos;

    @track accessInfo;

    connectedCallback() {
        getMyAccess()
            .then(result => { this.accessInfo = result; })
            .catch(() => {});
    }

    get videosWithAccess() {
        const videos = this.wiredVideos?.data;
        if (!videos) return [];
        const isSubscribed = this.accessInfo?.isSubscribed || false;
        const purchasedIds = this.accessInfo?.purchasedVideoIds || [];
        return videos.map(v => ({
            video: v,
            isOwned: isSubscribed || purchasedIds.includes(v.Id),
            key: v.Id
        }));
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

import { LightningElement, track, wire } from 'lwc';
import getVideos from '@salesforce/apex/GuitarVideoController.getVideos';
import getMyAccess from '@salesforce/apex/GuitarVideoController.getMyAccess';

export default class GuitarVideoCatalog extends LightningElement {
    @track selectedLevel = '';
    @track selectedCategory = '';
    @track accessInfo;

    @wire(getVideos, { level: '$selectedLevel', category: '$selectedCategory' })
    wiredVideos;

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

    handleLevelChange(event) {
        this.selectedLevel = event.target.value;
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.target.value;
    }
}

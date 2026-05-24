import { LightningElement, track, wire } from 'lwc';
import { subscribe, unsubscribe } from 'lightning/empApi';
import getVideos from '@salesforce/apex/GuitarVideoController.getVideos';
import getMyAccess from '@salesforce/apex/GuitarVideoController.getMyAccess';

const FILTER_CHANNEL = '/event/CatalogFilter__e';

export default class GuitarVideoCatalog extends LightningElement {
    @track selectedLevel = '';
    @track selectedCategory = '';
    @track accessInfo;

    _filterSubscription;

    @wire(getVideos, { level: '$selectedLevel', category: '$selectedCategory' })
    wiredVideos;

    connectedCallback() {
        getMyAccess()
            .then(result => { this.accessInfo = result; })
            .catch(() => {});

        subscribe(FILTER_CHANNEL, -1, event => {
            const payload = event.data.payload;
            this.selectedLevel    = payload.Level__c    || '';
            this.selectedCategory = payload.Category__c || '';
        }).then(response => {
            this._filterSubscription = response;
        });
    }

    disconnectedCallback() {
        if (this._filterSubscription) {
            unsubscribe(this._filterSubscription, () => {});
        }
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

    get subscriptionLabel() {
        const info = this.accessInfo;
        if (!info?.isSubscribed) return '';
        const d = info.subscriptionEndDate;
        if (!d) return 'Subscribed';
        const [year, month, day] = d.split('-');
        const formatted = new Date(+year, +month - 1, +day).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
        return `Subscribed until ${formatted}`;
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

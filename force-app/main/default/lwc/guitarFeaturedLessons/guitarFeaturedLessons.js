import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getFeaturedVideos from '@salesforce/apex/GuitarVideoController.getFeaturedVideos';
import getMyAccess from '@salesforce/apex/GuitarVideoController.getMyAccess';
import getFilterSettings from '@salesforce/apex/GuitarVideoController.getFilterSettings';
import updateContactPage from '@salesforce/apex/GuitarVideoController.updateContactPage';

export default class GuitarFeaturedLessons extends NavigationMixin(LightningElement) {
    @wire(getFeaturedVideos)
    wiredVideos;

    @track accessInfo;
    _accessPoll;
    _lastAccessActionKey = '';

    connectedCallback() {
        this._loadAccess();
        this._accessPoll = setInterval(() => {
            getFilterSettings()
                .then(result => this._handleAccessAction(result))
                .catch(() => {});
        }, 2000);
    }

    disconnectedCallback() {
        if (this._accessPoll) clearInterval(this._accessPoll);
    }

    _loadAccess() {
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

    get errorMessage() {
        return JSON.stringify(this.wiredVideos?.error);
    }

    handleFeaturedPointerDown(event) {
        const videoId = event.currentTarget?.dataset?.videoId;
        if (!videoId) return;
        updateContactPage({
            pageName: 'video',
            sessionKey: localStorage.getItem('ga_conversationId') || null,
            videoId
        }).catch(() => {});
    }

    handleBrowseAll() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/catalog' }
        });
    }

    _handleAccessAction(result) {
        const action = result?.action || '';
        const actionVideoId = result?.actionVideoId || '';
        const actionKey = `${action}:${actionVideoId}`;
        if (!action || actionKey === this._lastAccessActionKey) return;
        this._lastAccessActionKey = actionKey;
        if (action === 'PURCHASE' || action === 'SUBSCRIBE') {
            this._loadAccess();
        }
    }
}

import { LightningElement, track, wire } from 'lwc';
import getVideos from '@salesforce/apex/GuitarVideoController.getVideos';
import getMyAccess from '@salesforce/apex/GuitarVideoController.getMyAccess';
import getAgentAction from '@salesforce/apex/GuitarVideoController.getAgentAction';
import getFilterSettings from '@salesforce/apex/GuitarVideoController.getFilterSettings';

export default class GuitarVideoCatalog extends LightningElement {
    @track selectedLevel = '';
    @track selectedCategory = '';
    @track accessInfo;

    _conversationId = null;
    _openHandler = null;
    _messageHandler = null;
    _filterPoll = null;

    @wire(getVideos, { level: '$selectedLevel', category: '$selectedCategory' })
    wiredVideos;

    connectedCallback() {
        getMyAccess()
            .then(result => { this.accessInfo = result; })
            .catch(() => {});

        // Persist conversationId across LWR navigation (component is recreated on each page)
        this._conversationId = localStorage.getItem('ga_conversationId') || null;

        this._openHandler = (event) => {
            this._conversationId = event.detail?.conversationId || null;
            if (this._conversationId) localStorage.setItem('ga_conversationId', this._conversationId);
        };

        this._applyFilter = () => {
            const convId = this._conversationId || localStorage.getItem('ga_conversationId');
            if (convId) {
                getAgentAction({ conversationId: convId })
                    .then(result => {
                        if (result?.action === 'FILTER') {
                            const payload = JSON.parse(result.json || '{}');
                            this.selectedLevel    = payload.level    || '';
                            this.selectedCategory = payload.category || '';
                        }
                    })
                    .catch(() => {});
            }
            // Always also poll FilterState__c as a belt-and-suspenders fallback
            getFilterSettings()
                .then(result => {
                    if (!result) return;
                    const lvl = result.level    || '';
                    const cat = result.category || '';
                    if (lvl !== this.selectedLevel || cat !== this.selectedCategory) {
                        this.selectedLevel    = lvl;
                        this.selectedCategory = cat;
                    }
                })
                .catch(() => {});
        };

        // Trigger immediately on agent messages (only agent messages carry conversationEntry)
        this._messageHandler = (event) => {
            if (!event.detail?.conversationEntry) return;
            this._applyFilter();
        };

        // Poll every 2 s as fallback (covers timing gaps and page-load state)
        this._filterPoll = setInterval(this._applyFilter, 2000);

        window.addEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
        window.addEventListener('onEmbeddedMessageSent', this._messageHandler);
    }

    disconnectedCallback() {
        if (this._openHandler)   window.removeEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
        if (this._messageHandler) window.removeEventListener('onEmbeddedMessageSent', this._messageHandler);
        if (this._filterPoll)    clearInterval(this._filterPoll);
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

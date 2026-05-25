import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getFeaturedVideos from '@salesforce/apex/GuitarVideoController.getFeaturedVideos';
import getMyAccess from '@salesforce/apex/GuitarVideoController.getMyAccess';
import getAgentAction from '@salesforce/apex/GuitarVideoController.getAgentAction';
import updateContactPage from '@salesforce/apex/GuitarVideoController.updateContactPage';

export default class GuitarFeaturedLessons extends NavigationMixin(LightningElement) {
    @wire(getFeaturedVideos)
    wiredVideos;

    @track accessInfo;
    _conversationId = null;
    _openHandler = null;
    _messageHandler = null;
    _lastAccessActionKey = '';

    connectedCallback() {
        this._loadAccess();
        this._conversationId = localStorage.getItem('ga_conversationId') || null;

        this._openHandler = (event) => {
            this._conversationId = event.detail?.conversationId || null;
            if (this._conversationId) localStorage.setItem('ga_conversationId', this._conversationId);
        };

        // Event-driven off the agent's reply — read the action from the MessagingSession (no poll).
        this._messageHandler = (event) => {
            if (!event.detail?.conversationEntry) return;
            if (!this._conversationId) return;
            getAgentAction({ conversationId: this._conversationId })
                .then(result => this._handleAccessAction(result))
                .catch(() => {});
        };

        window.addEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
        window.addEventListener('onEmbeddedMessageSent', this._messageHandler);
    }

    disconnectedCallback() {
        if (this._openHandler) window.removeEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
        if (this._messageHandler) window.removeEventListener('onEmbeddedMessageSent', this._messageHandler);
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
        if (!action) return;
        // Subscribe is account-wide and _loadAccess is idempotent — always refresh so a
        // monthly->annual upgrade (same 'SUBSCRIBE' key) still updates the "Subscribed until" date.
        if (action === 'SUBSCRIBE') {
            this._loadAccess();
            return;
        }
        const actionVideoId = result?.actionVideoId || '';
        const actionKey = `${action}:${actionVideoId}`;
        if (actionKey === this._lastAccessActionKey) return;
        this._lastAccessActionKey = actionKey;
        if (action === 'PURCHASE') {
            this._loadAccess();
        }
    }
}

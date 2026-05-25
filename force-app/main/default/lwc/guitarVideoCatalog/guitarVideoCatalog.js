import { LightningElement, track, wire } from 'lwc';
import getVideos from '@salesforce/apex/GuitarVideoController.getVideos';
import getMyAccess from '@salesforce/apex/GuitarVideoController.getMyAccess';
import getAgentAction from '@salesforce/apex/GuitarVideoController.getAgentAction';

export default class GuitarVideoCatalog extends LightningElement {
    @track selectedLevel = '';
    @track selectedCategory = '';
    @track accessInfo;

    _conversationId = null;
    _openHandler = null;
    _messageHandler = null;
    _lastAccessActionKey = '';

    @wire(getVideos, { level: '$selectedLevel', category: '$selectedCategory' })
    wiredVideos;

    connectedCallback() {
        this._loadAccess();

        // Persist conversationId across LWR navigation (component is recreated on each page)
        this._conversationId = localStorage.getItem('ga_conversationId') || null;

        this._openHandler = (event) => {
            this._conversationId = event.detail?.conversationId || null;
            if (this._conversationId) localStorage.setItem('ga_conversationId', this._conversationId);
        };

        // Outbound is event-driven off the agent's reply — read the action from the
        // MessagingSession (no polling). Only agent messages carry conversationEntry.
        this._messageHandler = (event) => {
            if (!event.detail?.conversationEntry) return;
            this._checkAgentAction();
        };

        window.addEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
        window.addEventListener('onEmbeddedMessageSent', this._messageHandler);

        // Intentionally NOT applying any pre-existing filter on load — navigating to the catalog
        // clears the filter (the session's FILTER action is cleared by updateContactPage on
        // non-video pages), so the catalog always opens on "all lessons".
    }

    disconnectedCallback() {
        if (this._openHandler)   window.removeEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
        if (this._messageHandler) window.removeEventListener('onEmbeddedMessageSent', this._messageHandler);
    }

    _checkAgentAction() {
        if (!this._conversationId) return;
        getAgentAction({ conversationId: this._conversationId })
            .then(result => {
                if (!result) return;
                // Apply the filter ONLY on a FILTER action — otherwise a later
                // PURCHASE/SUBSCRIBE read (empty level/category) would wipe the active filter.
                if (result.action === 'FILTER') {
                    const lvl = result.level    || '';
                    const cat = result.category || '';
                    if (lvl !== this.selectedLevel || cat !== this.selectedCategory) {
                        this.selectedLevel    = lvl;
                        this.selectedCategory = cat;
                    }
                }
                this._handleAccessAction(result);
            })
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

    // Options rendered with `selected` bound to state, so an agent-applied filter
    // (or a manual change) is reflected in the dropdowns.
    get levelOptions() {
        return [
            { value: '', label: 'All Levels' },
            { value: 'Beginner', label: 'Beginner' },
            { value: 'Intermediate', label: 'Intermediate' },
            { value: 'Advanced', label: 'Advanced' }
        ].map(o => ({ ...o, selected: o.value === this.selectedLevel }));
    }

    get categoryOptions() {
        return [
            { value: '', label: 'All Categories' },
            { value: 'Technique', label: 'Technique' },
            { value: 'Theory', label: 'Theory' },
            { value: 'Song Lesson', label: 'Song Lesson' },
            { value: 'Gear & Tone', label: 'Gear & Tone' }
        ].map(o => ({ ...o, selected: o.value === this.selectedCategory }));
    }

    handleLevelChange(event) {
        this.selectedLevel = event.target.value;
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.target.value;
    }

    _loadAccess() {
        getMyAccess()
            .then(result => { this.accessInfo = result; })
            .catch(() => {});
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

import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import updateContactPage from '@salesforce/apex/GuitarVideoController.updateContactPage';

const CONV_KEY = 'ga_conversationId';

function resolvePage(pageRef) {
    const type = pageRef.type || '';
    const attrs = pageRef.attributes || {};
    if (type === 'comm__namedPage') {
        const name = attrs.name || '';
        return name.replace(/__c$/i, '').toLowerCase() || 'named:unknown';
    }
    if (type === 'standard__recordPage' && attrs.objectApiName === 'Guitar_Video__c') {
        return 'video';
    }
    return type || 'unknown';
}

function getVideoId(pageRef) {
    const type = pageRef.type || '';
    const attrs = pageRef.attributes || {};
    if (type === 'standard__recordPage' && attrs.objectApiName === 'Guitar_Video__c') {
        return attrs.recordId || null;
    }
    return null;
}

export default class GuitarPageTracker extends LightningElement {
    _lastPage = null;
    _conversationId = null;
    _openHandler = null;

    connectedCallback() {
        // Restore conversationId across navigation (component is recreated on each page)
        this._conversationId = localStorage.getItem(CONV_KEY) || null;

        this._openHandler = (event) => {
            this._conversationId = event.detail?.conversationId || null;
            if (this._conversationId) {
                localStorage.setItem(CONV_KEY, this._conversationId);
            }
            if (this._lastPage) {
                updateContactPage({
                    pageName: this._lastPage,
                    sessionKey: this._conversationId,
                    videoId: this._lastVideoId || null
                }).catch(() => {});
            }
        };
        window.addEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
    }

    disconnectedCallback() {
        if (this._openHandler) window.removeEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
    }

    @wire(CurrentPageReference)
    handlePageChange(pageRef) {
        if (!pageRef) return;
        const pageName = resolvePage(pageRef);
        const videoId = getVideoId(pageRef);
        if (pageName === this._lastPage && videoId === this._lastVideoId) return;
        this._lastPage = pageName;
        this._lastVideoId = videoId;
        updateContactPage({ pageName, sessionKey: this._conversationId, videoId }).catch(() => {});
    }
}

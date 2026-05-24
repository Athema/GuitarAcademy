import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import updateContactPage from '@salesforce/apex/GuitarVideoController.updateContactPage';
import getAgentPageContext from '@salesforce/apex/GuitarVideoController.getAgentPageContext';

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

export default class GuitarSessionDebug extends LightningElement {
    currentPage = '—';
    rawPageRef = '—';
    sessionKeyDisplay = 'waiting...';
    agentPage = '…';
    _conversationId = null;
    _openHandler = null;
    _contextPoll = null;

    connectedCallback() {
        this._conversationId = localStorage.getItem(CONV_KEY) || null;
        this.sessionKeyDisplay = this._conversationId ? this._conversationId.slice(0, 8) + '…' : 'waiting...';

        this._openHandler = (event) => {
            this._conversationId = event.detail?.conversationId || null;
            if (this._conversationId) {
                localStorage.setItem(CONV_KEY, this._conversationId);
            }
            this.sessionKeyDisplay = this._conversationId ? this._conversationId.slice(0, 8) + '…' : 'no conversationId';
            if (this.currentPage !== '—') {
                updateContactPage({
                    pageName: this.currentPage,
                    sessionKey: this._conversationId,
                    videoId: this._lastVideoId || null
                }).catch(() => {});
            }
        };
        window.addEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);

        this._contextPoll = setInterval(() => {
            getAgentPageContext({ sessionKey: this._conversationId })
                .then(val => { this.agentPage = val || '(blank)'; })
                .catch(() => { this.agentPage = 'error'; });
        }, 2000);
    }

    disconnectedCallback() {
        if (this._openHandler) window.removeEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
        if (this._contextPoll) clearInterval(this._contextPoll);
    }

    @wire(CurrentPageReference)
    handlePageChange(pageRef) {
        if (!pageRef) return;
        const type = pageRef.type || '';
        const name = pageRef.attributes?.name || pageRef.attributes?.apiName || '';
        this.rawPageRef = `${type}|${name}`;
        const pageName = resolvePage(pageRef);
        const videoId = getVideoId(pageRef);
        this.currentPage = pageName;
        this._lastVideoId = videoId;
        updateContactPage({ pageName, sessionKey: this._conversationId, videoId }).catch(() => {});
    }
}

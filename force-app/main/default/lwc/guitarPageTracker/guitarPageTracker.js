import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import updateContactPage from '@salesforce/apex/GuitarVideoController.updateContactPage';
import linkSessionContact from '@salesforce/apex/GuitarVideoController.linkSessionContact';

const CONV_KEY = 'ga_conversationId';
const LINKED_KEY = 'ga_meu_linked';

function resolvePage(pageRef) {
    if (getVideoIdFromUrl()) return 'video';
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
    const urlVideoId = getVideoIdFromUrl();
    if (urlVideoId) return urlVideoId;
    const type = pageRef.type || '';
    const attrs = pageRef.attributes || {};
    if (type === 'standard__recordPage' && attrs.objectApiName === 'Guitar_Video__c') {
        return attrs.recordId || null;
    }
    return null;
}

function getVideoIdFromUrl() {
    const match = window.location.pathname.match(/\/guitar-video\/([^/?#]+)/i);
    return match ? decodeURIComponent(match[1]) : null;
}

export default class GuitarPageTracker extends LightningElement {
    _lastPage = null;
    _conversationId = null;
    _openHandler = null;
    _messageHandler = null;

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

        // On the student's FIRST message (sender role EndUser), link the MessagingEndUser to their
        // Contact — once per conversation. Only links engaged conversations (not abandoned opens).
        this._messageHandler = (event) => {
            const role = event.detail?.conversationEntry?.sender?.role || event.detail?.sender?.role;
            if (role !== 'EndUser') return;
            if (!this._conversationId) return;
            if (localStorage.getItem(LINKED_KEY) === this._conversationId) return;
            linkSessionContact({ conversationId: this._conversationId })
                .then(() => localStorage.setItem(LINKED_KEY, this._conversationId))
                .catch(() => {});
        };
        window.addEventListener('onEmbeddedMessageSent', this._messageHandler);
    }

    disconnectedCallback() {
        if (this._openHandler) window.removeEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
        if (this._messageHandler) window.removeEventListener('onEmbeddedMessageSent', this._messageHandler);
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

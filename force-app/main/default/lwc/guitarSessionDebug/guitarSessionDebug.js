import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import isGuest from '@salesforce/user/isGuest';
import isDebugEnabled from '@salesforce/apex/GuitarSessionDebugController.isDebugEnabled';
import updateContactPage from '@salesforce/apex/GuitarVideoController.updateContactPage';
import getDebugSnapshot from '@salesforce/apex/GuitarSessionDebugController.getDebugSnapshot';

const CONV_KEY = 'ga_conversationId';

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

export default class GuitarSessionDebug extends LightningElement {
    currentPage = '—';
    rawPageRef = '—';
    conversationId = '(none)';
    sessionId = '(unresolved)';
    found = 'false';
    agentPage = '…';
    agentVideo = '';
    action = '';
    endUserName = '';
    contactId = '';
    filterGuard = '—';
    purchaseGuard = '—';
    resolveLatency = '—';
    log = [];

    _conversationId = null;
    _lastVideoId = null;
    _openedAt = null;
    _resolvedAt = null;
    _openHandler = null;
    _msgHandler = null;
    _poll = null;

    debugOn = false;

    get logLines() {
        return this.log.map((text, i) => ({ id: i, text }));
    }
    get filterClass() {
        return this.filterGuard === 'OPEN' ? 'guard guard-open' : 'guard guard-closed';
    }
    get purchaseClass() {
        return this.purchaseGuard === 'OPEN' ? 'guard guard-open' : 'guard guard-closed';
    }

    _pushLog(msg) {
        const ts = new Date().toLocaleTimeString();
        this.log = [`${ts}  ${msg}`, ...this.log].slice(0, 12);
    }

    connectedCallback() {
        if (isGuest) return; // debug tooling is for logged-in users only
        // Gate behind the Debug_Config__c custom setting — off by default, no deploy to toggle.
        isDebugEnabled()
            .then((enabled) => {
                if (!enabled) return;
                this.debugOn = true;
                this._init();
            })
            .catch(() => {});
    }

    _init() {
        this._conversationId = localStorage.getItem(CONV_KEY) || null;
        this.conversationId = this._conversationId ? this._conversationId.slice(0, 12) + '…' : '(none)';

        this._openHandler = (event) => {
            this._conversationId = event.detail?.conversationId || null;
            this._openedAt = Date.now();
            this._resolvedAt = null;
            this.resolveLatency = 'measuring…';
            if (this._conversationId) localStorage.setItem(CONV_KEY, this._conversationId);
            this.conversationId = this._conversationId ? this._conversationId.slice(0, 12) + '…' : '(none)';
            this._pushLog('conversationOpened ' + (this._conversationId ? this._conversationId.slice(0, 8) : 'null'));
            if (this.currentPage !== '—') {
                updateContactPage({ pageName: this.currentPage, sessionKey: this._conversationId, videoId: this._lastVideoId || null })
                    .then(() => this._pushLog('wrote page=' + this.currentPage + ' (on open)'))
                    .catch((e) => this._pushLog('write ERR ' + (e?.body?.message || e)));
            }
        };
        window.addEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);

        this._msgHandler = (event) => {
            const sender = event.detail?.conversationEntry?.sender || event.detail?.sender || '?';
            this._pushLog('messageSent sender=' + JSON.stringify(sender));
            this._refresh();
        };
        window.addEventListener('onEmbeddedMessageSent', this._msgHandler);

        this._poll = setInterval(() => this._refresh(), 2000);
        this._refresh();
    }

    _refresh() {
        getDebugSnapshot({ conversationId: this._conversationId })
            .then((snap) => {
                this.found = snap.found || 'false';
                this.sessionId = snap.sessionId ? snap.sessionId.slice(0, 15) + '…' : '(unresolved)';
                this.agentPage = snap.currentPage || '(blank)';
                this.agentVideo = snap.currentVideoId || '';
                this.action = snap.action || '';
                this.endUserName = snap.endUserName || '';
                this.contactId = snap.contactId || '(null)';
                this.filterGuard = snap.filterGuard || '—';
                this.purchaseGuard = snap.purchaseGuard || '—';
                if (snap.found === 'true' && !this._resolvedAt && this._openedAt) {
                    this._resolvedAt = Date.now();
                    this.resolveLatency = (this._resolvedAt - this._openedAt) + 'ms';
                    this._pushLog('session resolved in ' + this.resolveLatency);
                }
            })
            .catch((e) => {
                this.found = 'error';
                this._pushLog('snapshot ERR ' + (e?.body?.message || e));
            });
    }

    disconnectedCallback() {
        if (this._openHandler) window.removeEventListener('onEmbeddedMessagingConversationOpened', this._openHandler);
        if (this._msgHandler) window.removeEventListener('onEmbeddedMessageSent', this._msgHandler);
        if (this._poll) clearInterval(this._poll);
    }

    @wire(CurrentPageReference)
    handlePageChange(pageRef) {
        if (isGuest || !this.debugOn || !pageRef) return;
        const type = pageRef.type || '';
        const name = pageRef.attributes?.name || pageRef.attributes?.apiName || '';
        this.rawPageRef = `${type}|${name}`;
        const pageName = resolvePage(pageRef);
        const videoId = getVideoId(pageRef);
        this.currentPage = pageName;
        this._lastVideoId = videoId;
        updateContactPage({ pageName, sessionKey: this._conversationId, videoId })
            .then(() => this._pushLog('wrote page=' + pageName + (videoId ? ' video=' + videoId.slice(0, 6) : '')))
            .catch((e) => this._pushLog('write ERR ' + (e?.body?.message || e)));
    }
}

import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import updateSessionPage from '@salesforce/apex/GuitarVideoController.updateSessionPage';

const PAGE_MAP = {
    'guitar_academy__home':    'home',
    'guitar_academy__catalog': 'catalog',
    'guitar_academy__video':   'video'
};

export default class GuitarSessionDebug extends LightningElement {
    currentPage = '—';
    shortSessionId = '—';

    @wire(CurrentPageReference)
    handlePageChange(pageRef) {
        if (!pageRef) return;

        const sessionId = this._getSessionId();
        this.shortSessionId = sessionId ? '...' + sessionId.slice(-6) : 'no session';

        const apiName = pageRef.attributes?.apiName || pageRef.type || '';
        const pageName = PAGE_MAP[apiName] || apiName || 'unknown';
        this.currentPage = pageName;

        if (sessionId) {
            updateSessionPage({ sessionId, pageName }).catch(() => {});
        }
    }

    _getSessionId() {
        try {
            return window.embeddedservice_bootstrap?.sessionId ?? null;
        } catch (e) {
            return null;
        }
    }
}

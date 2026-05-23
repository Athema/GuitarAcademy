import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { subscribe, publish, MessageContext } from 'lightning/messageService';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import hasVideoAccess from '@salesforce/apex/GuitarVideoController.hasVideoAccess';
import purchaseVideo from '@salesforce/apex/GuitarVideoController.purchaseVideo';
import createSubscription from '@salesforce/apex/GuitarVideoController.createSubscription';
import GUITAR_ACADEMY_ACCESS from '@salesforce/messageChannel/GuitarAcademyAccess__c';
import DIRECT_PURCHASE_ENABLED from '@salesforce/label/c.Direct_Purchase_Enabled';

import NAME_FIELD        from '@salesforce/schema/Guitar_Video__c.Name';
import YOUTUBE_ID_FIELD  from '@salesforce/schema/Guitar_Video__c.YouTube_ID__c';
import LEVEL_FIELD       from '@salesforce/schema/Guitar_Video__c.Level__c';
import CATEGORY_FIELD    from '@salesforce/schema/Guitar_Video__c.Category__c';
import PRICE_FIELD       from '@salesforce/schema/Guitar_Video__c.Price__c';
import DURATION_FIELD    from '@salesforce/schema/Guitar_Video__c.Duration_Minutes__c';
import DESCRIPTION_FIELD from '@salesforce/schema/Guitar_Video__c.Description__c';
import THUMBNAIL_FIELD   from '@salesforce/schema/Guitar_Video__c.Thumbnail_URL__c';

const FIELDS = [NAME_FIELD, YOUTUBE_ID_FIELD, LEVEL_FIELD, CATEGORY_FIELD, PRICE_FIELD, DURATION_FIELD, DESCRIPTION_FIELD, THUMBNAIL_FIELD];
const PREVIEW_SECONDS = 20;
const OVERLAY_DELAY_MS = (PREVIEW_SECONDS + 2) * 1000;

export default class GuitarVideoPlayer extends NavigationMixin(LightningElement) {
    @api recordId;
    @track hasAccess = false;
    @track isPlaying = false;
    @track showOverlay = false;
    @track showAccessPanel = false;
    @track isBusy = false;
    @track actionSuccess = '';

    _previewTimer;
    _accessChecked = false;

    @wire(MessageContext) messageContext;

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (pageRef?.attributes?.recordId) {
            this.recordId = pageRef.attributes.recordId;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    record;

    get video() {
        if (!this.record?.data) return null;
        const g = f => getFieldValue(this.record.data, f);
        return {
            Name:                g(NAME_FIELD),
            YouTube_ID__c:       g(YOUTUBE_ID_FIELD),
            Level__c:            g(LEVEL_FIELD),
            Category__c:         g(CATEGORY_FIELD),
            Price__c:            g(PRICE_FIELD),
            Duration_Minutes__c: g(DURATION_FIELD),
            Description__c:      g(DESCRIPTION_FIELD),
            Thumbnail_URL__c:    g(THUMBNAIL_FIELD)
        };
    }

    get levelClass() {
        const level = (this.video?.Level__c || '').toLowerCase();
        return `level-badge level-${level}`;
    }

    get iframeSrc() {
        const ytId = this.video?.YouTube_ID__c;
        if (!ytId) return '';
        const base = `https://www.youtube.com/embed/${ytId}?rel=0&modestbranding=1&autoplay=1`;
        return this.hasAccess ? base : `${base}&end=${PREVIEW_SECONDS}`;
    }

    get playBtnLabel() {
        return this.hasAccess ? 'Play Full Lesson' : 'Preview (20s)';
    }

    get playBtnClass() {
        return this.hasAccess ? 'play-btn play-btn--full' : 'play-btn play-btn--preview';
    }

    get isDirectPurchaseEnabled() {
        return DIRECT_PURCHASE_ENABLED === 'true';
    }

    get showGetAccessButton() {
        return !this.hasAccess && !!this.video && this.isDirectPurchaseEnabled;
    }

    get accessPanelIcon() {
        return this.showAccessPanel ? '▲' : '▼';
    }

    get purchaseBtnLabel() {
        if (this.actionSuccess === 'purchase') return '✓ Purchased!';
        return this.isBusy ? 'Processing...' : `Buy once — $${this.video?.Price__c}`;
    }

    get monthlyBtnLabel() {
        if (this.actionSuccess === 'subscribe') return '✓ Subscribed!';
        return this.isBusy ? 'Processing...' : 'Monthly — $9.99/mo';
    }

    get annualBtnLabel() {
        if (this.actionSuccess === 'subscribe') return '✓ Subscribed!';
        return this.isBusy ? 'Processing...' : 'Annual — $79.99/yr (save 33%)';
    }

    connectedCallback() {
        subscribe(this.messageContext, GUITAR_ACADEMY_ACCESS, msg => {
            if (!msg.videoId || msg.videoId === this.recordId) {
                this.hasAccess = true;
                this.showOverlay = false;
                this.showAccessPanel = false;
                this._clearPreviewTimer();
                if (this.isPlaying) this._reloadIframe();
            }
        });
    }

    renderedCallback() {
        if (this.recordId && !this._accessChecked) {
            this._accessChecked = true;
            hasVideoAccess({ videoId: this.recordId })
                .then(result => { this.hasAccess = result; })
                .catch(() => {});
        }
    }

    disconnectedCallback() {
        this._clearPreviewTimer();
    }

    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/catalog' }
        });
    }

    handlePlay() {
        this.showOverlay = false;
        this.isPlaying = true;
        this._clearPreviewTimer();
        if (!this.hasAccess) this._startPreviewTimer();
    }

    handleReplay() {
        this.showOverlay = false;
        this._clearPreviewTimer();
        this._reloadIframe();
        this._startPreviewTimer();
    }

    handleToggleAccessPanel() {
        this.showAccessPanel = !this.showAccessPanel;
    }

    handlePurchaseVideo() {
        if (this.isBusy) return;
        this.isBusy = true;
        purchaseVideo({ videoId: this.recordId })
            .then(() => {
                this.actionSuccess = 'purchase';
                this._grantAccess();
            })
            .catch(err => {
                console.error('Purchase failed', err);
            })
            .finally(() => { this.isBusy = false; });
    }

    handleSubscribeMonthly() {
        this._subscribe('Monthly');
    }

    handleSubscribeAnnual() {
        this._subscribe('Annual');
    }

    _subscribe(plan) {
        if (this.isBusy) return;
        this.isBusy = true;
        createSubscription({ plan })
            .then(() => {
                this.actionSuccess = 'subscribe';
                this._grantAccess();
            })
            .catch(err => {
                console.error('Subscription failed', err);
            })
            .finally(() => { this.isBusy = false; });
    }

    _grantAccess() {
        this.hasAccess = true;
        this.showOverlay = false;
        this.showAccessPanel = false;
        this._clearPreviewTimer();
        publish(this.messageContext, GUITAR_ACADEMY_ACCESS, { videoId: this.recordId });
        if (this.isPlaying) this._reloadIframe();
    }

    _startPreviewTimer() {
        this._previewTimer = setTimeout(() => {
            this.showOverlay = true;
            const iframe = this.template.querySelector('.yt-frame');
            if (iframe) iframe.src = '';
        }, OVERLAY_DELAY_MS);
    }

    _clearPreviewTimer() {
        if (this._previewTimer) {
            clearTimeout(this._previewTimer);
            this._previewTimer = null;
        }
    }

    _reloadIframe() {
        const iframe = this.template.querySelector('.yt-frame');
        if (!iframe) return;
        const src = this.iframeSrc;
        iframe.src = '';
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { iframe.src = src; }, 50);
    }
}

import { LightningElement, track } from 'lwc';
import resetDemo from '@salesforce/apex/GuitarVideoController.resetDemo';
import basePath from '@salesforce/community/basePath';

export default class GuitarDemoReset extends LightningElement {
    @track state = 'idle'; // idle | confirm | busy | done

    _confirmTimer;

    get btnLabel() {
        const labels = { idle: 'Reset Demo', confirm: 'Confirm?', busy: 'Resetting...', done: '✓ Done' };
        return labels[this.state];
    }

    get btnClass() {
        return `reset-btn reset-btn--${this.state}`;
    }

    handleClick() {
        if (this.state === 'busy' || this.state === 'done') return;

        if (this.state === 'idle') {
            this.state = 'confirm';
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._confirmTimer = setTimeout(() => { this.state = 'idle'; }, 3000);
            return;
        }

        clearTimeout(this._confirmTimer);
        this.state = 'busy';
        resetDemo()
            .then(() => {
                this.state = 'done';
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { window.location.assign(basePath); }, 1500);
            })
            .catch(() => { this.state = 'idle'; });
    }

    disconnectedCallback() {
        clearTimeout(this._confirmTimer);
    }
}

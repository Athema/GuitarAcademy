import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class GuitarVideoCard extends NavigationMixin(LightningElement) {
    @api video;
    @api isOwned = false;

    get levelClass() {
        const level = (this.video?.Level__c || '').toLowerCase();
        return `level-badge level-${level}`;
    }

    handleClick() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/guitar-video/${this.video.Id}` }
        });
    }

    handleImgError(event) {
        event.target.src = 'https://via.placeholder.com/320x180?text=Guitar+Lesson';
    }
}

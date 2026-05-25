import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import updateContactPage from '@salesforce/apex/GuitarVideoController.updateContactPage';

export default class GuitarVideoCard extends NavigationMixin(LightningElement) {
    @api video;
    @api isOwned = false;

    get levelClass() {
        const level = (this.video?.Level__c || '').toLowerCase();
        return `level-badge level-${level}`;
    }

    handleClick() {
        const videoId = this.video?.Id;
        const goToVideo = () => {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: `/guitar-video/${videoId}` }
            });
        };
        if (!videoId) return;
        updateContactPage({
            pageName: 'video',
            sessionKey: localStorage.getItem('ga_conversationId') || null,
            videoId
        })
            .catch(() => {})
            .finally(goToVideo);
    }

    handleImgError(event) {
        event.target.src = 'https://via.placeholder.com/320x180?text=Guitar+Lesson';
    }
}

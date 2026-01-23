import {getDateString, getTimeString, stripHTMLFromText} from 'c/utils';
import ID_FIELD from '@salesforce/schema/FeedItem.Id';
import CREATEDDATE_FIELD from '@salesforce/schema/FeedItem.CreatedDate';
import CREATEDBYID_FIELD from '@salesforce/schema/FeedItem.CreatedById';
import BODY_FIELD from '@salesforce/schema/FeedItem.Body';
import VISIBILITY_FIELD from '@salesforce/schema/FeedItem.Visibility';
import COMMENTBODY_FIELD from '@salesforce/schema/FeedComment.CommentBody';
import FEEDITEMID_FIELD from '@salesforce/schema/FeedComment.FeedItemId';


const SHORTBODY_LENGTH = 75;
const RESP_SHORTBODY_LENGTH = 40;

class CaseComment {
   
    get formattedCreatedDateTimeString() {
        const dateObj = new Date(this[CREATEDDATE_FIELD.fieldApiName]);
        const dateString = getDateString(dateObj);
        const timeString = getTimeString(dateObj);
        return `${dateString} ${timeString}`;
    }
    // readonly, to be used in responsive layouts. 
    get combinedAuthorAndShortBody() {
        const authorSnippet = `${this.createdByName}, `;
        // Shorten the shortBody with the same amount of chars as in autor snippet.
        const shortBody = this.shortBody.slice(0, (RESP_SHORTBODY_LENGTH - authorSnippet.length));
        const label = authorSnippet + shortBody;
        return label.length>= RESP_SHORTBODY_LENGTH ? `${label.trim()}...` : label;
    }

    constructor(obj = {}) {
        this[ID_FIELD.fieldApiName] = obj[ID_FIELD.fieldApiName];
        this[CREATEDDATE_FIELD.fieldApiName] = obj[CREATEDDATE_FIELD.fieldApiName];
        this[CREATEDBYID_FIELD.fieldApiName] = obj[CREATEDBYID_FIELD.fieldApiName];
        this.createdByName = obj.CreatedBy ? `${obj.CreatedBy.FirstName} ${obj.CreatedBy.LastName}`: undefined;
        this[VISIBILITY_FIELD.fieldApiName] = obj[VISIBILITY_FIELD.fieldApiName];
        this[BODY_FIELD.fieldApiName] = obj[BODY_FIELD.fieldApiName]? obj[BODY_FIELD.fieldApiName] : obj[COMMENTBODY_FIELD.fieldApiName];
        // Fix short body text
        if(this[BODY_FIELD.fieldApiName] && this[BODY_FIELD.fieldApiName].length > SHORTBODY_LENGTH){
            
            this.shortBody = stripHTMLFromText(this[BODY_FIELD.fieldApiName]).slice(0,SHORTBODY_LENGTH) + '...';
        } else {
            this.shortBody = stripHTMLFromText(this[BODY_FIELD.fieldApiName]);
        }
    }
}

export { CaseComment }
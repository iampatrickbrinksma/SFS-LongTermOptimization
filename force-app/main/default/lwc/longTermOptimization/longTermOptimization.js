import { LightningElement } from 'lwc';

// Alerts and confirms
import LightningAlert from "lightning/alert";
import LightningConfirm from 'lightning/confirm';

import startOptimize from '@salesforce/apex/optimizationRequestUtil.startLongTermRequest';

export default class LongTermOptimization extends LightningElement {

    // Input fields on the forms
    fieldValues = {
        serviceTerritoryId: null,
        schedulingPolicyId: null,
        start: this.getTheDate( new Date(), 0 ),
        finish: this.getTheDate( new Date(), 21 ),
        optimizationHorizon: 21,
        overlapInDays: 3,
        booleanFieldApiName: null,
    }

    showSpinner = false;    

    getTheDate(thisDate, daysToAdd){
        thisDate.setDate( thisDate.getDate() + Number( daysToAdd ) );
        return `${ thisDate.getFullYear() }-${ ( "0" + ( thisDate.getMonth() + 1 ) ).slice( -2 ) }-${ ( "0" + thisDate.getDate() ).slice( -2 ) }`;
    }

    // Handle Inputfield changes for input fields
    handle_InputFieldChange(event){
        this.fieldValues[event.target.name] = event.detail.value;
    }    

    handle_Optimize(){
        if ( this.fieldValues.serviceTerritoryId === undefined || this.fieldValues.serviceTerritoryId === null ||
            this.fieldValues.schedulingPolicyId === undefined || this.fieldValues.schedulingPolicyId === null ) 
        {
            this.handle_Alert( 'Please provide all required information!' );
            return;
        }
        let start = new Date( Date.parse( this.fieldValues.start ) );
        let today = new Date();
        let startOfToday = new Date( today.getFullYear(), today.getMonth(), today.getDate() );
        if ( start < startOfToday ) {
            this.handle_Alert( 'Start Date must be today or in the future!');
            return;
        }
        this.fieldValues.finish = this.getTheDate( start, this.fieldValues.optimizationHorizon );
        LightningConfirm.open({
            message: 'Are you sure you want to start a long term optimization?',
            variant: 'header',
            label: 'Please confirm',
            theme: 'error',
        })
        .then(result => {
            if (result === true) {
                this.showSpinner = true;
                console.log(`
                    stId: ${this.fieldValues.serviceTerritoryId[0]}
                    spId: ${this.fieldValues.schedulingPolicyId[0]}
                    start: ${this.fieldValues.start}
                    finish: ${this.fieldValues.finish}
                    daysPerSubRequest: ${this.fieldValues.optimizationHorizon}
                    overlapInDays: ${this.fieldValues.overlapInDays}
                    filterFieldApiName: ${this.fieldValues.booleanFieldApiName}
                `);
                startOptimize({
                    stId: this.fieldValues.serviceTerritoryId[0],
                    spId: this.fieldValues.schedulingPolicyId[0],
                    start: this.fieldValues.start,
                    finish: this.fieldValues.finish,
                    daysPerSubRequest: this.fieldValues.optimizationHorizon,
                    overlapInDays: this.fieldValues.overlapInDays,
                    filterFieldApiName: (this.fieldValues.booleanFieldApiName === '' || this.fieldValues.booleanFieldApiName === undefined || this.fieldValues.booleanFieldApiName === null ? null : this.fieldValues.booleanFieldApiName)
                })
                .then(result => {
                    this.handle_Alert(
                        'Long term optimization started with Optimization Request with Id ' + result
                    );
                    this.showSpinner = false;
                })
                .catch((error) => {
                    console.error(error);
                    this.handle_Alert(JSON.stringify(error));
                    this.showSpinner = false;
                });                  
            }
        })
        .catch((error) => {
            console.error(error);
            this.handle_Alert(JSON.stringify(error));
            this.showSpinner = false;
        });
    }

    // Show alert message for errors
    async handle_Alert(msg) {
        await LightningAlert.open({
            message: msg,
            theme: "error",
            label: "Alert"
        })
        .then(() => {
            // alert closed
        });
    }  

}
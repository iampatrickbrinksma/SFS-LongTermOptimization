/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Apex Trigger for Optimization Request SObject
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <pbrinksma@salesforce.com>
* @version        1.0
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @changes
* v1.0            Patrick Brinksma   <pbrinksma@salesforce.com>
* 2023-03-28      Initial version
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
trigger OptimizationRequestTrigger on FSL__Optimization_Request__c (after update) {

    // Only when 1 record is being updated
    if ( Trigger.new.size() == 1 ) {
        // When the optimization request status is a chained one
        // and status is updated to Completed, enqueue the job
        // to start the next optimization request
        FSL__Optimization_Request__c optReq = Trigger.new[0];
        if (optReq.Is_Long_Term_Optimization_Request__c && 
            optReq.FSL__Status__c == 'Completed' &&
            Trigger.oldMap.get(optReq.Id).FSL__Status__c != 'Completed'
        ) {
            optimizationRequestUtil q = new optimizationRequestUtil(optReq.Id);
            System.enqueueJob(q);
        }
    }

}
/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class for chaining optimization requests in Salesforce Field Service
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <pbrinksma@salesforce.com>
* @version        1.0
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @changes
* v1.0            Patrick Brinksma   <pbrinksma@salesforce.com>
* 2023-03-28      Initial version
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class optimizationRequestUtil implements Queueable, Database.AllowsCallouts {

    // Reference to the optimization request
    private Id parentOptReqId;

    // Constructor
    public optimizationRequestUtil(Id parentOptReqId){
        this.parentOptReqId = parentOptReqId;
    }

    // This class is a Queueable to make sure we are able to chain
    // optimizations. Trying this in synchronous context or future
    // will result in exceptions, and should not be used
    public void execute(QueueableContext context){
        optimizationRequestUtil.startSubRequest(parentOptReqId);
    }    

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Start a long term request to start the chaining
    * ────────────────────────────────────────────────────────────────────────────────────────────────  
    * @param    stId                Service Territory Id
    * @param    spId                Scheduling Policy Id
    * @param    start               Start of the long term optimization request
    * @param    finish              End of the long term optimization request
    * @param    daysPerSubRequest   Number of days to optimize per request
    * @param    overlapInDays       Number of days to overlap the prev with the next request
    * @param    filterFieldApiName  Filter by this Boolean field (API name)
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */
    @AuraEnabled(cacheable = false)
    public static Id startLongTermRequest(
                                            Id stId, 
                                            Id spId, 
                                            Date start, 
                                            Date finish, 
                                            Integer daysPerSubRequest, 
                                            Integer overlapInDays, 
                                            String filterFieldApiName){

        // Make sure the time of the start and finish datetimes are at midnight
        Time midnightTime = Time.newInstance(0, 0, 0, 0);
        Datetime startDT = Datetime.newInstance(start, midnightTime);
        Datetime finishDT = Datetime.newInstance(finish, midnightTime);

        if ( startDT.addDays(daysPerSubRequest) > finishDT ) {
            throw new LongTermOptimizationException('Please provide valid start and finish dates!');
        }

        // Create the Optimization Request 
        Id optReqId = createOptimizationRequest(
            new List<Id>{stId}, 
            spId, 
            startDT, 
            startDT.addDays(daysPerSubRequest), 
            filterFieldApiName
        );

        // Update the Optimization Request record
        // with additional information about the chaining
        updateOptimizationRequest(
            optReqId, 
            [select Name from FSL__Optimization_Request__c where Id = :optReqId].Name, 
            null, 
            startDT, 
            finishDT, 
            daysPerSubRequest,
            overlapInDays,
            filterFieldApiName
        );

        return optReqId;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Start the next optimization request based on the previous  one
    * ────────────────────────────────────────────────────────────────────────────────────────────────  
    * @param    parentOptReqId      Id of the previous optimization request
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */
    public static void startSubRequest(Id parentOptReqId){

        // Retrieve the previous optimization request
        // which just completed. No chaining when the previous
        // optimization request has failed
        FSL__Optimization_Request__c parentOptReq = [
            select 
                Id, 
                FSL__Scheduling_Policy__c,
                FSL__Finish__c,
                FSL__Filter_By_Boolean__c,
                Is_Long_Term_Optimization_Request__c, 
                Long_Term_Request_Start__c,
                Long_Term_Request_Finish__c,
                FSL__Objects_To_Schedule__c,
                Sub_Request_Horizon_In_Days__c,
                Sub_Request_Overlap_In_Days__c,
                Originating_Optimization_Request__c,
                Filter_By_Boolean_API_Name__c
            from 
                FSL__Optimization_Request__c 
            where 
                Id = :parentOptReqId
        ];

        // Validate if we have actually reached the end of the total timeframe
        // Or if there are no SAs to schedule anymore
        if (parentOptReq.FSL__Objects_To_Schedule__c == 0 || 
            parentOptReq.FSL__Finish__c >= parentOptReq.Long_Term_Request_Finish__c){
            return;
        }

        // Set the new start and finish for the subsequent optimization process
        // If the overlap option is used, distract the number of days from the start
        // If the calculated finish is past the overal time period, set the finish to that datetime
        Datetime start =  parentOptReq.FSL__Finish__c.addDays(-Integer.valueOf(parentOptReq.Sub_Request_Overlap_In_Days__c));
        Datetime finish = start.addDays(Integer.valueOf(parentOptReq.Sub_Request_Horizon_In_Days__c));
        if (finish > parentOptReq.Long_Term_Request_Finish__c) {
            finish = parentOptReq.Long_Term_Request_Finish__c;
        }

        // Create the Optimization Request 
        Id nextOptReqId = createOptimizationRequest(
            getRequestTerritories(parentOptReqId), 
            parentOptReq.FSL__Scheduling_Policy__c, 
            start,
            finish, 
            parentOptReq.Filter_By_Boolean_API_Name__c
        );

        // Update the Optimization Request record
        // with additional information about the chaining        
        updateOptimizationRequest(
            nextOptReqId, 
            parentOptReq.Originating_Optimization_Request__c,
            parentOptReqId, 
            parentOptReq.Long_Term_Request_Start__c, 
            parentOptReq.Long_Term_Request_Finish__c,
            Integer.valueOf(parentOptReq.Sub_Request_Horizon_In_Days__c),
            Integer.valueOf(parentOptReq.Sub_Request_Overlap_In_Days__c),
            parentOptReq.Filter_By_Boolean_API_Name__c
        );

    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Start optimization process using the FSL Namespace method which 
    * returns the Id of the Optimization Request
    * ───────────────────────────────────────────────────────────────────────────────────────────────
    * @param    stIds               List of Service Territory Ids to include in the optimization
    * @param    spId                Id of the Scheduling Policy
    * @param    start               Datetime of the start of the period to optimize
    * @param    finish              Datetime of the end of the period to optimize
    * @param    filterFieldApiName  Filter by this Boolean field (API name)
    * ───────────────────────────────────────────────────────────────────────────────────────────────
    * @return   Id                  Id of the created optimization request
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    private static Id createOptimizationRequest(
                                                List<Id> stIds, 
                                                Id spId, 
                                                Datetime start, 
                                                Datetime finish, 
                                                String filterFieldApiName){

        FSL.OAASRequest oaasRequest = new FSL.OAASRequest();
        oaasRequest.allTasksMode = true;
        oaasRequest.filterFieldAPIName = filterFieldApiName;
        oaasRequest.start = start;
        oaasRequest.finish = finish;
        oaasRequest.includeServicesWithEmptyLocation = false;
        oaasRequest.locations = stIds;
        oaasRequest.schedulingPolicyID = spId;

        FSL.OAAS oaas = new FSL.OAAS();
        Id optReqId = oaas.optimize(oaasRequest);         
        return optReqId;
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Update an Optimization Request with additional information
    * ───────────────────────────────────────────────────────────────────────────────────────────────
    * @param    optReqId            Id of the optimization request
    * @param    rootOptReqName      Name of the first optimization request
    * @param    parentOptReqId      Id of the parent optimization request
    * @param    start               Datetime of the start of the period to optimize
    * @param    finish              Datetime of the end of the period to optimize
    * @param    daysPerSubRequest   Number of days to optimize per request
    * @param    overlapInDays       Number of days to overlap the prev with the next request
    * @param    filterFieldApiName  Filter by this Boolean field (API name)
    * ───────────────────────────────────────────────────────────────────────────────────────────────
    * @return   Id                  Id of the created optimization request
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */    
    private static void updateOptimizationRequest(
                                                Id optReqId, 
                                                String rootOptReqName, 
                                                Id parentOptReqId, 
                                                Datetime start, 
                                                Datetime finish, 
                                                Integer daysPerSubRequest, 
                                                Integer overlapInDays,
                                                String filterFieldApiName){
        FSL__Optimization_Request__c rootOptReq = new FSL__Optimization_Request__c(
            Id = optReqId,
            Is_Long_Term_Optimization_Request__c = true,
            Parent_Optimization_Request__c = parentOptReqId,
            Long_Term_Request_Start__c = start,
            Long_Term_Request_Finish__c = finish,
            Sub_Request_Horizon_In_Days__c = daysPerSubRequest,
            Sub_Request_Overlap_In_Days__c = overlapInDays,
            Originating_Optimization_Request__c = rootOptReqName,
            Filter_By_Boolean_API_Name__c = filterFieldApiName
        );
        update rootOptReq;        
    }

    /**
    * ───────────────────────────────────────────────────────────────────────────────────────────────┐
    * Retrieve the territories which are part of the optimization request
    * ───────────────────────────────────────────────────────────────────────────────────────────────
    * @param    parentOptReqId      Id of the parent optimization request
    * ───────────────────────────────────────────────────────────────────────────────────────────────
    * @return   List<Id>            List of Service Territory Ids
    * ───────────────────────────────────────────────────────────────────────────────────────────────┘
    */     
    private static List<Id> getRequestTerritories(Id optReqId){
        List<FSL__Territory_Optimization_Request__c> territories = [
            select 
                Id,
                FSL__ServiceTerritory__c
            from 
                FSL__Territory_Optimization_Request__c
            where 
                FSL__Optimization_Request__c = :optReqId
        ];

        List<Id> stIds = new List<Id>();
        for (FSL__Territory_Optimization_Request__c territory : territories){
            stIds.add(territory.FSL__ServiceTerritory__c);
        }

        return stIds;
    }

    public class LongTermOptimizationException extends Exception {}

}
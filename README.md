# Long Term Optimization for Salesforce Field Service

This project is an example how to run Salesforce Field Service Optimization for a longer period than the 21 days that is supported out of the box. It chains Optimization Requests enabling a longer period to be optimized. The result can of course be different compared to running optimization in a single request for a long period, but that's not possible today. 

## Disclaimer
This repository contains code intended to help Salesforce Field Service customers and partners accelerate their implementations. Please note the following:
* This code is not an official Salesforce product.
* It is not officially supported by Salesforce.
* The code serves as an example of how to implement specific functionality or make use of certain features.

Before using this code in a production environment, it is crucial that you:
* Adopt the code to fit your specific needs.
* Test thoroughly to ensure it works as expected in your environment.
* Consider the code to be your own and take full responsibility for its use.

By using this code, you acknowledge that Salesforce is not liable for any issues that may arise from its use.

# How To Use

Deploy the metadata to your org and assign the "Field Service Long Term Optimization" permission set to your user, and optionally add the following fields to the Optimization Request Page Layout:

| Field                            | Description                                                       |
|----------------------------------|-------------------------------------------------------------------|
| Filter By Boolean API Name       | API field name of the boolean field on service appointment        |
| Long Term Request Finish         | End date of the long term optimization request                    |
| Long Term Request Start          | Start date of the long term optimization request                  |
| Originating Optimization Request | Optimization request name value of the first request in the chain |
| Parent Finish                    | Reference to the parent finish field                              |
| Parent Optimization Request      | Previous optimization request                                     |
| Parent Start                     | Reference to the parent start field                               |
| Sub Request Horizon In Days      | Optimization horizon per request                                  |
| Sub Request Overlap In Days      | Overlap in days per subsequent request                            |

Assign the "Field Service Dispatcher Permissions" permission set to the Field Service Optimization user to provide the required permissions to create an optimization request. Furthermore, make sure this user has at least read access to all service territories.

Navigate to the Long Term Optimization tab via the App Launcher. On the left you will see the list with Optimization Requests and on the right the component to start a long term optimization request. Select a service territory (for now only one service territory is supported), a start date, end date and how many days to optimize per request. The overlap between optimization requests defines when the next optimization request starts. Optionally, provide the API name of the Boolean field on the Service Appointment object which is used to determine which appointments are eligible for optimization. Hit the Optimize button to start the process. 
A new Optimization Request is created using the FSL.OAAS.optimize method, and once that finishes, the next request is started until the entire period has been covered, or if there are no appointment available for optimization. When an optimization request does not complete, the chaining stops.

# Components

| Component                            | Type                    | Description                                                                                                    |
|--------------------------------------|-------------------------|----------------------------------------------------------------------------------------------------------------|
| optimizationRequestUtil              | Apex Class              | Implements Queueable to chain a new optimization request from the trigger. Contains AuraEnabled method for LWC |
| Long_Term_Optimization               | FlexiPage               | Lightning Page with the Optimization Request list view and the LWC                                             |
| longTermOptimization                 | Lightning Web Component | LWC to create a long term optimization request                                                                 |
| Long_Optimization_Requests           | List View               | Optimization Request list view                                                                                 |
| <Fields listed in the table above>   | Custom Field            | Custom fields on the Optimization Request object                                                               |
| Field_Service_Long_Term_Optimization | Permission Set          | Permission set including the required permissions                                                              |
| Long_Term_Optimization               | Custom Tab              | Tab for the Lightning Page                                                                                     |
| OptimizationRequestTrigger           | Apex Trigger            | Trigger to start the next optimization request                                                                 |

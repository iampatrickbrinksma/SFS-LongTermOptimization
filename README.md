# Long Term Optimization for Salesforce Field Service

This project is an example how to run Salesforce Field Service Optimization for a longer period than the 21 days that is supported out of the box. It chains Optimization Requests enabling a longer period to be optimized. 

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
| Sub Request Overlap In Days      | Overlap in days per subsequent request                           

Navigate to the Long Term Optimization tab via the App Launcher. On the left you will see the list with Optimization Requests and on the right the component to start a long term optimization request. Select a service territory (for now only one service territory is supported), a start date and how many days to optimize. The overlap between optimization requests defines when the next optimization request starts. Optionally, provide the API name of the Boolean field on the Service Appointment object which is used to determine which appointments are eligible for optimization. 
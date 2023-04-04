# Long Term Optimization for Salesforce Field Service

This project is an example how to run Salesforce Field Service Optimization for a longer period than the 21 days that is supported out of the box. It chains Optimization Requests enabling a longer period to be optimized. 

# How To Use

Deploy the metadata to your org and assign the "Field Service Long Term Optimization" permission set to your user. Navigate to the Long Term Optimization tab via the App Launcher. On the left you will see the list with Optimization Requests and on the right the component to start a long term optimization request. Select a service territory (for now only one service territory is supported), a start date and how many days to optimize. The overlap between optimization requests defines when the next optimization request starts. Optionally, provide the API name of the Boolean field on the Service Appointment object which is used to determine which appointments are eligible for optimization. 
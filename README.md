---
page_type: 
description: "Azure high availability solutions with sample application and terraform scripts"
products:
- Azure Virtual Machine Scale Set
- Azure Application Gateway
- Azure SQL Database
- Azure Private Endpoint
- Azure Front Door
- Azure Traffic Manager
- Azure Cross Region Load Balancer
languages:
- dotnet
- terraform
---

## Purpose
To show various options to deploy an application in high availability mode, including
- Azure Traffic Manager
- Azure Front Door
- Azure Cross Region Load Balancer

The application uses Azure sql failover group to provide geo-replication as well as automatic failover.

Estimated [solution monthly cost](https://azure.com/e/8be03981a30a4d0aad6cfc5637ad3051)

## Architecture
Architecture design diagram
![Architecture](/Images/Architecture.png)

## Folder Structure
- Deploy - Terraform scripts
- TodoApp - Sample dotnet 6.0 application which uses an Azure SQL database as a backend, there is a prebuilt container image huangyingting/todo available from docker hub.

## Deploy
### 1. DNS
The deployment require a domain name being registered and configured to be used for sub-sequence resources, including certificate automation from Let's Encrypt, Azure Front Door custom domain etc.

It is recommnended to follow below steps to get DNS work before deployment
- [Buy a custom domain name for Azure App Service
](https://learn.microsoft.com/en-us/azure/app-service/manage-custom-dns-buy-domain)
- [Host your domain on Azure DNS](https://learn.microsoft.com/en-us/training/modules/host-domain-azure-dns/)

### 2. Create Azure credentials
You will also need to create a service principal and paste its details in another secret called AZURE_CREDENTIALS. This is called a deployment credential. The process for doing this is described [here](https://github.com/Azure/login#configure-deployment-credentials). 

```
az ad sp create-for-rbac --name "spname" --sdk-auth --role contributor --scopes /subscriptions/<subscription-id>
```

In case you don't want the service principal to have such wide permissions, you can create a regular resource group service principal with contributor rights as explained [here](https://github.com/Azure/login#configure-deployment-credentials) and create your resource group through the portal or through CLI statements. 

### 3. Customize deployment variables
You will also need to create a file terraform.tfvars in Deploy folder with below values
```
email_address = "Your e-mail address used for request certificate from Let's Encrypt"
dns_zone_name = "Registered DNS name"
certificate_name = "Your certificate name"
dns_zone_resource_group_name = "Azure DNS resource group name in step 1"
azure_subscription_id = "Subscription id in step 2"
azure_tenant_id       = "Tenant id in step 2"
azure_client_id       = "Service principal client id in step 2"
azure_client_secret   = "Service principal client secret in step 2"
```
### 4. Deploy
- [Install terraform client](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- Change directory to Deploy folder
- Run following commands to kick off deployment
```
terraform init
terraform apply -auto-approve
```
- To destory the deployment, run
```
terraform destroy -auto-approve
```
### 5. Approve private endpoint connections
The last step is to approve private endpoint connections manually (no auto approve currently)
From Azure portal, find Azure storage account created in step 4, under "Security + networking" -> Networking -> Private endpoint connections, check all connections and click "Approve" button to approve the connections.

### 6. Deployed services overview
Below is resource visualization of deployed services 
![Deployed Services](/Images/HA-Services.png)

### 7. Testing
Azure front door waf testing
```
docker run -v ${PWD}/reports:/app/reports --network="host" \
    wallarm/gotestwaf --url=https://AFD_FQDN
```
Azure application gateway waf testing
```
docker run -v ${PWD}/reports:/app/reports --network="host" \
    wallarm/gotestwaf --url=https://APPGW_FQDN
```

## Contributing
Refer to the [Contributing page](/CONTRIBUTING.md)
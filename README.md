# databricksws-avm

This repository contains a pattern of bicep modules from the https://aka.ms/avm (or go directly to https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/databricks/workspace)

**On first deployment. You will have to reset the Virtual Machines admin password. You can do this under the "Connect" tab
Then log in with the Bastion tab on the VM.**

Once you have logged into the VM, navigate go to https://accounts.azuredatabricks.net

(You will be able to log in if you have owner on the Resource Group that databricks was deployed into)

You must now add yourself and others to the Workspace/xxxx/Permissions tab as either a databricks user or admin

Once done, you can open the Azure databricks workspace, the link can be found in the Workspaces tab of the Accounts website that you are logged into


The basic deployment of Databricks with its virtual networks
- Databricks workspace   
- Virtual Network with subnets 
- Network Security Group
- Private Endpoints
- Private DNS Zone for Databricks


The Virtual Machine
- Creates a Microsoft windows server 2022 Data centre
- Bastion host linked to the Virtual network which is created in the above steps
- Public IP for the Bastion


<img width="552" alt="bicepvisualdatabricksvnet" src="https://github.com/clintgrove/databricksws-avm/assets/30802291/9ba5a38a-0acd-4b3d-add7-09c522709079">

Steps 

#### Deployment
Clone or Fork this repository
Go to GitHub actions once you forked/cloned. Then add these secrets as you can see in the screenshot

![image](https://github.com/clintgrove/databricksws-avm/assets/30802291/2c6d3ca5-22ca-4c05-a985-34370c7e04ce)

To create the secret called AZURE_CREDENTIALS you need to make a service principal, like this 

`az ad sp create-for-rbac --name "myApp" --role contributor --scopes /subscriptions/<subscription-id>/resourceGroups/<group-name>/providers/Microsoft.Web/sites/<app-name> --json-auth`

You can find out more on this page https://learn.microsoft.com/en-us/azure/app-service/deploy-github-actions?tabs=userlevel%2Caspnetcore

The first time that you run this deployment, you must be set the network to **"new"** for the vnetAddressPrefixParam paramter. This will deploy a new virtual network. Every other subsequent deployment must have this parameter set to **"existing"**

![image](https://github.com/clintgrove/databricksws-avm/assets/30802291/2d240af2-9d27-4fbb-8ea0-04c4f5cbace1)

#TODO
#### access and permissions
##### Private endpoints and DNS zones

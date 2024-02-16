# databricksws-avm

This repository contains a pattern of bicep modules from the aka.ms/avm

On first deployment. You will have to reset the Virtual Machines admin password. You can do this under the "Connect" tab
Then log in with the Bastion tab on the VM. 
From there you can go to https://accounts.azuredatabricks.net

You can log in if you have owner on the Resource Group that databricks was deployed into. 

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

#### deployment
The first time that you run it, it must be set to "new" for the vnetAddressPrefixParam paramter. This will deploy a new virtual network. Every other subsequent deployment must have this parameter set to "existing"

#### access and permissions
##### Private endpoints and DNS zones

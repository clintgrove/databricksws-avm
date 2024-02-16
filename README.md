# databricksws-avm

This repository contains a pattern of bicep modules from the aka.ms/avm

It deploys a Databricks workspace
A Virtual Network with subnets
A Network Security Group


Steps 

#### deployment
The first time that you run it, it must be set to "new" for the vnetAddressPrefixParam paramter. This will deploy a new virtual network. Every other subsequent deployment must have this parameter set to "existing"

#### access and permissions
##### Create a service principal

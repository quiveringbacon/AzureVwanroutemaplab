# Azure Vwan routemap lab

This creates a vwan and a couple of spoke vnets with VM's connected to the vhub and an onprem vnet with a CSR1000v with a S2S tunnel to the vhub. The creates 2 routemaps, 1 prepends an AS to the spoke2 vnet route sent to onprem and another that modifies the route that spoke2 gets from onprem. You'll be prompted for the resource group name, location where you want the resources created, your public ip and username and password to use for the VM's. NSG's are placed on the default subnets of each vnet allowing RDP access from your public ip. This also creates a logic app that will delete the resource group in 24hrs.

The topology will look like this:
![wvanlabwithS2Sandroutemaps](https://github.com/quiveringbacon/AzureVwanroutemaplab/assets/128983862/5f119e85-e907-477e-9ded-16d1cd06f503)

You can run Terraform right from the Azure cloud shell by cloning this git repository with "git clone https://github.com/quiveringbacon/AzureVwanroutemaplab.git ./terraform".

Then, "cd terraform" then, "terraform init" and finally "terraform apply -auto-approve" to deploy.

*this is a long deployment and might take up to 1.5 to 2hrs to finish deploying*

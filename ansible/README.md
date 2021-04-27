On the host virtual machine, export the service principal values to configure your Ansible credentials.

export AZURE_SUBSCRIPTION_ID=<your-subscription_id>
export AZURE_CLIENT_ID=<security-principal-appid>
export AZURE_SECRET=<security-principal-password>
export AZURE_TENANT=<security-principal-tenant>

az vm list `
  --resource-group vocalink-rg `
  --query "[].{Name:name}" `
  --output table

[# Run the following ansible-inventory command to verify that Ansible can discover your inventory.](https://github.com/ansible/ansible/blob/stable-2.9/lib/ansible/plugins/inventory/azure_rm.py)

ansible-inventory --inventory azure_rm.yml --graph




# Run the ping module on your VMs
ansible \
--inventory azure_rm.yml \
--user testadmin \
--module-name ping \
tag_environment_Production
  
# Run the users playbook on your VMs
Run the following ansible-playbook command to apply your playbook:
ansible-playbook \
--inventory azure_rm.yml \
--private-key ~/.ssh/terraform_rsa.pem \
--user testadmin \
users.yml 
 
 # Verify
 IP_ADDRESS=$(az vm list-ip-addresses \
  --resource-group vocalink-rg \
  --name vm-01 \
  --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress \
  --output tsv)

  ssh -i ~/.ssh/terraform_rsa.pem testadmin@$IP_ADDRESS "/usr/bin/getent passwd testuser1"

  # You can use Ansible to run the same command on each of your VMs
  The --args argument specifies the command to run on each VM.

  ansible \
  --inventory azure_rm.yml \
  --user testadmin \
  --private-key ~/.ssh/terraform_rsa.pem \
  --args "/usr/bin/getent passwd testuser1" \
  tag_environment_Production

  # Run the following ansible-playbook command to apply your playbook a second time:
  ansible-playbook \
  --inventory azure_rm.yml \
  --user testadmin \
  --private-key ~/.ssh/terraform_rsa.pem \
  users.yml


## Create a Service Principal

1. go to your Azure Cloud Shell session.
   
2. Run the following az account list to get your Azure subscription ID, and save it as a Bash variable named ARM_SUBSCRIPTION_ID.

```
ARM_SUBSCRIPTION_ID=$(az account list \
  --query "[?isDefault][id]" \
  --all \
  --output tsv)
```
3. Create a unique identifier.

```Bash
UNIQUE_ID=$RANDOM
```

4. Run the following az ad sp create-for-rbac command to create a service principal.

ARM_CLIENT_SECRET=$(az ad sp create-for-rbac \
  --name http://ansible-sp-$UNIQUE_ID \
  --role Contributor \
  --scopes "/subscriptions/$ARM_SUBSCRIPTION_ID" \
  --query password \
  --output tsv)

The service principal's name begins with "http://ansible-sp-", and ends with your unique ID.

Contributor is the default role for a service principal. This role has full permissions to read and write to an Azure subscription.

The output from this command is your only opportunity to retrieve the generated password for the service principal. The --query argument reads the password field from the output. The output is assigned to the Bash variable named ARM_CLIENT_SECRET.


5. Run the following az ad sp show command to get your service principal's client ID, and assign the result to a Bash variable named ARM_CLIENT_ID.


ARM_CLIENT_ID=$(az ad sp show \
  --id http://ansible-sp-$UNIQUE_ID \
  --query appId \
  --output tsv)

6. Run the following az ad sp show command to get your service principal's tenant ID, and assign the result to a Bash variable named ARM_TENANT_ID.

ARM_TENANT_ID=$(az ad sp show \
  --id http://ansible-sp-$UNIQUE_ID \
  --query appOwnerTenantId \
  --output tsv)

7. Run the following az ad sp list command to list the service principals in your Azure subscription.
   
az ad sp list --show-mine --query [].servicePrincipalNames

8. Run the following echo and tee commands to create a credentials file that contains information about your service principal.
echo "\
[default]
subscription_id=$ARM_SUBSCRIPTION_ID
client_id=$ARM_CLIENT_ID
secret=$ARM_CLIENT_SECRET
tenant=$ARM_TENANT_ID" | tee credentials

$> cat credentials


1. Login to Cloud shell 
   
2. Run the following az group create command to create a resource group that's named learn-ansible-control-machine-rg.
   `az group create --name learn-ansible-control-machine-rg`

3. Run the following az vm create command to create a CentOS VM:

```bash
  az vm create \
 --resource-group learn-ansible-control-machine-rg \
 --name ansiblehost \
 --admin-username azureuser \
 --image OpenLogic:CentOS:7.7:latest \
 --ssh-key-values ~/.ssh/terraform_rsa.pub
```

{\ Finished ..
  "fqdns": "",
  "id": "/subscriptions/32ad910c-d715-45c1-a237-84dfaf1e8216/resourceGroups/learn-ansible-control-machine-rg/providers/Microsoft.Compute/virtualMachines/ansiblehost",
  "location": "uksouth",
  "macAddress": "00-22-48-40-F1-BC",
  "powerState": "VM running",
  "privateIpAddress": "10.0.0.4",
  "publicIpAddress": "20.90.106.43",
  "resourceGroup": "learn-ansible-control-machine-rg",
  "zones": ""
}


4. Run the following az vm extension set command to run the Custom Script Extension. The script configures Ansible on your VM.
az vm extension set \
  --resource-group learn-ansible-control-machine-rg \
  --vm-name ansiblehost \
  --name customScript \
  --publisher Microsoft.Azure.Extensions \
  --version 2.1 \
  --settings '{"fileUris":["https://raw.githubusercontent.com/MicrosoftDocs/mslearn-ansible-control-machine/master/configure-ansible-centos.sh"]}' \
  --protected-settings '{"commandToExecute": "./configure-ansible-centos.sh"}'


  configure-ansible-centos.sh
  https://raw.githubusercontent.com/MicrosoftDocs/mslearn-ansible-control-machine/master/configure-ansible-centos.sh

```shell
#!/bin/bash

# Update all packages that have available updates.
sudo yum update -y

# Install Python 3 and pip.
sudo yum install -y python3-pip

# Upgrade pip3.
sudo pip3 install --upgrade pip

# Install Ansible.
pip3 install ansible[azure]

# Install Ansible modules and plugins for interacting with Azure.
ansible-galaxy collection install azure.azcollection

# Install required modules for Ansible on Azure
wget https://raw.githubusercontent.com/ansible-collections/azure/dev/requirements-azure.txt

# Install Ansible modules
sudo pip3 install -r requirements-azure.txt

```

see https://docs.microsoft.com/en-us/azure/developer/ansible/install-on-linux-vm?tabs=ansible#install-ansible-on-the-virtual-machine 

5. Run the following command to store your VM's public IP address in a Bash variable:
   IPADDRESS=$(az vm list-ip-addresses \
  --resource-group learn-ansible-control-machine-rg \
  --name ansiblehost \
  --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress \
  --output tsv)

plugin: azure.azcollection.azure_rm
    include_vm_resource_groups:
      - vocalink-rg
    auth_source: auto
    keyed_groups:
    - prefix: tag
    key: tags
    plain_host_names: True
# Check if your environment is setup correctly
`.\terraform.exe init`

Initializing provider plugins...

The following providers do not have any version constraints in configuration,
so the latest version was installed.

To prevent automatic upgrades to new major versions that may contain breaking
changes, it is recommended to add version = "..." constraints to the
corresponding provider blocks in configuration, with the constraint strings
suggested below.

* provider.azurestack: version = "~> 0.8"
* provider.random: version = "~> 2.1"

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "Terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.


# Verify your plan
.\terraform.exe plan -var-file=C:\<DirectoryName>\terraform.tfvars
# Apply your plan
.\terraform.exe apply -var-file=C:\<DirectoryName>\terraform.tfvars

# Create a service principal
You've configured Terraform to access the state file remotely. Next, you create the service principal that can authenticate with Azure on your behalf.
https://docs.microsoft.com/en-us/learn/modules/provision-infrastructure-azure-pipelines/6-run-terraform-remote-storage

# Delete the state file from Blob storage
Here, you delete your state file from Blob storage.
https://docs.microsoft.com/en-us/learn/modules/provision-infrastructure-azure-pipelines/6-run-terraform-remote-storage


### Team Foundation Server is now called Azure DevOps Server

On September 10, 2018, Microsoft renamed Visual Studio Team Services (VSTS) to Azure DevOps Services. With Azure DevOps Server 2019, Microsoft is renaming Visual Studio Team Foundation Server to Azure DevOps Server.

You define and manage service connections from the Admin settings of your project:

Azure DevOps: https://dev.azure.com/{organization}/{project}/_settings/adminservices
e.g.
https://dev.azure.com/sandpit-devops/TailspinWebSpace/_settings/adminservices

TFS: https://{tfsserver}/{collection}/{project}/_admin/_services

# List Azure Locations 
az account list-locations   --query "[].{Name: name, DisplayName: displayName}"   --output table

## Housekeeping 

1. Go to the Cloud Shell

2. Run the following az group delete command to delete the resource group for your App Service deployment, tailspin-space-game-rg.

`az group delete --name tailspin-space-game-rg --yes`

3. Run the following az group delete command to delete the resource group for your storage account, tf-storage-rg.

`az group delete --name tf-storage-rg --yes`

As an optional step, run the following az group list command after the previous command finishes.

`az group list --output table`

You see that the resource groups tailspin-space-game-rg and tf-storage-rg no longer exist.

To delete your service principal:

Run the following az ad sp list command to list the service principals in your Azure subscription.


`az ad sp list --show-mine --query [].servicePrincipalNames`

Locate the service principal that you created in this module. The name begins with http://tf-sp- and ends with your unique ID. Here's an example:

```JSON
[
  [
    "http://tf-sp-28277",
    "198244ba-dc73-4561-acea-356c513b0c37"
  ]
]
```
Run the following az ad sp delete command to delete your service principal. Replace the name shown here with yours.

`az ad sp delete --id http://tf-sp-28277`

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

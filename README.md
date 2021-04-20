Team Foundation Server is now called Azure DevOps Server

On September 10, 2018, Microsoft renamed Visual Studio Team Services (VSTS) to Azure DevOps Services. With Azure DevOps Server 2019, Microsoft is renaming Visual Studio Team Foundation Server to Azure DevOps Server.

You define and manage service connections from the Admin settings of your project:

Azure DevOps: https://dev.azure.com/{organization}/{project}/_settings/adminservices
e.g.
https://dev.azure.com/sandpit-devops/TailspinWebSpace/_settings/adminservices

TFS: https://{tfsserver}/{collection}/{project}/_admin/_services

# List Azure Locations 
az account list-locations   --query "[].{Name: name, DisplayName: displayName}"   --output table

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

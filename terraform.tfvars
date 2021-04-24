# Configure the Azure Stack Hub Provider
# arm_endpoint - The Azure Resource Manager API Endpoint for your Azure Stack Hub instance. This will be https://management.{region}.{domain}.
# subscription_id - The ID of your Azure Stack Hub Subscription.
# client_id - The Application GUID that you configured your Service Principal Name (SPN) to use.
# client_secret - The Application password that you configured your Service Principal Name (SPN) to use.
# tenant_id - The tenant ID of your Azure Active Directory tenant domain. It can either be the actual GUID or your Azure Active Directory tenant domain name.

# Get VM list on 
# az vm image list -f RedHat -l uksouth --all --query "[].{publisher:publisher, offer:offer, sku: sku, latest:version}" --output=table
#vm_image_string             = "OpenLogic/CentOS/7.5/latest"

location        = "uksouth"
vm_count        = 2
vm_image_string = "cognosys/python-3-with-redhat-7-9/python-3-with-redhat-7-9/latest"

vm_size         = "Standard_A1_v2"
rg_name         = "vocalink-rg"
rg_tag          = "Production"

admin_username = "testadmin"
admin_password = "Password123!"

vm_type        = "Linux"
os_profile_linux_config_disable_password_authentication = false


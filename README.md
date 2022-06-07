# Azuremkt_Img_to_vhd
This script allows creating a page blob vhd from a list of Azure Marketplace images

The original purpose of this script was to make it easier to deploy VMs based on Azure Marketplace images in Azure Stack Edge. To import an image to ASE, you need to have it available in blob storage as a page blob with .vhd extension. There's a procedure in ASE's documentation but it's a lot of work to do and it's slow because it uses Start-AzStorageBlobCopy to perform a copy from managed disk to page blob. https://docs.microsoft.com/en-us/azure/databox-online/azure-stack-edge-gpu-create-virtual-machine-marketplace-image

This script makes it easier to generate the .vhd file because it allows you to simply choose from a list instead of having to look for sku codes and makes the procedure quicker by not only automating but also from allowing using azcopy. If you prefer to use AzCopy (highly recommended), and you don't have its location in PATH, you can download the executable from https://aka.ms/downloadazcopy-v10-windows , unzip, and place azcopy.exe in the folder where you run the script from.

To run, simply download the .ps1 file and run it from powershell. You'll need:

- Your Azure subscription id
- The name of a Resource Group (if it doesn't exist, you'll be prompted for a region on which to create it)
- The name of a Storage Account (if it doesn't exist, the script will attempt to create it)
- The name of a blob container on the Storage Account (if it doesn't exist, the script wil attempt to create it)
- The name you want to give the disk
- AzCopy in your machine (optional, highly recommended)

At this moment, the script doesn't verify if creating the resource group, storage account, or blob container is successful or not. It would be recommended that you make sure the names you use are unique and valid if you don't use resources that already exist and are relying on the script to create them for you.
The script also simply assumes the creation of the intermediate managed disk is successful, so make sure the name is unique and valid.

The script is provided as is.

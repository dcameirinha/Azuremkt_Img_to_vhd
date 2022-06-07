<#
 # This script allows you to make a page blob with .vhd extension out of a few Azure Marketplace VM images
 # The page blob can, for example, be imported to Azure Stack Edge to be used as an image to create VMs
 # You need Powershell 5.0 or higher, and the Az module installed
 # It is highly recommended that you have AzCopy installed or at least that the executable is in the same folder as the script file
#>


Write-Host "Welcome! This script allows you to fetch an Azure VM image and copy it to a page blob."
Write-Host "Let's check a few things first..."
Write-Host "Checking Powershell version..."
if ($PSVersionTable.PSVersion.Major -lt 5)
    {
        Write-Host "PowerShell version detected to be older than 5.0. Please update"
        exit
    }
Write-Host "OK" -BackgroundColor Black -ForegroundColor Green

Write-Host "Checking if Az module is installed..."
$azversion = Get-InstalledModule -Name Az
if (!$azversion)
    {
        Write-Host "Az module not detected, please install"
        exit
    }
Write-Host "OK" -BackgroundColor Black -ForegroundColor Green

Write-Host "Let's go"

$SubscriptionId = Read-Host -Prompt "Enter your Azure Subscription Id (public cloud)"
Write-Host "Checking..."
$azcontext = Get-AzContext

if (!$azcontext -or ($azcontext.Subscription.Id -ne $SubscriptionId)) 
    {
        Write-Host "Not connected, please login"
        Connect-AzAccount -Subscription $SubscriptionId
    }
else 
    {
        Write-Host "SubscriptionId '$SubscriptionId' already connected"
    }


$resourceG = Read-Host -Prompt "Give me the name of a Resource Group, please"

if (!(Get-AzResourceGroup -Name $resourceG))
{
    Read-Host "It looks like this resource group does not exist. Creating it..."
    
    $loctest = $false
    $loclist = Get-AzLocation
    while (!$loctest)
    {
        $location = Read-Host -Prompt "Choose an Azure Region for your resource group, please"

        foreach ($l in $loclist)
        {
            if($location -eq $l.DisplayName -or $location -eq $l.Location)
               { 
                    $loctest = $true
                    break
                }
        }

        if(!$loctest)
        {
            Write-Warning "Cannot find $location in the Azure region list"
        }
    }

    New-AzResourceGroup -Name $resourceG -Location $location
}

$location = (Get-AzResourceGroup -Name $resourceG).Location


$storageaccname = Read-Host -Prompt "Give me the storage account name, please. If it doesn't exist, I'll try to create it"
$diskname = Read-Host -Prompt "Give me a name for the disk, please"
$blobcontainer = Read-Host -Prompt "Give me a name for the blob container, please. If it doesn't exist, I'll try to create it"



$imageselecttest=$false;
Write-Host "Tell me which of these images you'd like me to get for you, please:"
Write-Host "1: 2019 Datacenter"
Write-Host "2: 2019 Datacenter 30GB"
Write-Host "3: 2019 Datacenter Core"
Write-Host "4: 2019 Datacenter Core 30GB"
Write-Host "5: Windows 10"
Write-Host "6: Windows 11"
Write-Host "7: Canonical Ubuntu Server 18.04 LTS"
Write-Host "8: Canonical Ubuntu Server 16.04 LTS"
Write-Host "9: CentOS 8.1"
Write-Host "10: CentOS 7.7"

While (!$imageselecttest)
{
    $imageoption = Read-Host -Prompt "Choose wisely..."
    $imageselecttest = $true

    switch($imageoption)
    {
        1 {$image = Get-AzVMImage -PublisherName "MicrosoftWindowsserver" -Offer "Windowsserver" -sku "2019-Datacenter" -Location $location | Select-Object -Index 0; break}
        2 {$image = Get-AzVMImage -PublisherName "MicrosoftWindowsserver" -Offer "Windowsserver" -sku "2019-Datacenter-smalldisk" -Location $location | Select-Object -Index 0; break}
        3 {$image = Get-AzVMImage -PublisherName "MicrosoftWindowsserver" -Offer "Windowsserver" -sku "2019-Datacenter-core" -Location $location | Select-Object -Index 0; break}
        4 {$image = Get-AzVMImage -PublisherName "MicrosoftWindowsserver" -Offer "Windowsserver" -sku "2019-Datacenter-core-smalldisk" -Location $location | Select-Object -Index 0; break}
        5 {$image = Get-AzVMImage -PublisherName "MicrosoftWindowsDesktop" -Offer "Windows-10" -sku "win10-21h2-pro" -Location $location | Select-Object -Index 0; break}
        6 {$image = Get-AzVMImage -PublisherName "MicrosoftWindowsDesktop" -Offer "Windows-11" -sku "win11-21h2-pro" -Location $location | Select-Object -Index 0; break}
        7 {$image = Get-AzVMImage -PublisherName "Canonical" -Offer "UbuntuServer" -sku "18.04-LTS" -Location $location | Select-Object -Index 0; break}
        8 {$image = Get-AzVMImage -PublisherName "Canonical" -Offer "UbuntuServer" -sku "16.04-LTS" -Location $location | Select-Object -Index 0; break}
        9 {$image = Get-AzVMImage -PublisherName "OpenLogic" -Offer "CentOS" -sku "8_1" -Location $location | Select-Object -Index 0; break}
        10 {$image = Get-AzVMImage -PublisherName "OpenLogic" -Offer "CentOS" -sku "7.7" -Location $location | Select-Object -Index 0; break}
        default {imageselecttest = $false; Write-Host "You chose poorly: Image could not be found, maybe it is not available in this region; break"}
      }
}
Write-Host "You have chosen... Wisely! $($image.Offer) $($image.Skus)"

Write-Host "Creating intermediate disk resource..."
$diskConfig = New-AzDiskConfig -Location $location -CreateOption FromImage -ImageReference @{Id = $image.Id}
$disk = New-AzDisk -Disk $diskConfig -ResourceGroupName $resourceG -DiskName $diskname
$sas = Grant-AzDiskAccess -ResourceGroupName $resourceG -DiskName $diskname -Access read -DurationInSecond 3600
Write-Host "Disk created and copy access granted..."

Write-Host "Checking if Storage Account exists..."
if( !(Get-AzStorageAccount -ResourceGroupName $resourceG -Name $storageaccname -ErrorAction SilentlyContinue))
{
    Write-Host "It looks like it doesn't. Creating storage account with name $($storageaccname) ..."
    New-AzStorageAccount -ResourceGroupName $resourceG -AccountName $storageaccname -Location $location -SkuName Standard_LRS
    Write-Host "Storage Account created..."
}

Write-Host "Fetching Storage Account access key and creating storage context..."
$sakey = (Get-AzStorageAccountKey -ResourceGroupName $resourceG -AccountName $storageaccname)| Where-Object {$_.KeyName -eq "key1"}
$scontext = New-AzStorageContext -StorageAccountName $storageaccname -StorageAccountKey $sakey.Value
Write-Host "Got them..."

Write-Host "Cheking if blob container exists..."
if(!(Get-AzStorageContainer -Name $blobcontainer -Context $scontext -ErrorAction SilentlyContinue))
{
    Write-Host "It looks like it doesn't. Creating blob container called $($blobcontainer) on Storage Account $($storageaccname) ..."
    New-AzStorageContainer -Name $blobcontainer -Context $scontext | Out-Null
    Write-Host "Blob container created..."
}

$blobname = (-join ($diskname, ".vhd"))


$useazcp = Read-Host -Prompt "Use AzCopy? (y/n) (highly recommended)"

if($useazcp -eq "y" -or $useazcp -eq "yes")
{
    Write-Host "Good choice! Checking AzCopy..."
    $azversion = azcopy --version
    $localazcp = $false


    if(!$azversion)
    {
        $azversion = .\azcopy --version

        if(!$azversion)
        {
        Write-Host "Could not find AzCopy, neither at the system level nor in this location"
        Write-Host "Go to https://aka.ms/downloadazcopy-v10-windows , donwload, unzip, and place azcopy.exe in this folder"
        exit
        }
        else {$localazcp = $true}
        
    }

    $destSAS = New-AzStorageAccountSASToken -Service Blob -ResourceType Service,Container,Object -Permission "rwd" -Context $scontext

    $desturl = "https://$($storageaccname).blob.core.windows.net/$($blobcontainer)/$($blobname)$($destSAS)"

    if($localazcp)
    {
        Write-Host "Found AzCopy on this folder, using it..."
        .\azcopy copy $sas.AccessSAS $desturl
    }
    else
    {
        Write-Host "Found AzCopy is available everywhere. Cool! Using it..."
        azcopy copy $sas.AccessSAS $desturl
    }

}
else
{
    Write-Host "Starting copy from managed disk to page blob $($blobname) in $($blobcontainer)... Not using AzCopy, this will take a while..."
    Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $blobcontainer -DestContext $sContext -DestBlob $blobname -ConcurrentTaskCount 50 -Force | Out-Null

    Start-Sleep -Seconds 1
    $copystatus = Get-AzStorageBlobCopyState -Container $blobcontainer -Context $sContext -Blob $blobname

    while ($copystatus.Status -ne "Success")
    {
        $percent =  [int32](( [float]$copystatus.BytesCopied / [float]$copystatus.TotalBytes) * 100)
        Write-Progress -Activity "Copy Status" -Status "$($percent)% Complete" -PercentComplete $percent

        Start-Sleep -Seconds 10
        $copystatus = Get-AzStorageBlobCopyState -Container $blobcontainer -Context $sContext -Blob $blobname
    }

    Write-Progress -Completed
}

Write-host "Cleaning up..."
Revoke-AzDiskAccess -ResourceGroupName $resourceG -DiskName $diskname | Out-Null
Write-Host "Disk access revoked..."
Remove-AzDisk -ResourceGroupName $resourceG -DiskName $diskname -Force | Out-Null
Write-Host "Intermetiate disk deleted..."
Write-Host "All Done!"
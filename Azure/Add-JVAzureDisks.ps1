
#Region Azure Login and Server Creds and Various Variables
#Requires -Module AzureRM
Write-Host "Please Login to Azure" -ForegroundColor Green
Connect-AzureRmAccount
Write-Host "Please Enter Your Administrator Account Credentials" -ForegroundColor Yellow
$credential = Get-Credential
#Max size in GB of disks
$MaxDiskSize = "500"
#Temporary Location for listing Disk letters
$Path = "C:\Temp"
$PathTest = Test-Path $Path

if ($PathTest -eq $false) {
New-Item -Path "C:\" -ItemType Directory -Name "Temp"
}


#EndRegion

#Region Set INFO

    #Region Set VM
$VMNameList = Get-AzureRmVM | Select-Object Name
$Validate = $false
do {
 
    $VMName = Read-host "Enter the VM Name"
 
    if ($VMName -in $VMNameList.Name) {
     
        Write-Host "$VMname is now the VM this script will action on" -ForegroundColor Green
        $Validate = $true
        $VMName = "$VMName"
    }
    else {
        Write-Host "The VM $VMName does not exist in Azure!" -ForegroundColor Red
        $Validate = $false
    }
 
} while ($Validate -eq $false)
#endregion

    #Region Create PS Session on VM
    
    $Session = New-PSSession -ComputerName $vmName -Credential $credential

    #EndRegion

    #Region Set Resource Group
Write-Host "Setting Azure Resource Group...." -ForegroundColor Yellow
$ResourceGroup =  Get-AzureRmVm | Where-Object {$_.Name -eq $VMName} | Select-Object ResourceGroupName
$rgName = $ResourceGroup.ResourceGroupName
Start-Sleep -Seconds 1
Write-host "Resource Group Set to $rgname" -ForegroundColor Green

   
    #Region Set Location
Write-Host "Setting Azure Location...." -ForegroundColor Yellow
$Setlocation = get-azurermvm -ResourceGroupName $rgName -Name $VMName
$Location = $Setlocation.Location
start-sleep -Seconds 1
Write-Host "Location set to $($Location.ToUpper())" -ForegroundColor Green
#endregion

    #Region VMInfo
    
    $VMinfo = Get-AzureRmVm -ResourceGroupName $rgName -Name $VMName

    #EndRegion

    #Max number of disks to add

    $VMSize = $VMinfo.HardwareProfile.VmSize
    $MaxDisk = Get-AzureRmVMSize -ResourceGroupName $ResourceGroup.ResourceGroupName -VMName $VMName | Where-Object {$_.Name -eq "$vmsize"}
    $MaxDisk = $MaxDisk.MaxDataDiskCount
    
#EndRegion

    #Region Set Number of Disks to Add

    do {
        
    $InputNumber = Read-Host "How Many Disks Would You Like to Add to $Vmname (maximum $MaxDisk)"
    
    if ([int]$InputNumber -gt [int]$MaxDisk) {
        Write-host "$InputNumber is too many!" -ForegroundColor Red
        
    }
    else {
        Write-Host "$InputNumber will be the number of disks added to $Vmname" -ForegroundColor Green
        $numberofdisks = 1..$InputNumber
    }
    
    } until ([int]$InputNumber -le [int]$MaxDisk)
    #EndRegion

    #Region Set Disk Type
    foreach ($Disk in $numberofdisks) {
    Write-Host "Setting Properties of Disk $Disk" -ForegroundColor Yellow   
    $Options = 1, 2, 3, 4
        
    do {
    Write-Host "Please choose Disk Type for the Disk $Disk"
    Write-Host "
1) Standard HDD
2) Standard SSD
3) Premium SSD
4) Exit
"
    $Global:Option = Read-Host "Answer"
    }
while ($($Option -in $Options) -eq $false)
 
switch -regex ($Option) {
    1 {
        Write-Host "Standard HDD Selected" -ForegroundColor Green
        $SKU = 'Standard_LRS'
    }
    2 {
        Write-Host "Standard SSD Seclected" -ForegroundColor Green
        $SKU = 'StandardSSD_LRS'
    }
    3 {
        Write-Host "Premium SSD Selected" - -ForegroundColor Green
        $SKU = 'Premium_LRS'
    }
    "exit" {
        break
    }
    Default {break}
}  
#EndRegion

    #Region Set Disk Size
    $Validate = $false
do  {
      
    $InputSize = Read-Host "Please enter the size in GB of Disk $Disk (Maxium $MaxDiskSize)"
        
    if ([int]$InputSize -gt [int]$MaxDiskSize) {
        Write-Host "Size of disk cannot exceed $MaxDiskSize GB" -ForegroundColor Red
        }
    else {
        Write-Host "$Inputsize GB will be the size of Disk $Disk" -ForegroundColor Green
        $DiskSize = $InputSize 
        $Validate = $true
    }
    }    
    until ([int]$DiskSize -lt [int]$MaxDiskSize -and $Validate -eq $true)
#EndRegion
    
    #Region Set Disk Letter
    #Limits Drive Letter between D and Z and checks if selected Drive Letter is in use
    $Regex = "[d-zD-Z]{1}"
    $Regnum = ".*\d+.*"
    $CurrentLetters = @()
        
    
    $CurrentLetters = Invoke-Command -Session $Session -ScriptBlock {
        
        Get-Partition
        }

    $CurrentLetters.DriveLetter | Where-Object {$_} | Out-File $Path\Disk_$VMName.txt
    $DiskLetterFile = "$Path\Disk_$VMname.txt"
    $Content = Get-Content $DiskLetterFile
    

        $Validate = $false
        Write-Host "Info: Current Letters in Use on $Vmname  " -NoNewline
        Write-Host $Content -ForegroundColor Yellow
            
        
     do {
        [string]$DriveLetter = Read-Host "Please Enter the Drive Letter for Disk $Disk" 
        if ([string]$DriveLetter -notmatch $Regex) {
            Write-Host "$DriveLetter invalid - Please select letters between D and Z" -ForegroundColor Red
        }
        elseif ($DriveLetter -match $Regnum) {
            Write-Host "$DriveLetter Invalid - Value cannot include Numbers" -ForegroundColor Red
        }

        elseif ($DriveLetter -in $Content ) {
            Write-Host "Disk $Disk Cannot be labelled $Driveletter as it is already in use by another disk" -ForegroundColor Red
            }

        else {
            Write-Host "$DriveLetter Will be the Letter assigned to Disk $Disk" -ForegroundColor Green
            $Validate = $true
            $DriveLetter | Out-File $DiskLetterFile -Append
            $Content = Get-Content $DiskLetterFile


        }
        }
    while ([string]$DriveLetter -notmatch $Regex -or $DriveLetter -match $Regnum -or $Validate -eq $false)
#EndRegion

    #Region Set Drive Label
    do {
    $DriveLabel = Read-Host "Please Enter The Name for this Disk (e.g "Data")"
    $DriveLabelCheck = Read-Host "Disk $Disk Will be labelled "$DriveLabel" - Are you sure?"

    if ($DriveLabelCheck -match "No") {
        $DriveLabelCheck = $false
    }
    elseif ($DrivelabelCheck -notmatch "Yes" ) {
        Write-Host "Please confirm with "Yes" or "No"" -ForegroundColor Yellow
        $DriveLabelCheck = $false
    }
    else {
        $DriveLabelCheck = $true
        Write-Host "Disk $Disk will be labelled "$DriveLabel"" -ForegroundColor Green
    }
    }
    Until($DriveLabelCheck -eq $true) 
#EndRegion

    #Region Set Lun
    
    $CurrentLuns = Invoke-Command -Session $session -ScriptBlock {get-disk | Measure-Object }
    $Lun = $CurrentLuns.Count -2
    $DiskNumber = $CurrentLuns.Count
    
   
 #EndRegion
    
#EndRegion

#Region Create And Attach Disks

$datadiskname = $vmName.ToUpper() + '_DataDisk_'+$Lun
Write-Host "Disk will be named "$DataDiskName.ToUpper()" in Azure" -ForegroundColor Yellow

Write-host "Creating Disk $Disk in Azure" -ForegroundColor Yellow
$diskConfig = New-AzureRmDiskConfig -SkuName $sku -Location $location -CreateOption Empty -DiskSizeGB $DiskSize
$dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName

Write-Host "Disk $Disk created, adding to "$VmName.ToUpper()"" -ForegroundColor Yellow
$vm = Get-AzureRmVM -Name $VMName -ResourceGroupName $rgName
$vm = Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun $Lun

Write-Host "Updating "$Vmname.ToUpper()"" -ForegroundColor Yellow
Update-AzureRmVM -VM $VM -ResourceGroupName $rgName
Write-Host "Disk $Disk successfully created and added to VM"

#Region Attach and Label Disk
Invoke-Command -Session $Session -ScriptBlock {

Write-Host "Verifying the OS of $using:VmName recognises the new disk" -ForegroundColor Yellow

do {
    try{    
    Get-Disk -Number $Using:DiskNumber -ErrorAction Stop
    $DiskFound = $true 
            }  
            catch {
    $DiskFound = $false
    }
    } 
    while ($DiskFound -eq $false)


Write-Host "Initializing Disk...." -ForegroundColor Yellow
do {
    try{    
    Get-Disk -Number $Using:DiskNumber -ErrorAction Stop
    $DiskFound = $true 
            }  
            catch {
    $DiskFound = $false
    }
    } 
    while ($DiskFound -eq $false)
Initialize-Disk -Number $Using:DiskNumber -PartitionStyle MBR -Confirm:$false

Write-Host "Creating New Partition...." -ForegroundColor Yellow
New-Partition -DiskNumber $Using:DiskNumber -DriveLetter $Using:DriveLetter -UseMaximumSize

#Wait for Parition to be created
do  {
try {
Get-Partition -DriveLetter $Using:Driveletter -ErrorAction Stop
$VolumeFound = $true
        }
        catch {
$VolumeFound = $false
         }
 
}
    while ($VolumeFound -eq $false )

Write-Host "Formatting Volume on Disk $Using:Disk and labelling $Using:DriveLabel" -ForegroundColor Yellow
Format-Volume -DriveLetter $Using:driveletter -NewFileSystemLabel $Using:DriveLabel -FileSystem NTFS -Confirm:$false

Write-Host "Disk $Using:Disk has been succesffully installed" -ForegroundColor Green
}
start-sleep -Seconds 5
#EndRegion






#End Disk Loop
}

#Clean Up Tasks
Write-host "Removing PSSession on $VMname and deleting Temp File" -ForegroundColor Yellow
Remove-Item -Path $path\Disk_$VMname.txt -Force
Remove-PSSession -Session $Session
Start-Sleep -Seconds 5
Write-Host "All Done! Please Come Again :)" -ForegroundColor Green

#EndRegion




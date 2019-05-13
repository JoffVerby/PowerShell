

#Region Vars + Azure Login + PSSession
Write-Host "This script is used for deploying SQL Servers in Azure" -ForegroundColor Green
Write-Host "Please Login to Azure" -ForegroundColor Yellow
Connect-AzureRmAccount
$Credential = Get-Credential

$sku = 'StandardSSD_LRS'
#Endregion

#Region Set VM + Info
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
    #EndRegion
#Session
$Session = New-PSSession -ComputerName $VMName -Credential $Credential
#EndRegion

#Region Computer Description

    $ComputerDescription =  Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $VMName | Select-Object Description

if (!$ComputerDescription.Description) {
    $ComputerDescription = "Azure SQL Server"
    Write-Host "Setting Computer Description as $ComputerDescription on Computer"
    Start-Sleep -Seconds 1
    Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $VMName | Set-CimInstance -Property @{Description = $ComputerDescription}
    #Set Computer Description on AD
    Write-Host "Setting Computer Description as $ComputerDescription on AD"
    Set-ADComputer -Identity $VMName -Description $ComputerDescription
}
#EndRegion

#Region Page File faff
Write-host "Configuring Page File Settings and renaming D Drive, this will be followed by a reboot or two" -ForegroundColor Yellow
Write-Host "Setting Page file on C Drive..." -ForegroundColor Yellow
New-CimInstance -ComputerName $vmanme -class Win32_PageFileSetting -Arguments @{ Name = "c:\pagefile.sys"; InitialSize = 0; MaximumSize = 0; } -ErrorAction SilentlyContinue
Write-Host "Removing Page File from D Drive..." -ForegroundColor Yellow
$removePF = Get-CimInstance win32_pagefilesetting -ComputerName $vmname  | Where-Object {$_.Name -eq "D:\pagefile.sys"}
$removePF | Remove-CimInstance

#Reboot
Write-Host "Rebooting $($VmName.ToUpper())" -ForegroundColor Yellow

$SessionTest = "false"
do {
if ($Session.Availability -eq "Available") {   
    Invoke-Command -Session $Session -ScriptBlock {shutdown -r -t 0 -f } -ErrorAction SilentlyContinue
    $SessionTest = "true"
    }

else {
    $Session = New-PSSession -ComputerName $VMName -Credential $Credential
}
}
until ($SessionTest -eq $true)


Start-Sleep -Seconds 4

do {
    $pingtest = "false"
    $ping = Test-Connection -ComputerName $VMName -Quiet -Count 2
    
    if ($ping -eq "True") {
        Write-Host "$($VmName.ToUpper()) is back, waiting for RDP Services..." -ForegroundColor Yellow
        $pingtest = "True"
        }
    else {
        Write-Host "Waiting for $($VmName.ToUpper()) to reboot..." -ForegroundColor Yellow
    }    
    
    
} until ($pingtest -eq $true)

#Test RDP is back

do {
    $RDP = Test-NetConnection -ComputerName $vmname -CommonTCPPort RDP -WarningAction SilentlyContinue
    $RDPTest = "False"
    
    if ($RDP.TcpTestSucceeded -eq "True" ) {
        Write-Host "RDP Service has returned on $($VmName.ToUpper())" -ForegroundColor Yellow
        $RDPTest = "True"

    }
    else {
        Write-Host "Waiting for RDP Services on $($VmName.ToUpper())" -ForegroundColor Yellow
    }
    
} until ($RDPTest -eq $true)

Write-Host "Changing D drive to P Drive..." -ForegroundColor Yellow
$drive = Get-CimInstance -ComputerName $vmname -ClassName Win32_volume -Filter "DriveLetter = 'D:'"
Set-CimInstance -InputObject $drive -Arguments @{DriveLetter="P:";Label="PageFile"}

Write-Host "Setting Page File on P Drive..." -ForegroundColor Yellow
New-CimInstance -ComputerName $vmname Win32_PageFileSetting -Arguments @{ Name = "p:\pagefile.sys"; InitialSize = 0; MaximumSize = 0; } -ErrorAction SilentlyContinue
Write-Host "Removing Page File from C Drive..." -ForegroundColor Yellow
$removePF = Get-CimInstance win32_pagefilesetting -ComputerName $vmname  | Where-Object {$_.Name -eq "c:\pagefile.sys"}
$removePF | Remove-CimInstance

#Reboot
Write-Host "Rebooting $($VmName.ToUpper())" -ForegroundColor Yellow

$SessionTest = "false"
do {
if ($Session.Availability -eq "Available") {   
    Invoke-Command -Session $Session -ScriptBlock {shutdown -r -t 0 -f } -ErrorAction SilentlyContinue
    $SessionTest = "true"
    }

else {
    $Session = New-PSSession -ComputerName $VMName -Credential $Credential
}
}
until ($SessionTest -eq $true)


Start-Sleep -Seconds 4

do {
    $pingtest = "false"
    $ping = Test-Connection -ComputerName $VMName -Quiet -Count 2
    
    if ($ping -eq "True") {
        Write-Host "$($VmName.ToUpper()) is back, waiting for RDP Services..." -ForegroundColor Yellow
        $pingtest = "True"
        }
    else {
        Write-Host "Waiting for $($VmName.ToUpper()) to reboot..." -ForegroundColor Yellow
    }    
    
    
} until ($pingtest -eq $true)

#Test RDP is back

do {
    $RDP = Test-NetConnection -ComputerName $vmname -CommonTCPPort RDP -WarningAction SilentlyContinue
    $RDPTest = "False"
    
    if ($RDP.TcpTestSucceeded -eq "True" ) {
        Write-Host "RDP Service has returned on $($VmName.ToUpper())" -ForegroundColor Yellow
        $RDPTest = "True"

    }
    else {
        Write-Host "Waiting for RDP Services on $($VmName.ToUpper())" -ForegroundColor Yellow
    }
    
} until ($RDPTest -eq $true)


#EndRegion


#EndRegion

    #Region Set Azure Resource Group
    Write-Host "Setting Azure Resource Group...." -ForegroundColor Yellow
    $ResourceGroup =  Get-AzureRmVm | Where-Object {$_.Name -eq $VMName} | Select-Object ResourceGroupName
    $rgName = $ResourceGroup.ResourceGroupName
    Start-Sleep -Seconds 1
    Write-host "Resource Group Set to $rgname" -ForegroundColor Green

    #EndRegion

        #Region Set Location
    Write-Host "Setting Azure Location...." -ForegroundColor Yellow
    $Setlocation = get-azurermvm -ResourceGroupName $rgName -Name $VMName
    $Location = $Setlocation.Location
    start-sleep -Seconds 1
    Write-Host "Location set to $($Location.ToUpper())" -ForegroundColor Green
    #EndRegion
#EndRegion

#Region Check Max Disks
    #Max number of disks to add
    $VMinfo = Get-AzureRmVM -ResourceGroupName $rgName -Name $VMName
    Write-Host "Checking VM Size...." -ForegroundColor Yellow
    $VMSize = $VMinfo.HardwareProfile.VmSize
    $MaxDisk = Get-AzureRmVMSize -ResourceGroupName $ResourceGroup.ResourceGroupName -VMName $VMName | Where-Object {$_.Name -eq "$vmsize"}
    $MaxDisk = $MaxDisk.MaxDataDiskCount
    Start-Sleep -Seconds 1
    if ($MaxDisk -lt 4) {
        Write-Host "$vmname cannot be configured as a SQL Server as it is the wrong size, please resize the VM and try running the script again" -ForegroundColor Red
        }
else { Write-Host "$($VmName.ToUpper()) size is $VMSize, disks can be added..." -ForegroundColor Green
#EndRegion 

#Region CD Drive to Z
Write-Host "Changing CD Drive from E to Z" -ForegroundColor Yellow
$CDdrive = Get-CimInstance -ComputerName $vmname -ClassName Win32_volume -Filter "DriveLetter = 'E:'"
Set-CimInstance -InputObject $CDdrive -Arguments @{DriveLetter="Z:"}
#EndRegion

#Region Create and attach Disks
foreach ($a in 0..5){
if ($a -eq 0) {

    Write-host "Creating First Disk..." -ForegroundColor Yellow
    $datadiskname = $($vmName.ToUpper()) + '_DataDisk_'+$a

    $diskConfig = New-AzureRmDiskConfig -SkuName $sku -Location $location -CreateOption Empty -DiskSizeGB 100
    $dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName
    
    $vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName 
    $vm = Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 0
    
    Update-AzureRmVM -VM $vm -ResourceGroupName $rgName


}

elseif ($a -eq 1) {

    Write-Host "Creating Second Disk..." -ForegroundColor Yellow
    $datadiskname = $($vmName.ToUpper()) + '_DataDisk_'+$a

    $diskConfig = New-AzureRmDiskConfig -SkuName $sku -Location $location -CreateOption Empty -DiskSizeGB 50
    $dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName
    
    $vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName 
    $vm = Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 1
    
    Update-AzureRmVM -VM $vm -ResourceGroupName $rgName
    
}

elseif ($a -eq 2) {

    Write-Host "Creating Third Disk..." -ForegroundColor Yellow
    $datadiskname = $($vmName.ToUpper()) + '_DataDisk_'+$a

    $diskConfig = New-AzureRmDiskConfig -SkuName $sku -Location $location -CreateOption Empty -DiskSizeGB 50
    $dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName
    
    $vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName 
    $vm = Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 2
    
    Update-AzureRmVM -VM $vm -ResourceGroupName $rgName
    
}

elseif ($a -eq 3){
    Write-Host "Creating Fourth Disk..." -ForegroundColor Yellow
    $datadiskname = $($vmName.ToUpper()) + '_DataDisk_'+$a

    $diskConfig = New-AzureRmDiskConfig -SkuName $sku -Location $location -CreateOption Empty -DiskSizeGB 50
    $dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName
    
    $vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName 
    $vm = Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 3
    
    Update-AzureRmVM -VM $vm -ResourceGroupName $rgName
}


elseif ($a -eq 4){
    Write-Host "Creating Fith Disk..." -ForegroundColor Yellow
    $datadiskname = $($vmName.ToUpper()) + '_DataDisk_'+$a

    $diskConfig = New-AzureRmDiskConfig -SkuName $sku -Location $location -CreateOption Empty -DiskSizeGB 60
    $dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName
    
    $vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName 
    $vm = Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 4
    
    Update-AzureRmVM -VM $vm -ResourceGroupName $rgName
}

else{
    Write-Host "Creating Sixth Disk..." -ForegroundColor Yellow
    $datadiskname = $($vmName.ToUpper()) + '_DataDisk_'+$a

    $diskConfig = New-AzureRmDiskConfig -SkuName $sku -Location $location -CreateOption Empty -DiskSizeGB 100
    $dataDisk1 = New-AzureRmDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $rgName
    
    $vm = Get-AzureRmVM -Name $vmName -ResourceGroupName $rgName 
    $vm = Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun 5
    
    Update-AzureRmVM -VM $vm -ResourceGroupName $rgName
}


}
#EndRegion

#Region Initialise Disks
$SessionTest = "false"
do {
if ($Session.Availability -eq "Available") {   
    Invoke-Command -Session $Session -ScriptBlock {

        foreach ($disk in 2..7) {
         
        ##Initialise First Disk
            if ($disk -eq 2) {
        
            $DiskNumber = '2'
            $DriveLetter = 'D'
            $FileSystemLabel = 'Data'
        
            do {
            try{    
            Get-Disk -Number $DiskNumber -ErrorAction Stop
            $DiskFound = $true 
                    }  
                    catch {
            $DiskFound = $false
            }
            } 
            while ($DiskFound -eq $false)
        
            Write-Host "Initializing Disk..." -ForegroundColor Yellow
            Initialize-Disk -Number $DiskNumber -PartitionStyle MBR
            Start-Sleep -Seconds 5
            Write-Host "Creating Partition..." -ForegroundColor Yellow
            New-Partition -DiskNumber $DiskNumber -DriveLetter $DriveLetter -UseMaximumSize
            do  {
            try {
            Get-Partition -DriveLetter $driveletter -ErrorAction Stop
            $VolumeFound = $true
                    }
                    catch {
            $VolumeFound = $false
                     }
             
        }
                    while ($VolumeFound -eq $false )
            Write-Host "Formatting Volume and setting Drive as Driveletter $DriveLetter and Drive Label as $FileSystemLabel" -ForegroundColor Yellow        
            Format-Volume -DriveLetter $driveletter -NewFileSystemLabel $FileSystemLabel -FileSystem NTFS
            Start-Sleep -Seconds 10
            }
        
        ##Initialise Second Disk
            elseif ($disk -eq 3) {
        
            $DiskNumber = '3'
            $DriveLetter = 'E'
            $FileSystemLabel = 'Applications'
            
            do {
                try{    
                Get-Disk -Number $DiskNumber -ErrorAction Stop
                $DiskFound = $true 
                        }  
                        catch {
                $DiskFound = $false
                }
                } 
                while ($DiskFound -eq $false)
            
            Write-Host "Initializing Disk..." -ForegroundColor Yellow    
            Initialize-Disk -Number $DiskNumber -PartitionStyle MBR
            Start-Sleep -Seconds 5
            Write-Host "Creating Partition..." -ForegroundColor Yellow
            New-Partition -DiskNumber $DiskNumber -DriveLetter $DriveLetter -UseMaximumSize
            do  {
            try {
            Get-Partition -DriveLetter $driveletter -ErrorAction Stop
            $VolumeFound = $true
                    }
                    catch {
            $VolumeFound = $false
                     }
             
        }
                    while ($VolumeFound -eq $false )
                    
            Write-Host "Formatting Volume and setting Drive as Driveletter $DriveLetter and Drive Label as $FileSystemLabel" -ForegroundColor Yellow        
            Format-Volume -DriveLetter $driveletter -NewFileSystemLabel $FileSystemLabel -FileSystem NTFS
            Start-Sleep -Seconds 10
            }
        
        ##Initialise Third Disk
        elseif ($disk -eq 4) {
        
            $DiskNumber = '4'
            $DriveLetter = 'L'
            $FileSystemLabel = 'Logs'
            
            do {
                try{    
                Get-Disk -Number $DiskNumber -ErrorAction Stop
                $DiskFound = $true 
                        }  
                        catch {
                $DiskFound = $false
                }
                } 
                while ($DiskFound -eq $false)
            
            Write-Host "Initializing Disk..." -ForegroundColor Yellow 
            Initialize-Disk -Number $DiskNumber -PartitionStyle MBR
            Start-Sleep -Seconds 5
            Write-Host "Creating Partition..." -ForegroundColor Yellow
            New-Partition -DiskNumber $DiskNumber -DriveLetter $DriveLetter -UseMaximumSize
            do  {
            try {
            Get-Partition -DriveLetter $driveletter -ErrorAction Stop
            $VolumeFound = $true
                    }
                    catch {
            $VolumeFound = $false
                     }
             
        }
                    while ($VolumeFound -eq $false )
              
            Write-Host "Formatting Volume and setting Drive as Driveletter $DriveLetter and Drive Label as $FileSystemLabel" -ForegroundColor Yellow         
            Format-Volume -DriveLetter $driveletter -NewFileSystemLabel $FileSystemLabel -FileSystem NTFS
            Start-Sleep -Seconds 10
            }
         ##Initialise Fourth Disk     
            elseif ($disk -eq 5) {
        
            $DiskNumber = '5'
            $DriveLetter = 'S'
            $FileSystemLabel = 'SystemDB'
            
            do {
                try{    
                Get-Disk -Number $DiskNumber -ErrorAction Stop
                $DiskFound = $true 
                        }  
                        catch {
                $DiskFound = $false
                }
                } 
                while ($DiskFound -eq $false)
            
            Write-Host "Initializing Disk..." -ForegroundColor Yellow    
            Initialize-Disk -Number $DiskNumber -PartitionStyle MBR
            Start-Sleep -Seconds 5
            Write-Host "Creating Partition..." -ForegroundColor Yellow
            New-Partition -DiskNumber $DiskNumber -DriveLetter $DriveLetter -UseMaximumSize
            do  {
            try {
            Get-Partition -DriveLetter $driveletter -ErrorAction Stop
            $VolumeFound = $true
                    }
                    catch {
            $VolumeFound = $false
                     }
             
        }
                    while ($VolumeFound -eq $false )
            Write-Host "Formatting Volume and setting Drive as Driveletter $DriveLetter and Drive Label as $FileSystemLabel" -ForegroundColor Yellow        
            Format-Volume -DriveLetter $driveletter -NewFileSystemLabel $FileSystemLabel -FileSystem NTFS
            }
            ##Initialise Fith Disk     
            elseif ($disk -eq 6) {
        
                $DiskNumber = '6'
                $DriveLetter = 'U'
                $FileSystemLabel = 'TempLog'
                
                do {
                    try{    
                    Get-Disk -Number $DiskNumber -ErrorAction Stop
                    $DiskFound = $true 
                            }  
                            catch {
                    $DiskFound = $false
                    }
                    } 
                    while ($DiskFound -eq $false)
                
                Write-Host "Initializing Disk..." -ForegroundColor Yellow    
                Initialize-Disk -Number $DiskNumber -PartitionStyle MBR
                Start-Sleep -Seconds 5
                Write-Host "Creating Partition..." -ForegroundColor Yellow
                New-Partition -DiskNumber $DiskNumber -DriveLetter $DriveLetter -UseMaximumSize
                do  {
                try {
                Get-Partition -DriveLetter $driveletter -ErrorAction Stop
                $VolumeFound = $true
                        }
                        catch {
                $VolumeFound = $false
                         }
                 
            }
                        while ($VolumeFound -eq $false )
                Write-Host "Formatting Volume and setting Drive as Driveletter $DriveLetter and Drive Label as $FileSystemLabel" -ForegroundColor Yellow        
                Format-Volume -DriveLetter $driveletter -NewFileSystemLabel $FileSystemLabel -FileSystem NTFS
                }

              ##Initialise Sith Disk     
              else {
        
                $DiskNumber = '7'
                $DriveLetter = 'T'
                $FileSystemLabel = 'TempData'
                
                do {
                    try{    
                    Get-Disk -Number $DiskNumber -ErrorAction Stop
                    $DiskFound = $true 
                            }  
                            catch {
                    $DiskFound = $false
                    }
                    } 
                    while ($DiskFound -eq $false)
                
                Write-Host "Initializing Disk..." -ForegroundColor Yellow    
                Initialize-Disk -Number $DiskNumber -PartitionStyle MBR
                Start-Sleep -Seconds 5
                Write-Host "Creating Partition..." -ForegroundColor Yellow
                New-Partition -DiskNumber $DiskNumber -DriveLetter $DriveLetter -UseMaximumSize
                do  {
                try {
                Get-Partition -DriveLetter $driveletter -ErrorAction Stop
                $VolumeFound = $true
                        }
                        catch {
                $VolumeFound = $false
                         }
                 
            }
                        while ($VolumeFound -eq $false )
                Write-Host "Formatting Volume and setting Drive as Driveletter $DriveLetter and Drive Label as $FileSystemLabel" -ForegroundColor Yellow        
                Format-Volume -DriveLetter $driveletter -NewFileSystemLabel $FileSystemLabel -FileSystem NTFS
                }
        }
            
            }
    $SessionTest = "true"
    }

else {
    $Session = New-PSSession -ComputerName $VMName -Credential $Credential
}
}
until ($SessionTest -eq $true)

    Remove-PSSession $Session

    Write-Host 'All Done!!' -ForegroundColor Green
#endregion
}
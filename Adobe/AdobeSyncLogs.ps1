#Sharepoint Creds and connect
$siteUrl = "<Url to SharePoint Site>"
$listUrl = "Adobe Sync Logs"
#Azure Automation Account
$SPCredential = 'Automation Account'
$SPCred = Get-AutomationPSCredential -Name $SPCredential
#Connect to site
Connect-PnpOnline -Url $siteUrl -Credentials $SPCred

#Log Files for running
$Path = "<UNC to Log Files>"
$File = Get-ChildItem -Path $path | Where-Object { $_.Name -notmatch "Uploaded" }

##Main##
foreach ($logfile in $File) {
    $Logs = $logfile | Select-Object -ExpandProperty FullName
    #Find the lines in the log file with email addresses
    $AdobeSyncLogs = Get-Content $logs | Select-String -Pattern '@joffnet'

    #Loop through each result
    foreach ($log in ($AdobeSyncLogs -split ('`'))) {
        #The switch statements define if a user has been created / deleted or modified
        switch -WildCard ($log) {
            "*Deleting*" {
                $Action = "User Deleted"
                #Sets the User
                $start = $log.IndexOf(',') + 1
                $User = $log.Substring($start).Trimend(',')
             
            }
            "*Managing*" { 
                $Action = "User Modified"
                #Sets the User
                $start = $log.IndexOf(',') + 1
                $User = $log.Substring($start).Trimend(',')
                $User = $User.Substring(0, $User.IndexOf(','))

                #Modified Group
                switch -Wildcard ($log) { 
                    #Checks to see if any groups have been added
                    "*added: {*" {
                        $add = $log.IndexOf('added: {') + 8
                        $AddCheck = $log.Substring($add)
                        $Addman = $AddCheck.Substring(0, $AddCheck.IndexOf('}'))

                        #If more than one group had been added
                        if ($Addman -match ', ') {    
                            $twoGroups = $Addman -split (',')
                            $AddedGroups = $twoGroups -replace '(\s*[\''\}]+)'
                            $Added = $AddedGroups -join ("`n `r")
                        }
                        else {
                            $Added = $Addman -replace '[\''\}]+'
                        } 
                    }
                    "*added: set()*" {
                        $Added = $null                    
                    }
                    #Checks to see if any groups have been removed
                    "*removed: {*" {
                        $add = $log.IndexOf('removed: {') + 11
                        $remman = $log.Substring($add)
                        #If more than one group has been removed
                        if ($remman -match ', ') {
                            $twoGroups = $remman -split (',')
                            $RemovedGroups = $twoGroups -replace '(\s*[\''\}]+)'
                            $removed = $RemovedGroups -join ("`r `n")
                        }
                        else {
                            $Removed = $remman -replace '[\''\}]+'
                        }            
                    }         
                    "*removed: set()*" {
                        $Removed = $null       
                    }
                }
            }
            "*Creating*" {  
                $Action = "User Created"
                $start = $log.IndexOf(',') + 1
                $User = $log.Substring($start).Trimend(',')            
            }
        }
        #Uploads to sharepoint
        $AddToList = Add-PnPListItem -List $listUrl -Values @{
             
            "User"    = $user
            "Action"  = $Action
            "Removed" = $Removed;
            "Added"   = $Added;
        }
        #Clear Variables
        if ($Removed) { Clear-Variable Removed }
        if ($Added) { Clear-Variable Added }
    }
    #Log File Management
    $NewFile = $false
    $i = 0
    do {
        try {    
            Rename-Item $logfile.FullName -NewName "$($logfile.basename)_Uploaded.log" -Force -ErrorAction Stop
            $NewFile = $true
        } 
        catch {
            $i++
            try {
                Rename-Item $logfile.FullName -NewName "$($logfile.basename)_Uploaded$i.log" -Force -ErrorAction Stop
                $NewFile = $true
            }
            catch { $NewFile = $false }
        }
    } until ($NewFile -eq "True")

}
    #Log file clean up
    $limit = (Get-Date).AddDays(-60)
    Get-ChildItem -Path $Path | Where-Object { $_.CreationTime -lt $limit } | Remove-Item -Force     



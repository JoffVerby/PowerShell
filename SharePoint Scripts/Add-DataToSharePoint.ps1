function Add-DataToSharePoint {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(ValueFromPipeline, Mandatory)]
        [Object]$Server,
        [Parameter(ValueFromPipeline)]
        [string]$list = <Default List>,
        [Parameter(ValueFromPipeline)]
        [string]$url
    )
    begin {
        #Region Functions
        function Set-SPMultiChoice {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory, ValueFromPipeline)]
                [object]$Property
            )
            process {
                if ($property.Value) {
                    switch ($property.Value) {
                        True {
                            $Server.($property.name) = 'Yes'
                            continue
                        }
                        False {
                            $Server.($property.name) = 'No'
                            continue
                        }
                        YES {
                            $Server.($property.name) = 'Yes'
                            continue
                        }
                        NO {
                            $Server.($property.name) = 'No'
                            continue
                        }
                    }
                }
            }
        }
        #EndRegion
        #Region Connect to SharePoint and List
        try {
            if ($url) {
                Connect-PnPOnline -Url $url -UseWebLogin
            }
        }
        catch {
            Write-Error "Cannot connect to site $($url)"
            break
        }
        if (-not($list)) {
            $list = Read-Host "Please Enter the name of the SharePointList"
        }
        #Chceck if list exists in site
        if ($list -notin $(Get-PnPList).title) {
            Write-Error "$($list) does not exist in SharePoint Site $($URL)"
            break
        }
        #EndRegion
        #Region Logging path
        $logPath = 'C:\temp\SPUpload.log'
        $CheckLogPath = Test-Path $logPath
        if (-not($CheckLogPath)) {
            try {
                New-Item -Path $logPath -Force -ErrorAction Stop | Out-Null
                Write-Verbose "Created Log path at $($logPath)"
                $logging = $true
            }
            catch {
                Write-Warning "A log file for this job could not be created"
                $logging = $false
            }
        }
        #EndRegion
    }
    process {
        #What if handling
        if ($PSCmdlet.ShouldProcess(($Server.Hostname), "Adding to $($list)")) {
            try {
                #Handle the Yes / No Values
                $properties = $server.psobject.Members
                foreach ($Property in $properties) {
                    Set-SPMultiChoice -property $Property
                }
                Add-PnPListItem -List $list -Values @{
    
                    "Ad"                     = $Server.Ad
                    "Address"                = $Server.Server_Address
                    "Backup"                 = $Server.Backup
                    "City"                   = $Server.City
                    "Cluster"                = $Server.Cluster
                    "CommvaultVerified"      = $Server.CommvaultVerified
                    "Contact"                = $Server.Contact
                    "Country_x002d_State"    = $Server.'Country/State'
                    "DataType"               = $Server.'Data Type'
                    "DataStore"              = $Server.DataStore
                    "GeoLoc"                 = $Server.GeoLoc
                    "Hostname"               = $Server.Hostname
                    "IP"                     = $Server.IP
                    "LeanIXBusinessCritical" = $Server.LeanIXBusinessCritical
                    "Manufacturer"           = $Server.Manufacturer
                    "Name"                   = $Server.Name
                    "Notes"                  = $Server.Notes
                    "OperatingSystem"        = $Server.OperatingSystem
                    "OracleCloudBackup"      = $Server.OracleCloudBackup
                    "Pingable"               = $Server.Pingable
                    "PowerState"             = $Server.PowerState
                    "Production"             = $Server.Production
                    "ResourcePool"           = $Server.ResourcePool
                    "SnapMirror"             = $Server.SnapMirror
                    "Type"                   = $Server.Type
                    "UsedSpaceGB"            = $Server.UsedSpaceGB
                    "Varonis"                = $Server.Varonis
                    "Veeam"                  = $Server.Veeam
      
                } -ErrorAction Stop
               if ($logging) {
                    Write-Output "Succecfully added $($server.hostname) to $($list)" | Out-File $logPath -Append
                }
            }
            catch {
                Write-Warning "there was a problem adding $($server.hostname)"
                if ($logging) {
                    Write-Output "Problem adding $($server.hostname), see below error"  $Error[0].exception.message | Out-File $logPath -Force -Append
                }
            }
        }
    
    }
    end {
    }
}

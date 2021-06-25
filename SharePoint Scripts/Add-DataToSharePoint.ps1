function Add-CommVaultToSharePoint {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # Parameter help description
        [Parameter(ValueFromPipeline, Mandatory)]
        [Object]$Server,
        [Parameter(ValueFromPipeline)]
        [string]$list = 'CommVault Audit',
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
        $list = $list
        #End Region
    }
    process {
        #What if Syntax
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
            }
            catch {
                Write-Warning "there was a problem adding $($server.hostname), see logs for details"
                Write-Output "Problem adding $($server.hostname), see below error"  $Error[0].exception.message | Out-File C:\temp\spUpLoadError.log -Force -Append
            }
        }
    
    }
    end {
    }
}

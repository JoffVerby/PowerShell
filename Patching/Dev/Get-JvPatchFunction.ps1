
function get-JVPatchList {
    [CmdletBinding()]
    param (
        [string] $Path
        
    )
    $Servers = Get-Content -Path $Path

#Action on each server
foreach ($server in $Servers) {

#Ping Test
$pingtest = Test-Connection -ComputerName $server -Count 2 -Quiet
if ($pingtest -eq $false) {
    $ping = ($server)+" is not Pinging"}
    else {
     $ping = ($server)+" Is Pinging"   
    }
    $PingResult = $ping

#Get Server Information    
try {
    $info = Get-ADComputer -Identity $server -Properties Name,Description,Operatingsystem | Select-Object Name,Description,Operatingsystem
    
        $Description =  $info.Description
        $OS =           $info.Operatingsystem
    }
catch {
        $Description =  "Cannot Find $Server in AD"
        $OS =           "Cannot Find $Server in AD"
    }

#Build the table    
$PatchList = New-Object psobject -Property @{

        Server =        $server
        Description =   $Description
        OS  =           $OS
        PingResult =    $PingResult
}
#Output
$PatchList | Export-Csv C:\Temp_Test\Patchtest.csv -Append -NoTypeInformation

}
}

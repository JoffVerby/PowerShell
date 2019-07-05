#This function finds the Security groups of a specified directory and allows the user of the function to add users to it
function Add-JvSecurityGroup {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        #Validate that directy exists, if not throws terminating error
        [ValidateScript({
            if (-not(Test-Path -Path $_ -PathType Container)) {
                throw "The folder [$_] does not exist"
            }
            else
            {
                $true    
            }
         })]
         #Validates that the path begins with "<ShareNameConvention>"
        [ValidatePattern('^\\\\<NetworkShareLocation>')]
        [string]$Path
    )
    
    begin {
        Write-Host "`n$Path has been set as the path `n `n Getting Security Groups and Users`n" -ForegroundColor Green
    }
    process {
    #get the groups of the directory    
    $ALL = Get-Acl -Path $Path
    
    #selects the group name, the level of access and only returns Domain accounts and removes Domain Admin Group 
    #Will only display groups with the naming security group naming conventions
    $Groups = $all.Access | Select-Object IdentityReference,FileSystemRights | Where-Object {(($_.IdentityReference.value) -match ('^<domainName>\\') -and ($_.IdentityReference.value -notlike '<DomainName>\Domain Admins') -and ($_.IdentityReference.value -match ('^<SecGroupNamingConvention>')))  }  

    #Build the Menu
    #exit number used for exit option in menu
    $exitnumber = $Groups | Measure-Object | Select-Object Count
    $i=0
    $menuoptions = @()
    foreach ($thing in $groups) {$i++ 
    $menuoptions += New-Object Psobject -Property @{

    Group           =   $($thing.IdentityReference.Value)
    AccessRights    =   $($thing.FileSystemRights) 
    Option          =   $i  
    }
    #builds in the exit option after the last group
    if ([int]$i -eq $exitnumber){
    $menuoptions += New-Object Psobject -Property @{
    Option          =   [int]$exitnumber+1
    Group           =   "Exit"    
    }
}
}
#ask which users to add
Write-Host "Please choose which group to add Users to" -ForegroundColor Green
$menuoptions | Format-Table Option,Group,AccessRights -AutoSize
#Ask user to select which group number
$selectgroup = Read-Host "Group Number"
#exits the script if exit is chosen
if ($selectgroup -eq [int]$exitnumber+1) {
    break
    }
#Corrospond the number selected to the option in the menu
$selectedgroupnumber = [int]$selectgroup -1
$selectedgroup = $menuoptions[$selectedgroupnumber].group.Substring(6)

#Ask the user for the user name(s) to add to group
do {$success = $false
    $users = Read-host "Enter the samAccountName(s) to add to $selectedGroup seperated by commas (q to exit)"
    #escape option
    if ($users -eq 'q'){break}
    Write-Host "Adding $users to $selectedgroup"
    #takes the samaccount names entered and splits them into seperate objects
    $UserMethod = $users.Split(',')
    #error handling variable if user is alread in group
    $UserExist = Get-ADGroupMember $selectedgroup
    foreach ($person in $UserMethod){
        $successname = Get-ADUser $person | Select-Object Name
        if($person -in $UserExist.samAccountName)
            {Write-Host "$($Successname.name) is already a member of $($selectedgroup) please try again" -ForegroundColor Red}        
        else{
            try{
    #Adding the users to selected groups with error handling
                Add-ADGroupMember -Identity $selectedgroup -Members $users.Split(',')
                $success = $true
                Write-Host "$($successname.Name) has been added to $selectedgroup" -ForegroundColor Green   
                }          
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]{Write-Host "$($Person) cannot be found in AD, try again" -ForegroundColor Red}    
                $success = $false
        }
    } 
}
    
until ($success -eq $true)
}
    end {

    }
}


    


   

function Add-JvSecurityGroup {
    <#
.SYNOPSIS
Adds an AD user to an AD Group which as access to the specified path

.DESCRIPTION
Retrieves the AD groups which have permission to the UNC path specified, a menu is built
numbering the groups as options, the user can then choose the group and add the user by
samaccount name to the desired group.

.PARAMETER Path
The UNC path to the folder in the file share

.EXAMPLE
Add-JvSecurityGroup -Path "\\joffnet.org\dfs\Fincance\Reports\"
\\joffnet.org\dfs\Fincance\Reports\ has been set as the path 

Getting Security Groups

Please choose which group to add Users to

Option Group                          AccessRights
------ -----                          ------------
 1 JoffNet\FS-IS-Finance-All 	Modify, Synchronize
 2 JoffNet\FS-IS-Finance-Reports    Modify, Synchronize
 3 Exit


Group Number:
#>
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        #Validate that directy exists, if not throws terminating error
        [ValidateScript( {
                if (-not(Test-Path -Path $_ -PathType Container)) {
                    throw "The folder [$_] does not exist"
                }
                else {
                    $true    
                }
            })]
        #Validates that the path begins with "<ShareNameConvention> - leave as '\\\\' to validate any UNC Path"
        [ValidatePattern('^\\\\')]
        [string]$Path
    )

    begin {
        Write-Host "`n$Path has been set as the path `n `n Getting Security Groups and Users`n" -ForegroundColor Green
        #Region Domain Vars
        $domainName = (Get-ADDomain).NetBiosName
        $domainNameCount = $domainName.Length + 1
        #endregion
    }
    process {
        #get the groups of the directory    
        $ALL = Get-Acl -Path $Path

        #selects the group name, the level of access and only returns Domain accounts and removes Domain Admin Group 
        #Will only display groups with the naming security group naming conventions
        $Groups = $all.Access | Select-Object IdentityReference, FileSystemRights | Where-Object { (($_.IdentityReference.value) -match ("^$domainName") -and ($_.IdentityReference.value -notlike "*Domain Admins*") -and ($_.IdentityReference.value -match ("^$domainName\\LDN"))) }  

        #Build the Menu
        #exit number used for exit option in menu
        $exitnumber = ($Groups | Measure-Object).Count + 1
        $i = 0
        $menuoptions = @()
        foreach ($groupName in $groups) {
            $i++ 
            $menuoptions += New-Object Psobject -Property @{

                Group        = $($groupName.IdentityReference.Value)
                AccessRights = $($groupName.FileSystemRights) 
                Option       = $i  
            }
            #builds in the exit option after the last group
            if (($i + 1) -eq $exitnumber) {
                $menuoptions += New-Object Psobject -Property @{
                    Option = $exitnumber
                    Group  = "Exit"    
                }
            }
        }
        #ask which users to add
        Write-Host "Please choose which group to add Users to" -ForegroundColor Green
        $menuoptions | Format-Table Option, Group, AccessRights -AutoSize
        #Ask user to select which group number
        $selectgroup = Read-Host "Group Number"
        #exits the script if exit is chosen
        if ($selectgroup -eq $exitnumber) {
            break
        }
        #Corrospond the number selected to the option in the menu
        $selectedgroupnumber = [int]$selectgroup - 1
        $selectedgroup = $menuoptions[$selectedgroupnumber].group.Substring($domainNameCount)

        #Ask the user for the user name(s) to add to group
        do {
            $success = $false
            $users = Read-host "Enter the samAccountName(s) to add to $selectedGroup seperated by commas (q to exit)"
            #escape option
            if ($users -eq 'q') { break }
            Write-Host "Adding $users to $selectedgroup"
            #takes the samaccount names entered and splits them into seperate objects
            $UserMethod = $users.Split(',')
            #error handling variable if user is alread in group
            $UserExist = Get-ADGroupMember $selectedgroup
            foreach ($person in $UserMethod) {
                $successname = Get-ADUser $person | Select-Object Name
                if ($person -in $UserExist.samAccountName)
                { Write-Host "$($Successname.name) is already a member of $($selectedgroup) please try again" -ForegroundColor Red }        
                else {
                    try {
                        #Adding the users to selected groups with error handling
                        Add-ADGroupMember -Identity $selectedgroup -Members $users.Split(',')
                        $success = $true
                        Write-Host "$($successname.Name) has been added to $selectedgroup" -ForegroundColor Green   
                    }          
                    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { Write-Host "$($Person) cannot be found in AD, try again" -ForegroundColor Red }    
                    $success = $false
                }
            } 
        }

        until ($success -eq $true)
    }
    end {

    }
}
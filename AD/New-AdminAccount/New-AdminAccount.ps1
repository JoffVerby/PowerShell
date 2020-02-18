function New-AdminAccount {
    <#
    .SYNOPSIS
        Creates Network Admin Accounts for Users
    .DESCRIPTION
        Admins will use the -User Parameter with the samaccount name of the user who requires an admin account.
        The function will incrament a value of 1 to the samaccountname until it finds one available and will append display name etc
    .PARAMETER User
        The SamAccountName of the users' current standard account
    .PARAMETER OU
        The Organisational Unit of where the Admin will be.
    .EXAMPLE
        PS C:\> New-CRUKAdminAccout -User verbyj01 -OU ServiceDesk
        Creates a new Admin account for the user with non-admin account verbyj01 in The Service Desk OU
    #>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory)]
        [string]$User,

        [Parameter(Mandatory)]
        [ValidateSet("AppManagement", "CRT", "DBA", "Developers", "Security", "ServiceDesk", "SharePointAdmins", "WebTeam")]
        [string]$OU
        
    )

    process {
        # Check for existing current Account
        try {
            $current = Get-ADUser $user
        }
        catch {
            throw $Error[0]
            break
        }
        #Get Displayname and append "(Admin Account)"
        $Disp = ($current).Name + " (Admin Account)"
        #Split the samaccount name into text and numbers, incrament account number by 1
        $samText = ($user -split '(?=\d)', 2)[0]
        $samNumber = [int]($user -split '(?=\d)', 2)[1]
        $samNumber++
      
        #Check for numbers less than 10 to handle the leading "0"
        if ($samNumber -lt 10) {

            $samNumber = ("{0:00}" -f $samNumber)
          
        }
        #Set the new SamAccount name
        $adminSam = $samText + $samNumber
        #Account Password
        $pass = [System.Web.Security.Membership]::GeneratePassword(24, 5)
        $securePass = $pass | ConvertTo-SecureString -AsPlainText -Force
        #OU Selection
        switch ($OU) {
            AppManagement       { $userOU = "OU=Application Management,OU=Administrators,DC=joffnet,DC=org" }
            DBA                 { $userOU = "OU=DBA,OU=Administrators,OU=Administrators,DC=joffnet,DC=org" }
            Developers          { $userOU = "OU=Developers,OU=Administrators,OU=Administrators,DC=joffnet,DC=org" }
            Security            { $userOU = "OU=Security,OU=Administrators,OU=Administrators,DC=joffnet,DC=org" }
            ServiceDesk         { $userOU = "OU=Service Desk,OU=Administrators,OU=Administrators,DC=joffnet,DC=org" }
            SharePointAdmins    { $userOU = "OU=Sharepoint Management,OU=Administrators,DC=joffnet,DC=org" }
            SRM                 { $userOU = "OU=SRM,OU=Administrators,OU=Administrators,DC=joffnet,DC=org" }
            WebTeam             { $userOU = "OU=Web,OU=Administrators,OU=Administrators,DC=joffnet,DC=org" }
         
        }
        #Build the values for the new AD Account
        $accountParams = @()
        $accountParams = @{
            Path                  = $userOU
            Name                  = $Disp
            Displayname           = $Disp
            GivenName             = ($current).GivenName
            Surname               = ($current).Surname
            Enabled               = $true
            ChangePasswordAtLogon = $false
            Description           = "Administrator Account"
            AccountPassword       = $securePass
        }

        #Try to create the user
        $createSuccess = $false
        do {  
            try {
                New-ADUser -SamAccountName $adminSam @accountParams
                $createSuccess = $true
                $newUser = Get-ADUser $adminSam
                Write-Output "$(($newuser).Name) has been created."
            }
            #If account exists add 1 to number on samaccountname and try again
            catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
                $samNumber = [int]$samNumber
                $samNumber++
                if ($samNumber -lt 10) {

                    $samNumber = ("{0:00}" -f $samNumber)
                  
                }
                $adminSam = $samText + $samNumber

            }
            #If Name already exists
            catch [Microsoft.ActiveDirectory.Management.ADException] {
                throw $Error[0]
                break
            }
        }
        until ($createSuccess -eq $true)
        
        
    }
}

function Add-JvSecurityGroup {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [ValidatePattern('^\\\\crwin.crnet.org\\dfs')]
        [string]$Path
    )
    
    begin {
        Write-Host "`n$Path has been set as the path `n" -ForegroundColor Green
    }
    
    process {
        
    }
    
    end {
    }
}
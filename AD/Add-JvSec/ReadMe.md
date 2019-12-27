## Add-JvSec

This reusable function was born out the repative task of adding users to certain AD security groups for file share access.  Due the way permissions were structured in the Organisation the relatively simple task was done with these steps

1. Navigate to file share as admin
1. Right click, Properties, Security 
1. Find the correct AD group
1. In AD or Powershell find the User
1. Check they aren't in the group and add them

With this function it's a simple one-liner (example below, function also contains an example in the help)

``Add-JvSecurityGroup -Path <UNC PAth>``

which builds a menu in the cli.  The user of the function then simply references the numbers in the Menu to choose the groups and uses the SamAccountName of the user to add to the group.

The Function checks if the Path, User, and file share exists with error handling.

*PS - I realise that ``Write-Host`` with colours is frowned upon, I may take it out at some point in the future but if you are reasing this it means I'm still okay with it!*
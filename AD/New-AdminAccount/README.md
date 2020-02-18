# New-CRUKAdminAccount

## Powershell function for automating the creation of a new network admin account

Use example:

New-CRUKAdminAccount -User test01 -OU ServiceDesk

This function references a users current non-admin account and creates an admin account using data from the current account.  The OU selected will put the new account in the relevant OU within the "Administrators" OU

The account name and display name is appended with "(Admin Account)".  The number on the samaccountname is incramented by 1 until it finds one available.

Passwords are created securley in the script and are not in plain text, therefore you need to reset the password and send a self-destruct email to the user post creation.

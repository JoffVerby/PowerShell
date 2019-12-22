# Adobe Scripts

The AdboeSyncLogs Script was written to make something useful out of the log file which is produced by the [Adobe User Sync Tool](https://adobe-apiplatform.github.io/user-sync.py/en/)

The Code is the middle-man between the two images in this ReadMe.  It runs in an Azure Runbook using an Azure Hybrid Worker Server

The Tool outputs the .log file to a windows file share.  It looks like this:

![alt text](https://github.com/JoffVerby/PowerShell/blob/master/Media/publicAdobe.jpg)

The Script ingests the log file, strips out anything useless, and uses a lot of regex to extract the useful bits before uploading to a sharepoint list, making it look like this:

![alt text](https://github.com/JoffVerby/PowerShell/blob/master/Media/adobesharepoint-public.jpg)

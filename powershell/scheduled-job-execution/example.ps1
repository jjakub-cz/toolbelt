##
# C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
# C:\Tasks\jobs\job.ps1
# C:\Tasks\jobs\
##
Import-Module -Name C:\Tasks\utils.psm1 -Verbose -Force
     
$to = @("email1@example.com", "email2@example.com)
$name = "job-name"
     
[uri]$url = "http://localhost:64859/some-endpoint"
ExecuteApiQuery -url $url -name $name -mailTo $to -alwaysSend $false

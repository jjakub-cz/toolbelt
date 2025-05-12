    ##
    #
    # utils.psm1
    #
    # @author JJakes
    # @version 2023-05-26.v02
    #
    # Skript obsahuje obecne metody pro ucely logovani powershell skriptu. Dostupne funkce a jejich volani
    #
    # fnc "WriteLog"
    #   volani:
    #     WriteLog -LogText $str
    #   parametr:
    #     -LogText "textovy retezec"
    #
    # fnc "StringifyLog"
    #   volani:
    #     StringifyLog -Log $output
    #   parametr:
    #     -Log objekt typu "PSCustomObject"
    #   vystup:
    #     Funkce na vystupu vraci string, tedy zretezene informace z objeku
    #     vzdy ve forme key=value oddelene strednikem
    # 
    # fnc "SendEmail"
    #   volani:
    #     SendEmail -To "email@email.cz" -Subject "text predmetu e-mailu" -Body "text tela emailu
    #
    ## 
     
     
    function ExecuteApiQuery{
        param(
            [Parameter(mandatory=$true)] [uri] $url,
            [Parameter(mandatory=$true)] [string] $name, 
            [Parameter(mandatory=$true)] [string[]] $mailTo,
            [Parameter(mandatory=$false)] [bool] $alwaysSend = $false
        )
     
        $datumCas = $(Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff")
        $userName = $env:username
        $guid = [guid]::NewGuid().Guid
        $chyba = $false
     
        Try {
            $StartTime = $(get-date)
            $response = Invoke-WebRequest -Uri $url.OriginalString -Method Get -UseBasicParsing
            $elapsed = ("{0}" -f ($(get-date)-$StartTime))
            $status = $response.StatusCode
        } Catch {
            $chyba = $true
            if( $_.Exception.Response.StatusCode.value__ -eq $null ) {
                $status = "5xx"
            } else {
                $status = $_.Exception.Response.StatusCode.value__
            }
            $response = $Error[0].Exception
        }
        WriteLog -LogText "time=""$datumCas"", job=""$name"", guid=""$guid"", status=""$status"", response=""$response""" -LogFile $name
     
        # tady zajistime poslani emailu
        $sc = [string]($MyInvocation.ScriptName)
        $uh = $url.Host
        $up = $url.Port
        $ua = $url.AbsolutePath
        $rs = $response.StatusCode
        $emailBody = "Script: $sc `
        URL: $uh : $up : $ua `
        HTTP status: $rs `
        Execution time: $elapsed `n`nCall output: `n$response"
     
        if($chyba -eq $true) {
            SendEmail -To $mailTo -Subject "SchJob $name" -Body $emailBody
        } else {
            if($alwaysSend) {
                Write-Output "Sending e-mail because I have to"
                SendEmail -To $mailTo -Subject "SchJob $name" -Body $emailBody
            }
        }
    }
     
     
    function WriteLog {
        param(
            [string] $LogText,
            [string] $LogFile = "_"
        )
     
        $LogPath = "C:\Tasks\logs\"
        Get-ChildItem "$LogPath\*.log" | Where LastWriteTime -LT (Get-Date).AddDays(-15) | Remove-Item -Confirm:$false
        $path = Join-Path -Path $LogPath -ChildPath "ps_$LogFile-$(Get-Date -Format 'yyyy-MM-dd').log"
        Add-Content -Path $path -Value $LogText
     
    }
     
     
    function SendEmail {
        param(
            [string[]] $To,
            [string] $Subject,
            [string] $Body
        )
     
        $date = Get-Date 
     
        $EmailParameters = @{
            To = $To
            Subject = "$Subject"
            Body = "Job from server $env:computername `n$Body"
            Priority = "High"
            SmtpServer = "smtp_server_ip"
            Encoding = "UTF8"
            From = "sender_email"}
     
        send-mailmessage @EmailParameters
    }
     
     
    function StringifyLog {
        param(
             [PSCustomObject] $Log
        )
        $str = $Log | ForEach-Object { ($_.PSObject.Properties | ForEach-Object { "$($_.Name)=""$($_.Value)""" })  -join ", " } | Out-String
     
        return $str.Trim()
    }


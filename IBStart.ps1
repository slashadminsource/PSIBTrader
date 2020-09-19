

using module '.\Modules\DataStorageManager.psm1'


Write-Host "################################################################"
Write-Host "#"
Write-Host "# Watchdog powershell script for IBTrader"
Write-Host "#"
Write-Host "# Script will start the data collector and ibot scripts"
Write-Host "# Will also restart both after the daily IB Program restarts"
Write-Host "#"
Write-Host "# Will also warn you if it detects issues collecting data"
Write-Host "#"
Write-Host "################################################################"
Write-Host ""

$global:dcProcess = $null
$global:ibProcess = $null
[DataStorageManager]$global:storage = New-Object DataStorageManager

function Start-Scripts()
{
    Write-Host "Starting data collector"
    $global:dcProcess = Start-Process powershell -argument ".\IBDataCollector.ps1 -AutoStart $true" -passthru
    $global:dcProcess.id
    Start-Sleep -Seconds 60
    Write-Host "Done"

    Write-Host "Starting bot"

    $global:ibProcess = Start-Process powershell -argument ".\IBBot.ps1" -passthru
    $global:ibPprocess.id
    Start-Sleep -Seconds 60
    Write-Host "Done"
}

function Restart-Scripts()
{
    Write-Host "Stopping scripts ready for restart"
    Stop-Process $global:dcProcess.Id
    Stop-Process $global:ibProcess.Id
    Write-Host "Done"
    Write-Host "Waiting 20 minutes before restart"
    Start-Sleep -Seconds 600
    Write-Host "Done.. Restarting scripts"
    Start-Scripts
}

function Start-DataCollectionChecks()
{
     Write-Host "Starting data collection checks"

     $stocks = $global:storage.GetStocks()

     foreach($stock in $stocks)
     {
        Write-host "Stock:" $stock.symbol
        $lastPrice = $global:storage.GetLastPriceDate($stock.symbol)
               
        $currentTime = Get-Date
        $diff = New-TimeSpan $lastPrice $currenttime
        Write-host "Last price capture time:" $lastPrice -ForegroundColor Red
        Write-host "current time:" $currentTime -ForegroundColor Red
        Write-host "diff minutes:" $diff.TotalMinutes -ForegroundColor Red

        if($diff.TotalMinutes -gt 30)
        {
            return $true
        }
     }

     Write-Host "Done"
     return $false
}

function Send-Mail()
{
    $notificationToEmailAddress = "ian.waters@southernit.com"
    $notificationFromEmailAddress = "psbot@bot.net"
    $smtpServer = "relay-cluster-eu01.hornetsecurity.com"
    $smtpPort = "25"
    $subject = "CRITICAL ALERT"
    $body = "Critical alert triggered on bot"
    Send-MailMessage -From $notificationFromEmailAddress -to $notificationToEmailAddress -Subject $subject -Body $body -SmtpServer $smtpServer -port $smtpPort
}

Function Check-BankHoliday 
{
    Param (
        [CmdletBinding()]
        [Parameter(Mandatory,ValueFromPipeline)][datetime]$Date
    )
    $bankHolidays = (Invoke-RestMethod -Uri "https://www.gov.uk/bank-holidays.json" -Method GET)
    $bankHolidays.'england-and-wales'.events.date -contains (Get-Date $Date -Format "yyyy-MM-dd")
}

function IsTradingHours([DateTime] $dt)
{
    $dt = $dt.AddHours(-5)

    $hour = $dt.hour
    $dayofWeek = $dt.DayofWeek.value__
    if($hour -gt 9 -and $hour -lt 15 -and $dayofWeek -gt 0 -and $dayofweek -lt 6 ) 
    {
        #Write-Host "IN TRADING HOURS" -ForegroundColor Green
        return $true

    }
    else 
    {
        #Write-Host "OUTSIDE OF TRADING HOURS" -ForegroundColor Red
        return $false

    }
}

$running = $true
Start-Scripts

While($running)
{
    $dt = Get-Date
    
    if($dt.Hour -eq 6 -and $dt.Minute -gt 55)
    {
        Restart-Scripts    
    }

    if(IsTradingHours $dt)
    {
        Write-Host "IN TRADING HOURS" -ForegroundColor Green
        if(check-bankholiday $dt)
        {
            Write-Host "OUTSIDE OF TRADING HOURS (BANK HOLIDAY)" -ForegroundColor Green
        }
        else
        {
            $badResults = Start-DataCollectionChecks

            if($badResults -eq $true)
            {
                #no data captured within 20 minutes so call for help
                Write-Host "CALLING FOR HELP" -ForegroundColor Red
                Send-Mail
                Start-Sleep -Seconds 3600
            }
        }
    }
    else
    {
        Write-Host "OUTSIDE TRADING HOURS" -ForegroundColor Red
    }
    
    #dont hog cpu
    Start-Sleep -Seconds 30
}
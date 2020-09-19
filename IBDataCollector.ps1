
using module '.\Modules\CSharpAPI.dll'
using module '.\Modules\IBClient.psm1'
using module '.\Modules\DataStorageManager.psm1'
using module '.\Modules\BlockchainExchange.psm1'


param ([switch]$autoStart = $false)


#used to detect if price updates are missing or stopped
[DateTime]$global:lastPriceCapture = Get-Date

[IBApi.EClientSocket]$global:clientSocket = $null


[IBClient]$global:wrap = $null
[IBApi.EReaderMonitorSignal]$global:signal = $null
[IBApi.EReader]$global:reader = $null


[bool]$global:running = $true
[int]$global:errorCount = 0
[int]$global:connectionErrorCount = 0
[DataStorageManager]$global:storage = New-Object DataStorageManager
################################################################################


function Setup-Display([int]$width, [int] $height)
{
    $psHost = get-host
    $window = $psHost.ui.rawui
    $newSize = $window.windowsize
    $newSize.height = $height
    $newSize.width = $width
    $window.windowsize = $newSize
}

function Read-Character()
{
    if ($Host.UI.RawUI.KeyAvailable -eq $true)
    {
        return $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
    }

    return ""
}

function Connect()
{
    $global:wrap = New-Object IBClient
    $global:signal = new-object IBApi.EReaderMonitorSignal
    $global:clientSocket = New-Object IBApi.EClientSocket($global:wrap, $global:signal)
    $global:clientSocket.eConnect("localhost",7497,0)
    
    $global:clientSocket.IsConnected()

    
    

    #wait for user to press ok to connect buttons in TWS
    start-sleep -Seconds 10

    if(  $global:clientSocket.IsConnected() -eq $false)
    {
        Write-Host "(33) ERROR CONNECTING" -ForegroundColor Red
        return $false
    }

    #$global:clientSocket.reqAccountUpdates($true,"")
    #$global:clientSocket.reqPositions()
    $global:reader = New-Object IBApi.EReader($global:clientSocket,$global:signal)
    $global:reader.Start()




    #################################
    #REQUEST PRICE UPDATE FOR A STOCK
    $global:clientSocket.reqMarketDataType(1) #switch to live (1) frozen (2) delayed (3) or delayed frozen (4)***/
    [Array]$stocks =  $global:storage.GetStocks()
    foreach($item in $stocks)
    {
        write-host $item.SYMBOL
        write-host $item.SYMBOLID
        write-host $item.POSITIONSIZE
        write-host $item.STATE
        write-host $item.STOPORDERID
        write-host $item.POSITION


        [IBApi.Contract]$contract = New-Object IBApi.Contract
        $contract.Symbol = $item.SYMBOL
        $contract.SecType = "STK"
        $contract.Currency = "USD"
        $contract.Exchange = "SMART"
        $contract.PrimaryExch = "ISLAND"
        Write-Host "REQUESTING MARKET DATA" 
        
        $global:clientSocket.reqMktData([int]$item.SYMBOLID, $contract, "", $false, $false, $null)
        start-sleep -Seconds 5
    }
    #################################




    ######################
    #REQUEST HISTORICAL MARKET DATA

    #$endSample = Get-Date
    #$startSample = $endSample.AddMinutes(-6)
    #[IBApi.Contract]$contract = New-Object IBApi.Contract
    #$contract.Symbol = "IBKR"
    #$contract.SecType = "STK"
    #$contract.Currency = "USD"
    #$contract.Exchange = "SMART"
    #$global:clientSocket.reqHistoricalData(4001, $contract, $endSample.ToString("yyyMMdd HH:mm:ss"), "1 D", "1 hour", "TRADES", 1, 1, $false, $null)

    #String queryTime = DateTime.Now.AddMonths(-6).ToString("yyyyMMdd HH:mm:ss");
    #client.reqHistoricalData(4001, ContractSamples.EurGbpFx(), queryTime, "1 M", "1 day", "MIDPOINT", 1, 1, false, null);
    #client.reqHistoricalData(4002, ContractSamples.EuropeanStock(), queryTime, "10 D", "1 min", "TRADES", 1, 1, false, null);
    ######################


    ################################
    #REQUEST LATEST BALANCE UPDATE
    #DU2195558
    #$global:clientSocket.reqAccountUpdates($true,"DU2195558")
    #$global:clientSocket.reqPositions()
    ################################

}

################################################################################

Setup-Display 125 40
Clear-Host

$global:running = $true

if($autoStart -eq $false)
{
    Write-Host ""
    Write-Host "#########################################" -ForegroundColor Blue
    Write-Host ""
    Write-Host "DATA COLLECTOR" -ForegroundColor Blue
    Write-Host ""
    Write-Host "PRESS C TO CREATE A NEW DATABASE" -ForegroundColor Blue
    Write-Host "PRESS S TO START COLLECTING DATA" -ForegroundColor Blue
    Write-Host ""
    Write-Host "#########################################" -ForegroundColor Blue
    Write-Host ""

    while($global:running)
    {
        $char = Read-Character

        if($char -eq 'c')
        {
            Write-Host "CREATING SQL DATABASE" -ForegroundColor Blue
            $global:storage.CreateDatabase()
            Write-Host "DONE" -ForegroundColor Green
            $Host.UI.RawUI.FlushInputBuffer()
        }
        elseif($char -eq 's')
        {
            $global:running = $false
            Write-Host "STARTING." -ForegroundColor Blue
            $Host.UI.RawUI.FlushInputBuffer()
        }
    }
}
else
{
    Write-Host "Autostart enabled.."
}

$global:running = $true
$connected = Connect

if($connected -eq $true)
{
    write-host "ENTERED RUNNING STATE"
    $global:running
    while($global:running)
    { 
    
        write-host "waiting signal"
        $global:signal.waitForSignal()
        $global:reader.processMsgs()
        write-host "signal received"
    }
}
else
{
    write-host "CONNECTION FAILURE" -ForegroundColor Red
    pause
}

write-host "EXIT" -ForegroundColor Red

pause



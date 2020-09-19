

using module '.\Modules\CSharpAPI.dll'
using module '.\Modules\IBClient.psm1'
using module '.\Modules\DataStorageManager.psm1'
using module '.\Modules\BlockchainExchange.psm1'
using module '.\Modules\Candle.psm1'

$global:lastSampledTime = Get-Date


[IBApi.EClientSocket]$global:clientSocket = $null

#candle period back from current time in minutes
$global:timeSMA = 60 #240 = 4 hour

#calculated SMA based on previous 20 candles
$global:averageSMA = 0

#used to detect if price updates are missing or stopped
[DateTime]$global:lastPriceCapture = Get-Date
[IBClient]$global:wrap = $null
[IBApi.EReaderMonitorSignal]$global:signal = $null
[IBApi.EReader]$global:reader = $null
[bool]$global:running = $true
[int]$global:errorCount = 0
[int]$global:connectionErrorCount = 0
[DataStorageManager]$global:storage = New-Object DataStorageManager
################################################################################

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

Function Check-BankHoliday 
{
    Param (
        [CmdletBinding()]
        [Parameter(Mandatory,ValueFromPipeline)][datetime]$Date
    )
    $bankHolidays = (Invoke-RestMethod -Uri "https://www.gov.uk/bank-holidays.json" -Method GET)
    $bankHolidays.'england-and-wales'.events.date -contains (Get-Date $Date -Format "yyyy-MM-dd")
}



function Read-Character()
{
    if ($Host.UI.RawUI.KeyAvailable -eq $true)
    {
        return $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
    }

    return $null
}


function Send-Mail([string]$message)
{
    $notificationToEmailAddress = "ian.waters@southernit.com"
    $notificationFromEmailAddress = "psbot@bot.net"
    $smtpServer = "relay-cluster-eu01.hornetsecurity.com"
    $smtpPort = "25"
    $subject = "CRITICAL ALERT"
    Send-MailMessage -From $notificationFromEmailAddress -to $notificationToEmailAddress -Subject $subject -Body $message -SmtpServer $smtpServer -port $smtpPort
}

function Calculate-20SMA([string]$symbol)
{
     [decimal]$averagePrice = 0

     $candles = New-Object -TypeName "System.Collections.ArrayList"
         
     #time to calulate a new sma and candle
     #$global:lastSampledtime = Get-Date
     #$global:lastSampledtime
     $endSample = Get-Date
     
     for($i = 0;$i-le14;$i++)
     {
        #start time sample
        $startSample = $endSample.AddMinutes($global:timeSMA-($global:timeSMA*2))
                       
        #if start and end times are outside of trading hours then minus one to i to gether more info.
        #write-host "start sample:" $startSample
        #write-host "end sample:" $endSample
        
        $startOK = IsTradingHours $startSample
        $endOK = IsTradingHours $endSample
        
        if($startOK -eq $true)
        {
            $bankHoliday = check-bankholiday $startSample

            if($bankHoliday -eq $true)
            {
                $startOK = $false
            }
        }

        if($endOK -eq $true)
        {
            $bankHoliday = check-bankholiday $endSample

            if($bankHoliday -eq $true)
            {
                $endOK = $false
            }
        }
        
        if($startOK -eq $true -or $endOk -eq $true)
        {
            #in trading hours
            #end time sample
            $p = $candles.Add($global:storage.BuildCandle($symbol,$startSample, $endSample))
                         
            
        }
        else
        {
            $i = $i-1
        }

        #step back - start becomes the new end
        $endSample = $startSample.AddSeconds(-1)       
     }


     #fix any zero values caused by an outage################
     [int]$zeroCount = 0
     [decimal]$av = 0
     [int]$num = 0
     foreach($c in $candles)
     {
        if($c.open -eq 0 -or $c.close -eq 0)
        {
            $zeroCount++
        }
        else
        {
            $av +=  $c.close
        }

        $num++
     }

     if($zeroCount -gt 0)
     {
        #Send-Mail "IBBot Data error: Found zero candle"
        
        Write-Host "av:" $av
        Write-Host "num:" $num
        Write-Host "zerocount:" $zeroCount
        
        $av = $av / ($num-$zeroCount)

        foreach($c in $candles)
        {
            if($c.open -eq 0 -or $c.close -eq 0)
            {
                $c.open = $av
                $c.close = $av
            }
        }
     }   
     ########################################################

     
        
     $totalPrice = 0
    
     foreach($c in $candles)
     {
        #write-host "FROM:" $c.startTime
        #write-host "END:" $c.endTime
        #write-host "OPEN:" $c.open
        #write-host "CLOSE:" $c.close
        #write-host "HIGH:" $c.high
        #write-host "LOW:" $c.low

        $prices = $c.open, $c.close
        $prices = $prices | sort -Descending
        #[decimal]$centerPrice = ($prices[0] - $prices[1]) + $prices[1]

        [decimal]$centerPrice = $c.close
        
        Write-Host "CANDLE FROM:" $c.startTime "END:" $c.endTime "OPEN:" $c.open "CLOSE:" $c.close "HIGH:" $c.high "LOW:" $c.low "CENTER PRICE:" $centerPrice

        $totalPrice += $centerPrice
    }

    if($candles.Count -gt 0)
    {
        $averagePrice = $totalPrice / $candles.Count
    }

    return $averagePrice
}

function Review([string]$symbol, [double]$sma)
{
    $endSample = Get-Date
    $startSample = $endSample.AddMinutes($global:timeSMA-($global:timeSMA*2))
                      
    $candle = $global:storage.BuildCandle($symbol,$startSample, $endSample)

    if($candle.close -gt $sma)
    {
        Write-Host "Last candle close ($($candle.close)) is above the SMA" -ForegroundColor Green
        #buy state
        return "BUY"
    }

    Write-Host "Last candle close ($($candle.close)) is below the SMA" -ForegroundColor Red

    RETURN "SELL"
}


function Detect-Whale([string]$symbol)
{
    Write-Host "Detecting Whale" -ForegroundColor Green
    $endSample = Get-Date
    $startSample = $endSample.AddMinutes($global:timeSMA-($global:timeSMA*2))
    $candle = $global:storage.BuildCandle($symbol,$startSample, $endSample)

    if($candle.close -gt $candle.open)
    {
        #calculate percentage increase from open and close
    
        $diff = $candle.close - $candle.open
        $percentageIncrease = ($diff / $candle.close) * 100

        Write-Host "Percentage Increase:" $percentageIncrease -ForegroundColor Green
    
        #if increase greater than x amount trigger an email
        if($percentageIncrease -gt 4)
        {
            Send-Mail "IB Bot Detected Fast Mover"
        }
    }

    Write-Host "DONE" -ForegroundColor Green
}

function UpdatePosition([string]$symbol,[string]$position, [decimal]$sma)
{
    Write-Host "UPDATING POSITION START"
        
    Write-Host "LAST CANDLE POSITION:" $position
    Add-Content "[$((Get-Date).ToString())] LAST CANDLE POSITION: $($position)" -path "Bot.txt"

    $currentPosition = $global:storage.GetPosition($symbol)
    Write-Host "CURRENT POSITION:" $currentPosition
    Add-Content "[$((Get-Date).ToString())] CURRENT POSITION: $($currentPosition)" -path "Bot.txt"

    if($currentPosition -eq "TOBUY")
    {
        if($position -eq "BUY")
        {
            #Make a move from a sold waiting state to in a trade
            #buy the stock
            Write-Host "BUYING STOCK - MOVING INTO A TOSELL POSITION" -ForegroundColor Green
            Add-Content "[$((Get-Date).ToString())] BUYING STOCK - MOVING INTO A TOSELL POSITION" -path "Bot.txt"
            $global:storage.SetPosition($symbol,"TOSELL")


            #GET NUMBER OF SHARES TO BUY
            $numberShares =  $global:storage.GetPositionSize($symbol)
           
            #GET NEXT ID
            Write-Host "REQUESTING CLIENT ID" -ForegroundColor Yellow
            $global:clientSocket.reqIds(-1)
            Start-Sleep -Seconds 5
            $global:reader.processMsgs()
            Start-Sleep -Seconds 5
            $clientID =  $global:storage.GetClientID()
            $clientID = $clientID + 1
            Write-Host "DONE" -ForegroundColor Green
            
                        
            #place market buy order
            Write-Host "BUYING $($numberShares) SHARES OF $($symbol)" -ForegroundColor Green
            Add-Content "[$((Get-Date).ToString())] BUYING $($numberShares) SHARES OF $($symbol)" -path "Bot.txt"
            [IBApi.Order]$order = New-Object IBApi.Order
            $order.Action = "BUY";
            $order.OrderType = "MKT"
            $order.TotalQuantity = $numberShares
            [IBApi.Contract]$contract = New-Object IBApi.Contract
            $contract.Symbol = $symbol
            $contract.SecType = "STK"
            $contract.Currency = "USD"
            $contract.Exchange = "SMART"
            $contract.PrimaryExch = "ISLAND"
            $global:clientSocket.placeOrder($clientID,$contract,$order)
            $global:storage.SetOrdID($symbol,$clientID)
            Start-Sleep -Seconds 5

            
            #place a stop

            #calc 5% below the sma
            [decimal]$pv = ($sma / 100) * 0.5

            $limit = $sma - $pv
            $limit =  [math]::Round($limit)
            Write-Host "ADDING STOP OF STOCK $($symbol) AT PRICE: $($limit)" -ForegroundColor Green
            Add-Content "[$((Get-Date).ToString())] ADDING STOP OF STOCK $($symbol) AT PRICE: $($limit)" -path "Bot.txt"
            [IBApi.Order]$order = New-Object IBApi.Order
            $order.Action = "SELL";
            $order.OrderType = "STP"
            $order.AuxPrice = $limit
            $order.TotalQuantity = $numberShares
            [IBApi.Contract]$contract = New-Object IBApi.Contract
            $contract.Symbol = $symbol
            $contract.SecType = "STK"
            $contract.Currency = "USD"
            $contract.Exchange = "SMART"
            $contract.PrimaryExch = "ISLAND"
            $clientID = $clientID + 1
            $global:clientSocket.placeOrder($clientID,$contract,$order)
            $global:storage.SetStopID($symbol,$clientID)
            Start-Sleep -Seconds 5

            

            $global:reader.processMsgs()

            Start-Sleep -Seconds 5
        }
    }
    elseif($currentPosition -eq "TOSELL")
    {
        if($position -eq "SELL")
        {
            #Make a move from an in trade state to a waiting to buy
            #buy the stock
            Write-Host "SELLING STOCK - MOVING INTO A TOBUY POSITION" -ForegroundColor Red
            Add-Content "[$((Get-Date).ToString())] SELLING STOCK - MOVING INTO A TOBUY POSITION" -path "Bot.txt"

            $global:storage.SetPosition($symbol,"TOBUY")

            #GET NEXT ID
            Write-Host "REQUESTING CLIENT ID" -ForegroundColor Yellow
            $global:clientSocket.reqIds(-1)
            Start-Sleep -Seconds 5
            $global:reader.processMsgs()
            Start-Sleep -Seconds 5
            $clientID =  $global:storage.GetClientID()
            $clientID = $clientID + 1
            Write-Host "DONE" -ForegroundColor Green

            #remove stop order
            $stopOrderID = $global:storage.GetStopID($symbol)
            Write-Host "REMOVING STOP ORDER: $($stopOrderID)"
            Add-Content "[$((Get-Date).ToString())] REMOVING STOP ORDER: $($stopOrderID)" -path "Bot.txt"                    
            $global:clientSocket.cancelOrder($stopOrderID)
            $global:storage.SetStopID($symbol,-1)
            Start-Sleep -Seconds 5

            #place market sell order
            #GET NUMBER OF SHARES TO SELL
            $numberShares = $global:storage.GetPositionSize($symbol)
            Write-Host "SELLING $($numberShares) SHARES OF $($symbol)" -ForegroundColor Green
            Add-Content "[$((Get-Date).ToString())] SELLING $($numberShares) SHARES OF $($symbol)" -path "Bot.txt"
            [IBApi.Order]$order = New-Object IBApi.Order
            $order.Action = "SELL";
            $order.OrderType = "MKT"
            $order.TotalQuantity = $numberShares
            [IBApi.Contract]$contract = New-Object IBApi.Contract
            $contract.Symbol = $symbol
            $contract.SecType = "STK"
            $contract.Currency = "USD"
            $contract.Exchange = "SMART"
            $contract.PrimaryExch = "ISLAND"
            $clientID = $clientID + 1
            $global:clientSocket.placeOrder($clientID,$contract,$order)
            $global:storage.SetOrdID($symbol,-1)
            Start-Sleep -Seconds 5          
        }
        else
        {
            #WE ARE HOLDING STOCK AND STILL IN A TOSELL POSITION SO UPDATE THE STOP
          
            Write-Host "WE ARE HOLDING STOCK AND STILL IN A TOSELL POSITION SO UPDATE THE STOP" -ForegroundColor Cyan
            #CANCEL THE STOP
            #remove stop order
            Write-Host "REMOVING EXISTING STOP" -ForegroundColor Cyan
            $stopOrderID = $global:storage.GetStopID($symbol)
            Write-Host "REMOVING STOP ORDER: $($stopOrderID)"
            Add-Content "[$((Get-Date).ToString())] REMOVING STOP ORDER: $($stopOrderID)" -path "Bot.txt"  
            $global:clientSocket.cancelOrder($stopOrderID)                  
            $global:storage.SetStopID($symbol,-1)
            Start-Sleep -Seconds 5
            $global:reader.processMsgs()
            Write-Host "STOP REMOVAL COMPLETE" -ForegroundColor Cyan
            
            #SET A NEW STOP
            Write-Host "ADDING A NEW STOP" -ForegroundColor Cyan
             #GET NEXT ID
            Write-Host "REQUESTING CLIENT ID" -ForegroundColor Yellow
            Write-Host "EXISTING ID:" $global:storage.GetClientID()
            $global:clientSocket.reqIds(-1)
            Start-Sleep -Seconds 5
            $global:reader.processMsgs()
            Start-Sleep -Seconds 5
            $clientID =  $global:storage.GetClientID()
            $clientID = $clientID + 1
            Write-Host "NEW ID:" $clientID
            Write-Host "DONE" -ForegroundColor Green
            Start-Sleep -Seconds 5


            #place a stop
            $numberShares =  $global:storage.GetPositionSize($symbol)
            
            
            #calc 5% below the sma
            [decimal]$pv = ($sma / 100) * 0.5
            $limit = $sma - $pv
            

            $limit =  [math]::Round($limit)
            Write-Host "ADDING STOP OF STOCK $($symbol) AT PRICE: $($limit)" -ForegroundColor Green
            Add-Content "[$((Get-Date).ToString())] ADDING STOP OF STOCK $($symbol) AT PRICE: $($limit)" -path "Bot.txt"
            [IBApi.Order]$order = New-Object IBApi.Order
            $order.Action = "SELL";
            $order.OrderType = "STP"
            $order.AuxPrice = $limit
            $order.TotalQuantity = $numberShares
            [IBApi.Contract]$contract = New-Object IBApi.Contract
            $contract.Symbol = $symbol
            $contract.SecType = "STK"
            $contract.Currency = "USD"
            $contract.Exchange = "SMART"
            $contract.PrimaryExch = "ISLAND"
            $global:clientSocket.placeOrder($clientID,$contract,$order)
            $global:storage.SetStopID($symbol,$clientID)
            Start-Sleep -Seconds 5
            $global:reader.processMsgs()
            
            Write-Host "ADDING NEW STOP COMPLETE" -ForegroundColor Cyan
        }
    }
        
    Write-Host "UPDATING POSITION END"
}


function Connect()
{
    $global:wrap = New-Object IBClient
    $global:signal = new-object IBApi.EReaderMonitorSignal
    $global:clientSocket = New-Object IBApi.EClientSocket($global:wrap, $global:signal)
    $global:clientSocket.eConnect("localhost",7497,1)
    
    $global:clientSocket.IsConnected()
    
    #wait for user to press ok to connect buttons in TWS
    start-sleep -Seconds 10

    if(  $global:clientSocket.IsConnected() -eq $false)
    {
        Write-Host "(33) ERROR CONNECTING" -ForegroundColor Red
        return $false
    }

    $global:reader = New-Object IBApi.EReader($global:clientSocket,$global:signal)
    $global:reader.Start()
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


################################################################################

Setup-Display 110 40
Clear-Host

$global:lastSampledtime = Get-Date

$tradeState = "TOBUY"

#calculated SMA based on previous 20 candles
#$global:averageSMA = Calculate-20SMA

Write-Host ""
Write-Host "=====================================" -ForegroundColor Blue
Write-Host ""
Write-Host "STARTING BOT" -ForegroundColor Blue
Write-Host "SMA Period   :" $global:timeSMA -ForegroundColor Blue
Write-Host "Current Time :" $global:lastSampledtime -ForegroundColor Blue
Write-Host ""
Write-Host "=====================================" -ForegroundColor Blue
Write-Host ""
Add-Content "[$((Get-Date).ToString())] STARTING BOT" -path "Bot.txt"


$global:running = $true
$connected = Connect



#write-host "start"
#$global:clientSocket.reqAllOpenOrders()
# $global:reader.processMsgs()
#write-host "end"
#pause
#RETURN

if($connected -eq $true)
{
    Write-Host "CONNECTED: " $global:clientSocket.IsConnected() -ForegroundColor Green


    while($global:running)
    {
        if($connected -eq $true)
        {
            Write-Host ""
            Write-Host "CONNECTED: " $global:clientSocket.IsConnected() -ForegroundColor Green


            ############################################
            #CHECKING IF STOPS HAVE BEEN FILLED
            Write-Host "CHECKING IF STOPS HAVE BEEN FILLED" -ForegroundColor Green
            $global:clientSocket.reqAllOpenOrders()
            Start-Sleep -Seconds 10
            $global:reader.processMsgs()
            Write-Host "STOP CHECKS COMPLETED" -ForegroundColor Green
            ############################################

            $dt = Get-Date
            #if(IsTradingHours $dt)
            if($true)
            {
                #get all stocks to process
                [array]$stocks = $global:storage.GetStocks()

                foreach($stock in $stocks)
                {
                    Write-Host "=========================================================" -ForegroundColor Blue
                    Write-Host "PROCESSING STOCK:" $stock.SYMBOL
                    Write-Host "SYMBOLID:" $stock.SYMBOLID
                    Write-Host "POSITIONSIZE:" $stock.POSITIONSIZE
                    Write-Host "STATE:" $stock.STATE
                    Write-Host "STOPORDERID:" $stock.STOPORDERID
                    Write-Host "POSITION:" $stock.POSITION
                    
                    $state =  $global:storage.GetState($stock.SYMBOL)

                    ############################################################################
                    #CALCULATE SMA
                    $sma = Calculate-20SMA $stock.SYMBOL
                    Write-Host "SMA:" $sma -ForegroundColor Green
                    Add-Content "[$((Get-Date).ToString())] SMA: $($sma)" -path "Bot.txt"
                    ############################################################################

                    ###########################
                    #STOP
                    [decimal]$pv = ($sma / 100) * 0.5
                    $limit = $sma - $pv
                    $limit =  [math]::Round($limit)
                    Write-Host "STOP AT PRICE: $($limit)" -ForegroundColor Green
                    Add-Content "[$((Get-Date).ToString())] STOP AT PRICE: $($limit)" -path "Bot.txt"
                    ###########################

                    #####################################################
                    #DETERMINE POSITION
                    $position = Review $stock.SYMBOL $sma
                    Write-Host "TRADE STATE:" $position -ForegroundColor green
                    Add-Content "[$((Get-Date).ToString())] TRADE STATE: $($position)" -path "Bot.txt"
                    #####################################################

                    ##############################################
                    #Detect whales
                    Write-Host "DETECTING WHALES" -ForegroundColor Yellow
                    Detect-Whale $stock.SYMBOL $sma
                    ##############################################



                    if($state -eq "LEARNING")
                    {
                        Write-Host "STOCK IS IN LEARNING MODE" -ForegroundColor Green
                        Add-Content "[$((Get-Date).ToString())] STOCK IS IN LEARNING MODE" -path "Bot.txt"
                    }
                    else
                    {
                        Write-Host "STOCK IS IN LIVE TRADING MODE" -ForegroundColor Red
                        Add-Content "[$((Get-Date).ToString())] STOCK IS IN LIVE TRADING MODE" -path "Bot.txt"

                        if(IsTradingHours $dt)
                        {
                            if(check-bankholiday $dt)
                            {
                                Write-Host "OUTSIDE OF TRADING HOURS (BANK HOLIDAY)" -ForegroundColor Green
                            }
                            else
                            {
                                Write-Host "IN TRADING HOURS - UPDATING POSITION" -ForegroundColor Green
                                ########################################
                                #UPDATE POSITION
                                UpdatePosition $stock.SYMBOL $position $sma
                                ########################################
                            }
                        }
                        else
                        {
                            Write-Host "OUTSIDE OF TRADING HOURS" -ForegroundColor Green
                        }
                    }

                    Write-Host "=========================================================" -ForegroundColor Blue
                }
            }

            $global:lastSampledtime = Get-Date
            $nextSampleTime = (Get-Date).AddSeconds(60 * $global:timeSMA)
            Write-Host "NEXT SAMPLE TIME:" $nextSampleTime -ForegroundColor Green
            Add-Content "[$((Get-Date).ToString())] NEXT SAMPLE TIME: $($nextSampleTime)" -path "Bot.txt"
            Write-Host "=========================================================" -ForegroundColor Blue


            #Check if the log file is too big and rename it
            #if((Get-Item "DataCollector.txt").length -gt 20000kb) 
            #{
            #   $newName = "DataCollector " + (Get-Date -Format "dddd MM dd yyyy HH mm") + ".txt"
            #   Rename-Item -Path "DataCollector.txt" -NewName $newName
            #}
            
            #Clear old database price entries
            $global:storage.ClearOld()
            

            Start-Sleep -Seconds (60 * $global:timeSMA)
        }
    }
}
else
{
    Write-Host "CONNECTED: " $global:clientSocket.IsConnected() -ForegroundColor Red
}

Write-Host "END"
pause

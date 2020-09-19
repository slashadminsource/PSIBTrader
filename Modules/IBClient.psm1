
using module '.\CSharpAPI.dll'
using module '.\DataStorageManager.psm1'

class IBClient : IBApi.EWrapper
{
    #[IBApi.EClientSocket]$clientSocket = $null
    #private int nextOrderId;
    #private int clientId;
    #[IBApi.Messages]$test
    #[IBApi.SynchronizationContext]$sc
    #public IBClient(IBApi.EReaderSignal $signal)
    #{
         #$clientSocket = New-Object IBApi.EClientSocket($this, $signal)
    #    sc = SynchronizationContext.Current;
    #}

    [DataStorageManager]$storage = $null

    IBClient()
    {
        $this.storage = New-Object DataStorageManager
    }

    error([Exception]$e)
    {
        Write-Host "1"
    }

    error([string]$str)
    {
        Write-Host "2"
        Write-Host "ERROR:" $str
    }

    error([int]$id, [int]$errorCode, [string]$errorMsg)
    {
        Write-Host "3"
        Write-Host "ERRORCODE:" $errorCode "ERROR MESSAGE:" $errorMsg
    }

    currentTime([long]$time)
    {
        Write-Host "4"
    }

    tickPrice([int]$tickerId, [int]$field, [double]$price, [IBApi.TickAttrib]$attribs)
    {
        Write-Host "5"

        #Write-Host "TICKER ID: " $tickerId
        #Write-Host "FIELD:" $field
        #Write-Host "PRICE: " $price

        #https://interactivebrokers.github.io/tws-api/tick_types.html
        #FIELD: 68 = ask price

        $symbol = $this.storage.GetSymbolFromID($tickerId)
        $lastPriceCapture = $this.storage.GetLastPriceDate($symbol)

        $currentTime = Get-Date
        $diff = New-TimeSpan $lastPriceCapture $currenttime
        #Write-host "lastPriceCapture:" $lastPriceCapture -ForegroundColor Red
        #Write-host "currenttime:" $currentTime -ForegroundColor Red
        #Write-host "diff:" $diff -ForegroundColor Red
        #Write-host "diff total minutes:" $diff.TotalMinutes -ForegroundColor Red
            
        if($diff.TotalMinutes -gt 10)
        {
            #not received a new price in 10 minutes. logging now.

            Write-Host "10 MIN INTERVAL - LOGGING NEW PRICE" -ForegroundColor Red
            Write-Host "TICKER ID: " $tickerId
            Write-Host "FIELD:" $field
            Write-Host "PRICE: " $price
            #pause
            

            if($field -eq 68)
            {
                #delayed last trade price
                #log ticker id and price
            

                #Write-Host "ADDING PRICE FOR SYMBOL: " $symbol
            
                #$this.storage.AddPrice([string]$symbol,[decimal]$open,[decimal]$close,[decimal]$high,[decimal]$low)
                $this.storage.AddPrice($symbol,$price,$price,$price,$price)
            }

            if($field -eq 2)
            {
                #ask price
                #log ticker id and price
                #$symbol = $this.storage.GetSymbolFromID($tickerId)

                #Write-Host "ADDING PRICE FOR SYMBOL: " $symbol
            
                #$this.storage.AddPrice([string]$symbol,[decimal]$open,[decimal]$close,[decimal]$high,[decimal]$low)
                #$this.storage.AddPrice($symbol,$price,$price,$price,$price)
            }

            if($field -eq 4)
            {
                #last traded price
                #log ticker id and price
                #$symbol = $this.storage.GetSymbolFromID($tickerId)

                #Write-Host "ADDING PRICE FOR SYMBOL: " $symbol
            
                #$this.storage.AddPrice([string]$symbol,[decimal]$open,[decimal]$close,[decimal]$high,[decimal]$low)
                $this.storage.AddPrice($symbol,$price,$price,$price,$price)
            }
        }
   
        
        #Console.WriteLine("Price Change Ticker: " + tickerId + ", Field: " + name + ", Price: " + price);

        Write-Host "5 END"
    }
    
    tickSize([int]$tickerId, [int]$field, [int]$size)
    {
        Write-Host "6"
        
        
        Write-Host "TICKER ID: " $tickerId
        Write-Host "FIELD:" $field
        Write-Host "SIZE: " $size

        #var name = Enum.GetName(typeof(FieldTypes), field);
        #Console.WriteLine("Size Change TickerId: " + tickerId + ", Field: " + name + ", Size: " + size);
    }

    tickString([int]$tickerId, [int]$tickType, [string]$value)
    {
        Write-Host "7"
    }

    tickGeneric([int]$tickerId, [int]$field, [double]$value)
    {
        Write-Host "8"
    }

    tickEFP([int]$tickerId, [int]$tickType, [double]$basisPoints, [string]$formattedBasisPoints, [double]$impliedFuture, [int]$holdDays, [string]$futureLastTradeDate, [double]$dividendImpact, [double]$dividendsToLastTradeDate)
    {
        Write-Host "9"
    }

    deltaNeutralValidation([int]$reqId, [IBApi.DeltaNeutralContract]$deltaNeutralContract)
    {
        Write-Host "10"
    }

    tickOptionComputation([int]$tickerId, [int]$field, [double]$impliedVolatility, [double]$delta, [double]$optPrice, [double]$pvDividend, [double]$gamma, [double]$vega, [double]$theta, [double]$undPrice)
    {
        Write-Host "11"
    }

    tickSnapshotEnd([int]$tickerId)
    {
        Write-Host "12"
    }

    nextValidId([int]$orderId)
    {
        #Write-Host "13"
        #Write-Host "NEXTVALIDID:" $orderId -ForegroundColor Yellow
        $this.storage.SetClientID($orderId)

    }

    managedAccounts([string]$accountsList)
    {
        Write-Host "14"
        #Write-Host "MANAGED ACCOUNTS:" $accountsList
    }

    connectionClosed()
    {
        Write-Host "15"
    }

    accountSummary([int]$reqId, [string]$account, [string]$tag, [string]$value, [string]$currency)
    {
        Write-Host "16"
    }

    accountSummaryEnd([int]$reqId)
    {
        Write-Host "17"
    }

    bondContractDetails([int]$requestId, [IBApi.ContractDetails]$contractDetails)
    {
        Write-Host "18"
    }

    updateAccountValue([string]$key, [string]$value, [string]$currency, [string]$accountName)
    {
        Write-Host "19"
        #Write-Host "UPDATE ACCOUNT VALUE KEY:" $key
        #Write-Host "UPDATE ACCOUNT VALUE VALUE:" $value
        #Write-Host "UPDATE ACCOUNT VALUE CURRENCY:" $currency
        #Write-Host "UPDATE ACCOUNT VALUE ACCOUNT NAME:" $accountName
    }

    updatePortfolio([IBAPi.Contract]$contract, [double]$position, [double]$marketPrice, [double]$marketValue, [double]$averageCost, [double]$unrealizedPNL, [double]$realizedPNL, [string]$accountName)
    {
        Write-Host "20"
    }

    updateAccountTime([string]$timestamp)
    {
        Write-Host "21"
        #Write-Host "UPDATE ACCOUNT TIME TIMESTAMP:" $timestamp
    }

    accountDownloadEnd([string]$account)
    {
        Write-Host "22"
        #Write-Host "ACCOUNT DOWNLOAD END:" $account
    }

    orderStatus([int]$orderId, [string]$status, [double]$filled, [double]$remaining, [double]$avgFillPrice, [int]$permId, [int]$parentId, [double]$lastFillPrice, [int]$clientId, [string]$whyHeld, [double]$mktCapPrice)
    {
        Write-Host "23" -ForegroundColor Red
        #Write-Host "ORDER STATUS ID:" $orderId -ForegroundColor Red
        #Write-Host "ORDER STATUS CLIENT ID:" $clientId -ForegroundColor Red
        #Write-Host "ORDER STATUS PERM ID:" $permId -ForegroundColor Red
        #Write-Host "ORDER STATUS PARENT ID:" $parentId -ForegroundColor Red
        #Write-Host "ORDER STATUS:" $status -ForegroundColor Red
        
        
        #GET ALL STOP ORDER ID'S
        [Array]$stopOrders = $this.storage.GetAllStopOrdID()


        #DOES THIS STATUS UPDATE MATCH A STOP ORDER ID?
        foreach($stop in $stopOrders)
        {
            #Write-Host "CHECKING STOP:" $stop.STOPORDERID -ForegroundColor Yellow

            #IF YES IS THE UPDATE A Filled STATUS?
            if($stop.STOPORDERID -eq $orderId)
            {
                #Write-Host "THIS STOP IS BEING UPDATED:" $stop.STOPORDERID  -ForegroundColor Yellow
                #Write-Host "TESTING IF STOP HAS BEEN FILLED ITS STATUS IS:" $status -ForegroundColor Yellow
                if($status -eq "Filled")
                {
                    Write-Host "STOP HAS BEEN FILLED. RESETTING POSITION TO TOBUY" -ForegroundColor Yellow
                    #IF YES THEN SET POSITION TOBUY
                    $this.storage.SetPosition($stop.SYMBOL,"TOBUY")
                    $this.storage.SetOrdID($stop.SYMBOL,-1)
                    $this.storage.SetStopID($stop.SYMBOL,-1)
                }
                else
                {
                    #Write-Host "STOP HAS NOT BEEN FILLED" -ForegroundColor Yellow
                }
            }
        }

       
    }

    openOrder([int]$orderId, [IBApi.Contract]$contract, [IBApi.Order]$order, [IBApi.OrderState]$orderState)
    {
        Write-Host "24" -ForegroundColor Red
        #Write-Host "OPEN ORDER ID:" $orderId -ForegroundColor Red
        #Write-Host "OPEN ORDER STOCK:" $contract.Symbol -ForegroundColor Red
        #Write-Host "OPEN ORDER ACTION:" $order.Action -ForegroundColor Red
        #Write-Host "OPEN ORDER STATE:" $orderState.Status -ForegroundColor Red
    }

    openOrderEnd()
    {
        Write-Host "25"
    }

    contractDetails([int]$reqId, [IBApi.ContractDetails]$contractDetails)
    {
        Write-Host "26"
    }

    contractDetailsEnd([int]$reqId)
    {
        Write-Host "27"
    }

    execDetails([int]$reqId, [IBApi.Contract]$contract, [IBApi.Execution]$execution)
    {
        Write-Host "28"
    }

    execDetailsEnd([int]$reqId)
    {
        Write-Host "29"
    }

    commissionReport([IBApi.CommissionReport]$commissionReport)
    {
        Write-Host "30"
        Write-Host "COMMISSION REPORT EXECID:" $commissionReport.ExecId
        Write-Host "COMMISSION REPORT COMMISSION:" $commissionReport.Commission
        Write-Host "COMMISSION REPORT CURRENCY:" $commissionReport.Currency
        Write-Host "COMMISSION REPORT REALIZEDPNL:" $commissionReport.RealizedPNL

    }

    fundamentalData([int]$reqId, [string]$data)
    {
        Write-Host "31"
    }

    historicalData([int]$reqId, [IBApi.Bar]$bar)
    {
        Write-Host "32"
    }

    historicalDataEnd([int]$reqId, [string]$startDate, [string]$endDate)
    {
        Write-Host "33"
    }

    marketDataType([int]$reqId, [int]$marketDataType)
    {
        Write-Host "34"
    }

    updateMktDepth([int]$tickerId, [int]$position, [int]$operation, [int]$side, [double]$price, [int]$size)
    {
        Write-Host "35"
    }

    updateMktDepthL2([int]$tickerId, [int]$position, [string]$marketMaker, [int]$operation, [int]$side, [double]$price, [int]$size, [bool]$isSmartDepth)
    {
        Write-Host "36"
    }

    updateNewsBulletin([int]$msgId, [int]$msgType, [string]$message, [string]$origExchange)
    {
        Write-Host "37"
    }

    position([string]$account, [IBApi.Contract]$contract, [double]$pos, [double]$avgCost)
    {
        Write-Host "38"
        Write-Host "POSITION ACCOUNT:" $account
        Write-Host "POSITION CONTRACT:" $contract.Symbol
        Write-Host "POSITION POS:" $pos
        Write-Host "POSITION AVGCOST:" $avgCost
    }

    positionEnd()
    {
        Write-Host "39"
    }

    realtimeBar([int]$reqId, [long]$time, [double]$open, [double]$high, [double]$low, [double]$close, [long]$volume, [double]$WAP, [int]$count)
    {
        Write-Host "40"
    }

    scannerParameters([string]$xml)
    {
        Write-Host "41"
    }

    scannerData([int]$reqId, [int]$rank, [IBApi.ContractDetails]$contractDetails, [string]$distance, [string]$benchmark, [string]$projection, [string]$legsStr)
    {
        Write-Host "42"
    }

    scannerDataEnd([int]$reqId)
    {
        Write-Host "43"
    }

    receiveFA([int]$faDataType, [string]$faXmlData)
    {
        Write-Host "44"
    }

    verifyMessageAPI([string]$apiData)
    {
        Write-Host "45"
    }

    verifyCompleted([bool]$isSuccessful, [string]$errorText)
    {
        Write-Host "46"
    }

    verifyAndAuthMessageAPI([string]$apiData, [string]$xyzChallenge)
    {
        Write-Host "46"
    }

    verifyAndAuthCompleted([bool]$isSuccessful, [string]$errorText)
    {
        Write-Host "47"
    }

    displayGroupList([int]$reqId, [string]$groups)
    {
        Write-Host "48"
    }

    displayGroupUpdated([int]$reqId, [string]$contractInfo)
    {
        Write-Host "49"
    }

    connectAck()
    {
        Write-Host "50"
                #if (ClientSocket.AsyncEConnect)
                 #   ClientSocket.startApi();
    }

    positionMulti([int]$reqId, [string]$account, [string]$modelCode, [IBApi.Contract]$contract, [double]$pos, [double]$avgCost)
    {
        Write-Host "51"
    }

    positionMultiEnd([int]$reqId)
    {
        Write-Host "52"
    }

    accountUpdateMulti([int]$reqId, [string]$account, [string]$modelCode, [string]$key, [string]$value, [string]$currency)
    {
        Write-Host "53"
    }

    accountUpdateMultiEnd([int]$reqId)
    {
        Write-Host "54"
    }

    securityDefinitionOptionParameter([int]$reqId, [string]$exchange, [int]$underlyingConId, [string]$tradingClass, [string]$multiplier, [System.Collections.Generic.HashSet[String]]$expirations, [System.Collections.Generic.HashSet[double]]$strikes)
    {
        Write-Host "55"
    }

    securityDefinitionOptionParameterEnd([int]$reqId)
    {
        Write-Host "56"
    }

    softDollarTiers([int]$reqId, [IBApi.SoftDollarTier[]]$tiers)
    {
        Write-Host "57"
    }

    familyCodes([IBApi.FamilyCode[]]$familyCodes)
    {
        Write-Host "58"
    }

    symbolSamples([int]$reqId, [IBAPi.ContractDescription[]]$contractDescriptions)
    {
        Write-Host "59"
    }

    mktDepthExchanges([IBAPi.DepthMktDataDescription[]]$depthMktDataDescriptions)
    {
        Write-Host "60"
    }

    tickNews([int]$tickerId, [long]$timeStamp, [string]$providerCode, [string]$articleId, [string]$headline, [string]$extraData)
    {
        Write-Host "61"
    }

    smartComponents([int]$reqId, [System.Collections.Generic.Dictionary[[int],[System.Collections.Generic.KeyValuePair[[string],[char]]]]]$theMap)
    {
        Write-Host "62"
    }

    tickReqParams([int]$tickerId, [double]$minTick, [string]$bboExchange, [int]$snapshotPermissions)
    {
        Write-Host "63"
    }

    newsProviders([IBApi.NewsProvider[]]$newsProviders)
    {
        Write-Host "64"
    }

    newsArticle([int]$requestId, [int]$articleType, [string]$articleText)
    {
        Write-Host "65"
    }

    historicalNews([int]$requestId, [string]$time, [string]$providerCode, [string]$articleId, [string]$headline)
    {
        Write-Host "66"
    }

    historicalNewsEnd([int]$requestId, [bool]$hasMore)
    {
        Write-Host "67"
    }

    headTimestamp([int]$reqId, [string]$headTimestamp)
    {
        Write-Host "68"
    }

    histogramData([int]$reqId, [IBApi.HistogramEntry[]]$data)
    {
        Write-Host "69"
    }

    historicalDataUpdate([int]$reqId, [IBApi.Bar]$bar)
    {
        Write-Host "70"
    }

    rerouteMktDataReq([int]$reqId, [int]$conId, [string]$exchange)
    {
        Write-Host "71"
    }

    rerouteMktDepthReq([int]$reqId, [int]$conId, [string]$exchange)
    {
        Write-Host "72"
    }

    marketRule([int]$marketRuleId,[IBApi.PriceIncrement[]]$priceIncrements)
    {    
        Write-Host "73"
    }

    pnl([int]$reqId, [double]$dailyPnL, [double]$unrealizedPnL, [double]$realizedPnL)
    {
        Write-Host "74"
    }

    pnlSingle([int]$reqId, [int]$pos, [double]$dailyPnL, [double]$unrealizedPnL, [double]$realizedPnL, [double]$value)
    {
        Write-Host "75"
    }

    historicalTicks([int]$reqId, [IBApi.HistoricalTick[]]$ticks, [bool]$done)
    {
        Write-Host "76"
    }

    historicalTicksBidAsk([int]$reqId, [IBApi.HistoricalTickBidAsk[]]$ticks, [bool]$done)
    {
        Write-Host "77"
    }

    historicalTicksLast([int]$reqId, [IBApi.HistoricalTickLast[]]$ticks, [bool]$done)
    {
        Write-Host "78"
    }

    tickByTickAllLast([int]$reqId, [int]$tickType, [long]$time, [double]$price, [int]$size, [IBApi.TickAttribLast]$tickAttribLast, [string]$exchange, [string]$specialConditions)
    {
        Write-Host "79"
    }

    tickByTickBidAsk([int]$reqId, [long]$time, [double]$bidPrice, [double]$askPrice, [int]$bidSize, [int]$askSize, [IBApi.TickAttribBidAsk]$tickAttribBidAsk)
    {
        Write-Host "81"
    }

    tickByTickMidPoint([int]$reqId, [long]$time, [double]$midPont)
    {
        Write-Host "82"
    }

    orderBound([long]$orderId, [int]$apiClientId, [int]$apiOrderId)
    {
        Write-Host "83"
    }

    completedOrder([IBApi.Contract]$contract, [IBApi.Order]$order, [IBApi.OrderState]$orderState)
    {
        Write-Host "84"
    }

    completedOrdersEnd()
    {
        Write-Host "85"
    }
}

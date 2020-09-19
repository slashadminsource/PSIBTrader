
class BlockchainExchange
{
    $apiKey      = ''
    $url         = 'wss://ws.prod.blockchain.info/mercury-gateway/v1/ws'
    $webSocket   = $null                                           
    $cancelToken = $null
    $logPath     = "c:\blockchainexchangelog.txt"
    $callTimeout = 5
    
    BlockchainExchange([string]$apiKey)
    {
        $this.apiKey      = $apiKey
    }

    InitVariables()
    {
        $this.webSocket   = $null                                           
        $this.cancelToken = $null
        $this.webSocket   = New-Object System.Net.WebSockets.ClientWebSocket                                                
        $this.cancelToken = New-Object System.Threading.CancellationToken
        $this.webSocket.Options.UseDefaultCredentials = $false
        $this.webSocket.Options.SetRequestHeader("origin","https://exchange.blockchain.com")
    }

    [bool]Connect()
    {
        $this.InitVariables()

        $response = $this.webSocket.ConnectAsync($this.url, $this.cancelToken)
        While (!$response.IsCompleted) 
        { 
            Start-Sleep -Milliseconds 100 
        }
            
        If (!($this.webSocket -is [System.Net.WebSockets.ClientWebSocket]))
        {
            Write-Log  -Level Error 'Connect error:' -Path $this.logPath
            return $false
        }

        if($this.Authenticate() -eq $true)
        {
            $sResult = $this.Subscribe()
            return $sResult
        }

        return $false
    }

    [bool]Subscribe()
    {
        #subscribe to heatbeat messages which help break out of receiving loop
        $this.Send('{"action": "subscribe","channel": "heartbeat"}')
        Start-Sleep -Seconds 1
        $response = $this.Receive()
        Write-Host $response -ForegroundColor Green
        Add-Content $response -path "DataCollector.txt"
        if($response.Contains("Rejected"))
        {
            Write-Host "HEARTBEAT REJECTED" -ForegroundColor Red
            Add-Content "HEARTBEAT REJECTED" -path "DataCollector.txt"
            return $false
        }

    
        # subscribe to candlestick market data
        # The price data is an array consisting of [timestamp, open, high, low, close, volume]
        # granularity (in seconds) has to be specified. Supported granularity values are: 
        # 60    1min      0.016hr
        # 300   5min      0.083hr
        # 900   15min     0.25hr
        # 3600  60min     1hr
        # 21600 360min    6hr
        # 86400 1440min   24hr
        $this.Send('{"action": "subscribe","channel": "prices","symbol": "BTC-USD","granularity": 60}')
         Start-Sleep -Seconds 1
        $response = $this.Receive()
        Write-Host $response -ForegroundColor Green
        Add-Content $response -path "DataCollector.txt"
        if($response.Contains("Rejected"))
        {
            Write-Host "PRICES REJECTED" -ForegroundColor Red
            Add-Content "PRICES REJECTED" -path "DataCollector.txt"
            return $false
        }
        
        #subscribe to trading channel
        $this.Send('{"action": "subscribe","channel": "trading"}')
        Start-Sleep -Seconds 1
        $response = $this.Receive()
        Write-Host $response -ForegroundColor Green
        Add-Content $response -path "DataCollector.txt"
        if($response.Contains("Rejected"))
        {
            Write-Host "TRADE REJECTED" -ForegroundColor Red
            Add-Content "TRADE REJECTED" -path "DataCollector.txt"
            return $false
        }

        #subscribe to balance updates
        $this.Send('{"action": "subscribe","channel": "balances"}')
        Start-Sleep -Seconds 1
        $response = $this.Receive()
        Write-Host $response -ForegroundColor Green
        Add-Content $response -path "DataCollector.txt"
        if($response.Contains("Rejected"))
        {
            Write-Host "BALANCES REJECTED" -ForegroundColor Red
            Add-Content "BALANCES REJECTED" -path "DataCollector.txt"
            return $false
        }

        #subscribe to ticker updates
        $this.Send('{"action": "subscribe","channel": "ticker","symbol": "BTC-USD"}')
        Start-Sleep -Seconds 1
        $response = $this.Receive()
        Write-Host $response -ForegroundColor Green
        Add-Content $response -path "DataCollector.txt"
        if($response.Contains("Rejected"))
        {
            Write-Host "TICKER REJECTED" -ForegroundColor Red
            Add-Content "TICKER REJECTED" -path "DataCollector.txt"
            return $false
        }

        return $true

    }
    
    Disconnect()
    {
        $this.webSocket.Dispose()
    }

    [bool]Authenticate()
    {
        $cmd = "{""token"": ""$($this.apiKey)"", ""action"": ""subscribe"", ""channel"": ""auth""}"
        return $this.Send($cmd)
    }

    [bool]Send([string]$data)
    {
        $array = @()
        $encoding = [System.Text.Encoding]::UTF8
        $Array = $encoding.GetBytes($data)
        $formattedData = New-Object System.ArraySegment[byte]  -ArgumentList @(,$Array)

        $response = $this.webSocket.SendAsync($formattedData, [System.Net.WebSockets.WebSocketMessageType]::Text, [System.Boolean]::TrueString, $this.cancelToken)
        $connStart = Get-Date

        While (!$response.IsCompleted) 
        { 
            $timeTaken = ((get-date) - $connStart).Seconds
            If ($timeTaken -gt $this.callTimeout) 
            {
                Write-Log -Level Error "Message took longer than $($this.callTimeOut) seconds and may not have been sent." -Path $this.logPath
                return $false
            }
            Start-Sleep -Milliseconds 100 
        }

        return $true
    }

    [string]Receive()
    {
        $encoding = [System.Text.Encoding]::UTF8
        $size = 1024
        $array = [byte[]] @(,0) * $size
        $data = New-Object System.ArraySegment[byte] -ArgumentList @(,$array)
        $connection = $this.webSocket.ReceiveAsync($data, $this.cancelToken)

        $connStart = Get-Date
        While (!$connection.IsCompleted) 
        { 
            if($connection.State -eq "Closed")
            {
                return $null
            }
                
            #write-Host "Waiting for Receive to complete"
            #$timeTaken = ((get-date) - $connStart).Seconds
            #write-host "time taken:" $timeTaken
            #If ($timeTaken -gt $this.callTimeout) 
            #{
            #    $this.cancelToken.Cancel()
                #no message waiting to be received
            #    return $null
            #}
            Start-Sleep -Milliseconds 100 
        }
        #Write-Host "Finished Receiving Request"
       
        $response = ""
        try
        {
            $chararray = $encoding.GetChars($data.array) 
            [string]$chararray2 = $chararray | Where-Object{$_}
            #$response = [String]::new($chararray2)
            $response = $chararray2.ToString()
            $response = $response.Replace(" ", "")

            #Write-Host "Response: "$response

           
        }
        catch
        {
            $response = "ERROR"
        }
            
        return $response
    }
    
    MktBuy([float]$btc)
    {
        $cmd = "{""action"": ""NewOrderSingle"",""channel"": ""trading"",""clOrdID"": ""MKTBUY"",""symbol"": ""BTC-USD"",""ordType"": ""market"",""timeInForce"": ""GTC"",""side"": ""buy"",""orderQty"": $($btc)}"
        $this.Send($cmd)
    }

    MktSell([float]$btc)
    {
        $cmd = "{""action"": ""NewOrderSingle"",""channel"": ""trading"",""clOrdID"": ""MKTSELL"",""symbol"": ""BTC-USD"",""ordType"": ""market"",""timeInForce"": ""GTC"",""side"": ""sell"",""orderQty"": $($btc)}"
        $this.Send($cmd)
    }

    LimitBuy([float]$btc, [decimal]$limit)
    {
        $cmd = "{""action"": ""NewOrderSingle"",""channel"": ""trading"",""clOrdID"": ""LMTBUY"",""symbol"": ""BTC-USD"",""ordType"": ""limit"",""timeInForce"": ""GTC"",""side"": ""buy"",""orderQty"": $($btc),""price"": $($limit)}"#,""execInst"": ""ALO""}"
        $this.Send($cmd)
    }

    LimitSell([float]$btc, [decimal]$limit)
    {
        $cmd = "{""action"": ""NewOrderSingle"",""channel"": ""trading"",""clOrdID"": ""LMTSELL"",""symbol"": ""BTC-USD"",""ordType"": ""limit"",""timeInForce"": ""GTC"",""side"": ""sell"",""orderQty"": $($btc),""price"": $($limit)}"#,""execInst"": ""ALO""}"
        $this.Send($cmd)
    }

    AddStop([float]$btc, [decimal]$limit)
    {
        $cmd = "{""action"": ""NewOrderSingle"",""channel"": ""trading"",""clOrdID"": ""STOP"",""symbol"": ""BTC-USD"",""ordType"": ""stop"",""timeInForce"": ""GTC"",""side"": ""sell"",""orderQty"": $($btc),""stopPx"": $($limit)}"
        $this.Send($cmd)
    }

    RemoveStop([string]$orderID)
    {
        $cmd = "{""action"": ""CancelOrderRequest"",""channel"": ""trading"",""orderID"": ""$($orderID)""}"
        $this.Send($cmd)
    }
}
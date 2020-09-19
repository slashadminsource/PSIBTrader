
# The simple moving average is quite easy to calculate. 
# It is calculated by averaging a number of past data points. 
# Past closing prices are most often used as data points. 
# For example, to calculate a security's 20-day SMA, the closing prices of the past 20 days would be added up, and then divided by 20.
using module '.\Candle.psm1'


Class DataStorageManager
{
    CreateDatabase()
    {
        #DROP EXISTING DATABASE IF IT EXISTS
        $cmd = "IF EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE name = N'IBTradingBot')
                USE [master]
                GO
                ALTER DATABASE [IBTradingBot] SET SINGLE_USER WITH ROLLBACK 
                IMMEDIATE
                GO
                DROP DATABASE [IBTradingBot]
                GO"
                
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Query $cmd

              
        #CREATE NEW DATABASE
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Query "CREATE DATABASE IBTradingBot;"


        #BUILD PRICES TABLE
        $cmd = 'CREATE TABLE PRICES (
                ID int NOT NULL IDENTITY PRIMARY KEY,
                DT DATETIME DEFAULT(getdate()),
                SYMBOL VARCHAR(255),
                OPN DECIMAL(8,2),
                CLS DECIMAL(8,2),
                HIGH DECIMAL(8,2),
                LOW DECIMAL(8,2)
                );'

        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        

        #BUILD BALANCE TABLE
        $cmd = 'CREATE TABLE BALANCE (
                ID int NOT NULL IDENTITY PRIMARY KEY,
                DT DATETIME DEFAULT(getdate()),
                AVAILABLE DECIMAL(8,2)
                );'

        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
               

        #BUILD STOCKS TABLE
        $cmd = 'CREATE TABLE STOCKS (
                ID int NOT NULL IDENTITY PRIMARY KEY,
                SYMBOL VARCHAR(255),
                SYMBOLID int,
                POSITIONSIZE int,
                STATE VARCHAR(255),
                TRADEID int,
                STOPORDERID int,
                POSITION VARCHAR(255)
                );'

        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd


        #insert my test data
        $cmd = "INSERT INTO STOCKS (SYMBOL,SYMBOLID,POSITIONSIZE,STATE,TRADEID,STOPORDERID,POSITION) VALUES ('TSLA',5000,1,'LEARNING',0,0,'TOBUY');"
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd


        #BUILD VARIABLE TABLE
        $cmd = 'CREATE TABLE VARIABLES (
                ID int NOT NULL IDENTITY PRIMARY KEY,
                CLIENTID INT
                );'

        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
                        
        #ADD VARIABLES
        $cmd = "INSERT INTO VARIABLES (CLIENTID) VALUES (-1);"
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd


        
        

        #insert my test data
        #$cmd = "INSERT INTO STOCKS (SYMBOL,SYMBOLID,POSITIONSIZE,STATE,ORDERID,STOPORDERID,POSITION) VALUES ('AMZN',6000,1,'LEARNING','NONE','NONE','TOBUY');"
        #Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
               
    }

    SetPosition([string]$symbol,[string]$position)
    {
        $cmd = "UPDATE STOCKS SET POSITION = '$($position)' WHERE SYMBOL = '$($symbol)';"
        
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
    }

    [string]GetPosition([string]$symbol)
    {
        $cmd = "SELECT POSITION FROM STOCKS WHERE SYMBOL = '$($symbol)';"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result[0]
    }

    [int]GetPositionSize([string]$symbol)
    {
        $cmd = "SELECT POSITIONSIZE FROM STOCKS WHERE SYMBOL = '$($symbol)';"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result[0]
    }
       

    ClearOld()
    {
        $dt = Get-Date
        $dt = $dt.AddDays(-20)
        
        $cmd = "DELETE FROM PRICES WHERE DT < '$($dt)';"
        
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
    }


    [string]GetState([string]$symbol)
    {
        $cmd = "SELECT STATE FROM STOCKS WHERE SYMBOL = '$($symbol)';"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result[0]
    }

    [string]GetStopOrderID([string]$symbol)
    {
        $cmd = "SELECT STOPORDERID FROM VARIABLES;"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result[0]
    }

    [string]GetSymbolFromID([int]$symbolID)
    {
        $cmd = "SELECT SYMBOL FROM STOCKS WHERE SYMBOLID = $($symbolID);"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result[0]
    }

    [DateTime]GetLastPriceDate([string]$symbol)
    {
        $cmd = "SELECT DT FROM PRICES WHERE SYMBOL = '$($symbol)' ORDER BY DT DESC;"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd


        if($result -eq $null)
        {
            write-host "is null"
            return (Get-Date).AddMinutes(-20)
        }


        if($result.GetType().ToString() -eq "System.Data.DataRow")
        {
            return $result.DT
        }

        #probably a System.Object[]
        
        return $result[0].DT
    }

    [Array]GetStocks()
    {
        $cmd = "SELECT SYMBOL,SYMBOLID,POSITIONSIZE,STATE,STOPORDERID,POSITION FROM STOCKS;"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result
    }


    [int]GetClientID()
    {
        $cmd = "SELECT CLIENTID FROM VARIABLES;"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result[0]
    }



    SetStopID([string]$symbol,[int]$orderID)
    {
        $cmd = "UPDATE STOCKS SET STOPORDERID = $($orderID) WHERE SYMBOL='$($symbol)';"
        
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
    }

    [int]GetStopID([string]$symbol)
    {
        $cmd = "SELECT STOPORDERID FROM STOCKS WHERE SYMBOL='$($symbol)';"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result[0]
    }




    SetOrdID([string]$symbol,[int]$orderID)
    {
        $cmd = "UPDATE STOCKS SET TRADEID = $($orderID) WHERE SYMBOL='$($symbol)';"
        
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
    }

    [int]GetOrdID([string]$symbol)
    {
        $cmd = "SELECT TRADEID FROM STOCKS WHERE SYMBOL='$($symbol)';"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result[0]
    }

    [Array]GetAllStopOrdID()
    {
        $cmd = "SELECT SYMBOL,STOPORDERID FROM STOCKS;"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        
        $stopOrders = @()
        

        if($result -eq $null)
        {
            return $stopOrders
        }


        if($result.GetType().ToString() -eq "System.Data.DataRow")
        {
            $stopOrders = $stopOrders + $result
        }

        foreach($rst in $result)
        {
            $stopOrders = $stopOrders + $rst
        }
              
        return $stopOrders
    }


    SetClientID([int]$orderID)
    {
        $cmd = "UPDATE VARIABLES SET CLIENTID = $($orderID);"
        
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
    }

    SetStopOrderID([string]$symbol,[string]$orderID)
    {
        $cmd = "UPDATE VARIABLES SET STOPORDERID = $($orderID);"
        
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
    }

    [decimal]GetBalance()
    {
        
        $cmd = "SELECT AVAILABLE FROM BALANCE ORDER BY ID DESC;"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result[0].USDAVAILABLE
    }

    AddPrice([string]$symbol,[decimal]$open,[decimal]$close,[decimal]$high,[decimal]$low)
    {
        $cmd = "INSERT INTO PRICES (SYMBOL,OPN,CLS,HIGH,LOW) VALUES ('$($symbol)',$($open),$($close),$($high),$($low));"
        
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
    }

    [decimal]GetPrice([string]$symbol)
    {
        $cmd = "SELECT CLS FROM PRICES ORDER BY ID DESC;"
        $result = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        return $result[0].CLS
    }

    AddBalance([decimal]$available)
    {
        $cmd = "INSERT INTO BALANCE (AVAILABLE) VALUES ($($available));"
        #WRITE-HOST "**** price: " $cmd
        #PAUSE
        Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
    }

    [Candle]BuildCandle([string]$symbol, [datetime]$startTime, [dateTime]$endTime)
    {
        $candle = New-Object -TypeName Candle
        $candle.startTime = $startTime
        $candle.endTime = $endTime
        
        #get all prices between dates
        $cmd = "SELECT ID,OPN,CLS,HIGH,LOW FROM PRICES WHERE DT BETWEEN '$($startTime)' AND '$($endTime)' AND SYMBOL = '$($symbol)' ORDER BY ID ASC;"
        #write-host $cmd
        $results = Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Database "IBTradingBot" -Query $cmd
        
        if($results.count-gt 0)
        {

            #get open
            $candle.open = $results[0].OPN

            #get close
            $candle.close = $results[($results.Length-1)].CLS

            #get high
            $candle.high = ($results | Measure-Object -Property HIGH -Maximum).Maximum

            #get low
            $candle.low = ($results | Measure-Object -Property LOW -Minimum).Minimum
        }

        return $candle
    }
}


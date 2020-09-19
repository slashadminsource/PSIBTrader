# PSIBTrader

This bot is for educational purposes only!
This bot will loose all of your money if you try to get it working.
I do not support this bot, its provided to the PowerShell coding community for educational purposes.
Traing stocks is very risky, im not a trader or an accountant, im an IT guy who likes to mess around with coding projects from time to time.
This code most definately contains bugs and errors and terrible code which will never be fixed or updated by me.
Use at your own risk!


I worked on this project because I wanted to see if I could develop a swing trading PowerShell Bot. 


This Bot has three components to it:

1: IBDataCollector.ps1 This script collects stock price data from the Interactive Brokers Trader Workstation software and places it into a SQL database.

2: IBBot.ps1 This script handles the swing trading stragegy and places buy and sell orders to the Interactive Brokers Trader Workstation software. It looks at the pricing data stored in the SQL database and works out the average price in every four hour time span in trading hours.

It then calculates the 14 Simple Moving Average (SMA) and determines if the price is heading up or down and places a buy or sell order when the price goes above or below the SMA.

3: IBStart.ps1 This script simply starts the IBDataCollector and IBStart stripts and restarts them every day. (The trader workstation software restarts daily so this script restarts the scripts after each restart of the software).

SETUP.

1: Setup a trading account with Interactive Brokers here: https://www.interactivebrokers.co.uk/en/home.php and install the Trading Workstation software. Follow their guides to enable the API functionality. I tested thes script in paper trading mode which is pretend money and the safest way to get things up and running. You will also need to add a market data subscription to your account so you can receive stock pricing information.

2: Get yourself a spare windows 10 PC which you can leave running or setup a virtual machine in Azure or AWS and continue the setup steps on that PC.

3: Install SQL Server Express 2019 from here: https://go.microsoft.com/fwlink/?linkid=866658 Accept all defaults untill the isntall is finished. This will create a default SQL instance called "SQLEXPRESS".

4: Right click IBDataCollector.ps1 and select 'Run With PowerShell'. From the menu press C to create a database then exit the script.

5: Right click IBStart.ps1 and it will startup the scripts.

By default the script will add Tesla stock in learning mode to the database. After a few days of running the Bot you can change from 'LEARNING' mode into 'TRADING' mode by editing the STOCKS table within th database.

When you edit the STOCKS table close all open script windows and run IBStart.ps1 again to reinitiate the Bot.


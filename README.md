# Metatrader-Bridge-ZeroMQ
This repository contains a python client and a MQL4/5 server connector using text files

The code implements the two side "PUSH-PULL" pattern, based on the following diagram:

<p align="center">
  <img width="500" height="340" src="./images/push_pull.drawio.svg">
</p>

The python client sends a message throw a PUSH file to a receiver PULL file on the mql server side. 
When the server (the metatrader client terminal), which is reading another file, process the 
message, PUSHes the answer in another file binded in this case to the receiver PULL file in the python client.

## Methods implemented.

1. Open Order. Opens an order for an instrument
2. Close Order. Closes an order based on the ticket id
3. Opened Orders. Get the opened orders info.
4. Equity. Get the trading account equity
5. Prices. Get the close bar prices based on the position (0 is the current bar).
6. Bid/Ask. Get the current market prices.

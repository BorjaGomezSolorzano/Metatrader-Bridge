//+------------------------------------------------------------------+
//|                                                    Mt4Bridge.mq4 |
//|                                      Copyright 2022, Borja Gomez |
//|                                              borjags87@gmail.com |
//|               code based on https://github.com/dingmaotu/mql-zmq |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Borja Gomez"
#property link      "borjags87@gmail.com"
#property version   "1.00"

input int MILLISECOND_TIMER = 25;

string folderName = "DWX";

string filePathSend = folderName + "/DWX_SEND.txt";
string filePathReceive = folderName + "/DWX_RECEIVE.txt";


bool WriteToFile(string text) {
   int handle = FileOpen(filePathSend, FILE_WRITE|FILE_TXT);
   if (handle == -1) return false;
   
   uint numBytesWritten = FileWriteString(handle, text);
   FileClose(handle);
   return numBytesWritten > 0;
}


void ResetFolder() {
   FolderCreate(folderName);
   FileDelete(filePathSend);
   FileDelete(filePathReceive);
}


void OnInit()
{
     EventSetMillisecondTimer(MILLISECOND_TIMER);
     
     ResetFolder();
}


void OnTimer()
{
   if (FileIsExist(filePathReceive))
   {
      int handle = FileOpen(filePathReceive, FILE_READ|FILE_TXT);  // FILE_COMMON | 
      if (handle == -1) return;
      if (handle == 0) return;
      
      string dataStr = "";
      while(!FileIsEnding(handle)) dataStr += FileReadString(handle);
      FileClose(handle);
      FileDelete(filePathReceive);
      
      string a[11];
      
      ushort u_sep = StringGetCharacter(";", 0);
      StringSplit(dataStr, u_sep, a);
      
      string zmq_ret = InterpretZmqMessage(a);
      
      WriteToFile(zmq_ret);
   }
}

void OnDeinit(const int reason) 
{
   ResetFolder();
   
   EventKillTimer();
}


// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

string InterpretZmqMessage(string& a[]) 
{
   string zmq_ret = "";
   string id = a[0];
   
   if(id == "OPENED_ORDERS") zmq_ret = GetAccountOrdersString();
   else if(id == "OPEN_ORDER") zmq_ret = GetOpenOrderString(a);
   else if(id == "CLOSE_ORDER") CloseOrder(a);
   else if(id == "PRICES_INTERVAL") zmq_ret = GetPricesInterval(a);
   else if(id == "PRICES_SAMPLED") zmq_ret = GetPricesSampled(a);
   else if(id == "EQUITY") zmq_ret = GetAccountInfoString();
   else if(id == "BID_ASK") zmq_ret = GetRatesString(a[1]);
   
   return zmq_ret;
}


void CloseOrder(string& a[])
{
   int ticket = StrToInteger(a[1]);
   string _symbol = a[2];
   int _type = StrToInteger(a[3]);
   double size = StrToDouble(a[4]);
   double _price = MarketInfo(_symbol, _type == 0 ? MODE_ASK : MODE_BID);
   double _max_slippage = StrToDouble(a[5]);
   
   OrderClose(ticket, size, _price, _max_slippage);
}


string GetOpenOrderString(string& a[])
{
   int _magic = 0;
   string _symbol = a[1];
   int _type = StrToInteger(a[2]);
   double _price = MarketInfo(_symbol, _type == 0 ? MODE_ASK : MODE_BID);
   double _lots = StrToDouble(a[3]);
   double sl = StrToDouble(a[4]);
   double tp = StrToDouble(a[5]);
   double _max_slippage = StrToDouble(a[6]);
   
   int ticket = OrderSend(_symbol, _type, _lots, _price, _max_slippage, sl, tp, "", _magic);
   
   return IntegerToString(ticket);
}


string GetPricesSampled(string& a[])
{
   string _symbol = a[1];
   int timeframe = StrToInteger(a[2]);
   int n = StrToInteger(a[3]);
   int shift = StrToInteger(a[4]);
   
   string zmq_ret = "";
   int c = 1;
   for(int i = 0; i < n; i++) {
      if(i > 0) zmq_ret += ";";
      double close = iClose(_symbol, timeframe, c);
      c += shift;
      zmq_ret += DoubleToString(close, 5);
   }
   
   return zmq_ret;
}


string GetPricesInterval(string& a[])
{
   double price_a[];
   
   int timeframe = StrToInteger(a[3]);
   
   int price_count = a[1] == "DATE" ? 
   CopyClose(a[2], timeframe, StrToTime(a[4]), StrToTime(a[5]), price_a) :
   CopyClose(a[2], timeframe, StrToInteger(a[4]), StrToInteger(a[5]), price_a);
   
   string zmq_ret = "";
   for(int i = 0; i < price_count; i++) {
      if(i > 0) zmq_ret += ";";
      zmq_ret += DoubleToString(price_a[i], 5);
   }
   
   return zmq_ret;
}


string GetAccountOrdersString()
{
   string zmq_ret = "";
   int j = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS)==false) continue;
       
      if (j > 0) zmq_ret += ";";
      
      j += 1;
      
      datetime open_dt = OrderOpenTime();
      long open_ms = (long) open_dt;
      
      zmq_ret += IntegerToString(OrderTicket()) +
                 "," + IntegerToString(OrderMagicNumber()) + 
                 "," + OrderSymbol() + 
                 "," + DoubleToString(OrderLots()) + 
                 "," + IntegerToString(OrderType()) + 
                 "," + DoubleToString(OrderOpenPrice()) + 
                 "," + IntegerToString(open_ms) + 
                 "," + DoubleToString(OrderStopLoss()) + 
                 "," + DoubleToString(OrderTakeProfit()) + 
                 "," + DoubleToString(OrderProfit()) + 
                 "," + OrderComment();
    }
    
    return zmq_ret;
}


string GetRatesString(string symbol)
{
   return DoubleToStr(MarketInfo(symbol, MODE_BID), 5) + ";" +
          DoubleToStr(MarketInfo(symbol, MODE_ASK), 5);
}


string GetAccountInfoString()
{
   return DoubleToStr(AccountEquity(), 4);
}
  
//+------------------------------------------------------------------+
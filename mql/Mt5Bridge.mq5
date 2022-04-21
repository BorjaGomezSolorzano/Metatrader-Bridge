//+------------------------------------------------------------------+
//|                                                    Mt5Bridge.mq5 |
//|                                      Copyright 2022, Borja Gomez |
//|                                              borjags87@gmail.com |
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
     
     Print(TimeTradeServer());
     
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


bool str_eq(string a, string b)
{
   return StringCompare(a, b,true) == 0;
}

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

string InterpretZmqMessage(string& a[]) 
{
   string zmq_ret = "";
   string id = a[0];
   
   if(str_eq(id, "OPENED_ORDERS"))  zmq_ret = GetAccountOrdersString();
   else if(str_eq(id, "OPEN_ORDER")) zmq_ret = GetOpenOrderString(a);
   else if(str_eq(id, "CLOSE_ORDER")) CloseOrder(a);
   else if(str_eq(id, "PRICES_INTERVAL")) zmq_ret = GetPricesInterval(a);
   else if(str_eq(id, "PRICES_SAMPLED")) zmq_ret = GetPricesSampled(a);
   else if(str_eq(id, "EQUITY")) zmq_ret = GetAccountInfoString();
   else if(str_eq(id, "BID_ASK")) zmq_ret = GetRatesString(a[1]);
   
   return zmq_ret;
}


void CloseOrder(string& a[])
{  
   MqlTradeResult result={};
   MqlTradeRequest request={};
   request.order=StringToInteger(a[1]);
   request.action=TRADE_ACTION_REMOVE;
   OrderSend(request, result);
}


string GetOpenOrderString(string& a[])
{
   string _symbol = a[1];
   double _price = 0.0;
   
   MqlTradeRequest request={};
   request.action=TRADE_ACTION_DEAL;
   request.magic=0;
   request.symbol=_symbol;
   request.volume=StringToDouble(a[3]);
   request.sl=StringToDouble(a[4]);
   request.tp=StringToDouble(a[5]);
   
   int _type_int = StringToInteger(a[2]);
   
   ENUM_ORDER_TYPE _type = NULL;
   switch(_type_int)
     {
      case(0):_type=ORDER_TYPE_BUY; break;
      case(1):_type=ORDER_TYPE_SELL; break;
     }
   
   MqlTick last_tick; 
   if(SymbolInfoTick(_symbol, last_tick))
   {
     _price = _type_int == 0 ? last_tick.ask : last_tick.bid;
   }
   
   request.type=_type;
   request.price=_price;
   
   MqlTradeResult result={};
   OrderSend(request,result);
   
   return IntegerToString(result.request_id);
}

ENUM_TIMEFRAMES get_tf(string tf) {
   if(str_eq(tf, "M1")) return PERIOD_M1;
   else if(str_eq(tf, "M5")) return PERIOD_M5;
   else if(str_eq(tf, "M15")) return PERIOD_M15;
   else if(str_eq(tf, "M30")) return PERIOD_M30;
   else if(str_eq(tf, "H1")) return PERIOD_H1;
   else if(str_eq(tf, "H4")) return PERIOD_H4;
   else if(str_eq(tf, "D1")) return PERIOD_D1;
   else if(str_eq(tf, "W1")) return PERIOD_W1;
   else if(str_eq(tf, "MN1")) return PERIOD_MN1;
   else return NULL;
}


string GetPricesSampled(string& a[])
{
   string _symbol = a[1];
   ENUM_TIMEFRAMES tf = get_tf(a[2]);
   string times_str = a[3];
   bool exact = false;
   
   string b[];
   
   ushort u_sep = StringGetCharacter(",", 0);
   int k = StringSplit(times_str, u_sep, a);
   
   string zmq_ret = "";
   for(int i = 0; i < k; i++) {
      if(i > 0) zmq_ret += ";";
      
      string time_str = b[i];
      datetime time = StringToTime(time_str);
      int bar_index=iBarShift(_symbol, tf, time, exact);
      double close = iClose(_symbol, tf, bar_index);
      
      zmq_ret += DoubleToString(close, 5);
   }
   
   return zmq_ret;
}


string GetPricesInterval(string& a[])
{
   double price_a[];
   
   string _symbol = a[2];
   string _start = a[4];
   string _end = a[5];
   ENUM_TIMEFRAMES tf = get_tf(a[3]);
   
   int price_count = str_eq(a[1], "DATE") ? 
   CopyClose(_symbol, tf, StringToTime(_start), StringToTime(_end), price_a) :
   CopyClose(_symbol, tf, StringToInteger(_start), StringToInteger(_end), price_a);
   
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
   ulong order_ticket;
   for(int i=0; i<OrdersTotal(); i++) {
      if((order_ticket=OrderGetTicket(i))<=0) continue;
       
      if (j > 0) zmq_ret += ";";
      
      j += 1;
      
      zmq_ret += IntegerToString(OrderGetInteger(ORDER_TICKET)) +
                 "," + IntegerToString(OrderGetInteger(ORDER_MAGIC)) + 
                 "," + OrderGetString(ORDER_SYMBOL) + 
                 "," + DoubleToString(OrderGetDouble(ORDER_VOLUME_INITIAL)) + 
                 "," + IntegerToString(OrderGetInteger(ORDER_TYPE)) + 
                 "," + DoubleToString(OrderGetDouble(ORDER_PRICE_OPEN)) + 
                 "," + IntegerToString(OrderGetInteger(ORDER_TIME_SETUP)) + 
                 "," + DoubleToString(OrderGetDouble(ORDER_SL)) + 
                 "," + DoubleToString(OrderGetDouble(ORDER_TP)) + 
                 "," + DoubleToString(0.0) + 
                 "," + OrderGetString(ORDER_COMMENT);
    }
    
    return zmq_ret;
}


string GetRatesString(string symbol)
{
   double bid = 0.0; double ask = 0.0;
   
   MqlTick last_tick; 
   if(SymbolInfoTick(symbol, last_tick)) 
   { 
      bid = last_tick.bid; ask = last_tick.ask;
   } 
   
   return DoubleToString(bid, 5) + ";" + DoubleToString(ask, 5);
}


string GetAccountInfoString()
{
   return DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 4);
}
  
//+------------------------------------------------------------------+
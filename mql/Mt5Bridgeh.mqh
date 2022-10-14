//+------------------------------------------------------------------+
//|                                                   Mt5Bridgeh.mqh |
//|                                      Copyright 2022, Borja Gomez |
//|                           https://github.com/BorjaGomezSolorzano |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Borja Gomez"
#property link      "https://github.com/BorjaGomezSolorzano"


#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>



bool str_eq(string a, string b)
{
   return StringCompare(a, b, true) == 0;
}


int WriteToFile(string filePath, string text)
{
   int handle = FileOpen(filePath, FILE_WRITE|FILE_ANSI|FILE_TXT);
   if (handle == -1) return -1;
   
   uint numBytesWritten = FileWriteString(handle, text);
   FileClose(handle);
   
   return numBytesWritten;
}


string ReadFile(string filePath) 
{
   int handle = FileOpen(filePath, FILE_READ|FILE_ANSI|FILE_TXT);
   if (handle == -1) return NULL;
   if (handle == 0) return NULL;
   
   string dataStr = "";
   while(!FileIsEnding(handle)) dataStr += FileReadString(handle);
   FileClose(handle);
   
   return dataStr;
}


ENUM_TIMEFRAMES get_tf(string tf) 
{
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
   int k = StringSplit(times_str, u_sep, b);
   
   string zmq_ret = "";
   for(int i = 0; i < k; i++) {
      if(i > 0) zmq_ret += ";";
      
      string time_str = b[i];
      datetime time = StringToTime(time_str);
      int bar_index=iBarShift(_symbol, tf, time, exact);
      double close = iClose(_symbol, tf, bar_index);
      double low = iLow(_symbol, tf, bar_index);
      double high = iHigh(_symbol, tf, bar_index);
      
      zmq_ret += DoubleToString(low, 5) + "," + DoubleToString(high, 5) + "," + DoubleToString(close, 5);
   }
   
   return zmq_ret;
}


string parse_prices(int price_count, double& price_a[], datetime& time_a[])
{
   string zmq_ret = "";
   for(int i = 0; i < price_count; i++) {
      if(i > 0) zmq_ret += ";";
      
      long ms = (long) time_a[i] * 1000;
      
      zmq_ret += IntegerToString(ms) + "," + DoubleToString(price_a[i], 5);
   }
   
   return zmq_ret;
}


string GetPricesInterval(string& a[])
{
   double price_a[];
   datetime time_a[];
   
   string _symbol = a[1];
   int _start = StringToInteger(a[3]);
   int count = StringToInteger(a[4])-_start+1;
   ENUM_TIMEFRAMES tf = get_tf(a[2]);
   
   int price_count = CopyClose(_symbol, tf, _start, count, price_a);
   int time_count = CopyTime(_symbol, tf, _start, count, time_a);
   
   if(price_count != time_count) return "";
   
   return parse_prices(price_count, price_a, time_a);
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


string GetAccountOrdersString()
{
   string zmq_ret = "";
   int j = 0;
   ulong order_ticket;
   
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if((order_ticket=PositionGetTicket(i))<=0) continue;
       
      if (j > 0) zmq_ret += ";";
      
      j += 1;
      
      zmq_ret += IntegerToString(PositionGetInteger(POSITION_TICKET)) +
                 "," + IntegerToString(PositionGetInteger(POSITION_MAGIC)) + 
                 "," + PositionGetString(POSITION_SYMBOL) + 
                 "," + DoubleToString(PositionGetDouble(POSITION_VOLUME)) + 
                 "," + IntegerToString(PositionGetInteger(POSITION_TYPE)) + 
                 "," + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN)) + 
                 "," + IntegerToString(PositionGetInteger(POSITION_TIME)) + 
                 "," + DoubleToString(PositionGetDouble(POSITION_SL)) + 
                 "," + DoubleToString(PositionGetDouble(POSITION_TP)) + 
                 "," + DoubleToString(0.0) + 
                 "," + PositionGetString(POSITION_COMMENT);
    }
    
    return zmq_ret;
}


void CloseOrder(string& a[])
{
   MqlTradeResult result={};
   MqlTradeRequest request={};
   
   int ticket = StringToInteger(a[1]);
   double lotsToClose = StringToDouble(a[2]);
   
   CTrade  trade;
   trade.PositionClosePartial(ticket, lotsToClose);
}



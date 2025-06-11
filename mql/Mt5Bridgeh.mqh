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


string InterpretZmqMessage(string& a[]) 
{
   string zmq_ret = "";
   string id = a[0];
   
   if(str_eq(id, "OPENED_ORDERS"))  zmq_ret = GetAccountOrdersString();
   else if(str_eq(id, "OPENED_PENDING"))  zmq_ret = GetAccountPendingString();
   else if(str_eq(id, "OPEN_ORDER")) zmq_ret = GetOpenOrderString(a);
   else if(str_eq(id, "CLOSE_ORDER")) zmq_ret = CloseOrder(a);
   else if(str_eq(id, "DELETE_PENDING")) zmq_ret = DeletePending(a);
   else if(str_eq(id, "PRICES_INTERVAL")) zmq_ret = GetPricesInterval(a);
   else if(str_eq(id, "ALL0")) zmq_ret = GetAll0(a);
   else if(str_eq(id, "MODIFY_SL_TP")) zmq_ret = ModifySLTP(a);
   else if(str_eq(id, "ALL1")) zmq_ret = GetAll1(a);
   else if(str_eq(id, "LOW")) zmq_ret = GetSampled(a);
   else if(str_eq(id, "HIGH")) zmq_ret = GetSampled(a);
   else if(str_eq(id, "CLOSE")) zmq_ret = GetSampled(a);
   else if(str_eq(id, "EQUITY")) zmq_ret = GetAccountInfoString();
   else if(str_eq(id, "BID")) zmq_ret = GetBid(a[1]);
   else if(str_eq(id, "ASK")) zmq_ret = GetAsk(a[1]);
   else if(str_eq(id, "SPREAD")) zmq_ret = GetSpread(a[1]);
   
   return zmq_ret;
}


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
   else if(str_eq(tf, "M3")) return PERIOD_M3;
   else if(str_eq(tf, "M5")) return PERIOD_M5;
   else if(str_eq(tf, "M6")) return PERIOD_M6;
   else if(str_eq(tf, "M10")) return PERIOD_M10;
   else if(str_eq(tf, "M15")) return PERIOD_M15;
   else if(str_eq(tf, "M20")) return PERIOD_M20;
   else if(str_eq(tf, "M30")) return PERIOD_M30;
   else if(str_eq(tf, "H1")) return PERIOD_H1;
   else if(str_eq(tf, "H4")) return PERIOD_H4;
   else if(str_eq(tf, "D1")) return PERIOD_D1;
   else if(str_eq(tf, "W1")) return PERIOD_W1;
   else if(str_eq(tf, "MN1")) return PERIOD_MN1;
   else return NULL;
}


string GetAll1(string& a[])
{
   string _symbols = a[1];
   string tfs = a[2];
   string times = a[3];
   
   ushort u_sep = StringGetCharacter(",", 0);
   
   string s_symbol[];
   string s_tf[];
   string s_times[];
   
   int n_symbol = StringSplit(_symbols, u_sep, s_symbol);
   int n_tf = StringSplit(tfs, u_sep, s_tf);
   StringSplit(times, u_sep, s_times);
   
   string str_ret = "";
   for(int i_symbol = 0; i_symbol < n_symbol; i_symbol++) { // PARA CADA SIMBOLO
      
      if(i_symbol > 0) str_ret += ";";
      
      string _symbol = s_symbol[i_symbol];
      
      int d = SymbolInfoInteger(_symbol, SYMBOL_DIGITS);
      
      for(int i_tf = 0; i_tf < n_tf; i_tf++) {
               
         ENUM_TIMEFRAMES tf = get_tf(s_tf[i_tf]);
         string time = s_times[i_tf];
         
         if(i_tf > 0) str_ret += "|";
         
         int bar_index = iBarShift(_symbol, tf, time, true);
         
         str_ret += DoubleToString(iClose(_symbol, tf, bar_index), d);
         str_ret += ",";
         str_ret += DoubleToString(iLow(_symbol, tf, bar_index), d);
         str_ret += ",";
         str_ret += DoubleToString(iHigh(_symbol, tf, bar_index), d);
      }
   }
   
   return str_ret;
}


string GetAll0(string& a[])
{
   string _symbol = a[1];
   ENUM_TIMEFRAMES tf = get_tf(a[2]);
   string times = a[3];
   
   ushort u_sep = StringGetCharacter(",", 0);
   
   string s_times[];
   
   int n = StringSplit(times, u_sep, s_times);
   
   int d = SymbolInfoInteger(_symbol, SYMBOL_DIGITS);
    
   string b[];
   
   string zmq_ret = "";
   for(int i = 0; i < n; i++) {
      if(i > 0) zmq_ret += ",";
      
      string time = s_times[i];
      
      int bar_index = iBarShift(_symbol, tf, time, true);
      
      zmq_ret += DoubleToString(iLow(_symbol, tf, bar_index), d) + ";" +
                 DoubleToString(iHigh(_symbol, tf, bar_index), d)  + ";" +
                 DoubleToString(iClose(_symbol, tf, bar_index), d) + ";" +
                 DoubleToString(iOpen(_symbol, tf, bar_index), d);
   }
   
   return zmq_ret;
}


string GetSampled(string& a[])
{
   string type = a[0];
   string _symbol = a[1];
   ENUM_TIMEFRAMES tf = get_tf(a[2]);
   string times_str = a[3];
   bool exact = false;
   
   int d = SymbolInfoInteger(_symbol, SYMBOL_DIGITS);
   
   string b[];
   
   ushort u_sep = StringGetCharacter(",", 0);
   int k = StringSplit(times_str, u_sep, b);
   
   string zmq_ret = "";
   for(int i = 0; i < k; i++) {
      if(i > 0) zmq_ret += ",";
      
      datetime time = StringToTime(b[i]);
      int bar_index=iBarShift(_symbol, tf, time, exact);
      
      if(str_eq(type, "LOW")) zmq_ret += DoubleToString(iLow(_symbol, tf, bar_index), d);
      else if(str_eq(type, "HIGH")) zmq_ret += DoubleToString(iHigh(_symbol, tf, bar_index), d);
      else if(str_eq(type, "CLOSE")) zmq_ret += DoubleToString(iClose(_symbol, tf, bar_index), d);
   }
   
   return zmq_ret;
}


string parse_prices(int price_count, double& price_a[], datetime& time_a[], int d)
{
   string zmq_ret = "";
   for(int i = 0; i < price_count; i++) {
      if(i > 0) zmq_ret += ";";
      
      long ms = (long) time_a[i] * 1000;
      
      zmq_ret += IntegerToString(ms) + "," + DoubleToString(price_a[i], d);
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
   
   int d = SymbolInfoInteger(_symbol, SYMBOL_DIGITS);
   
   int price_count = CopyClose(_symbol, tf, _start, count, price_a);
   int time_count = CopyTime(_symbol, tf, _start, count, time_a);
   
   if(price_count != time_count) return "";
   
   return parse_prices(price_count, price_a, time_a, d);
}


string GetAsk(string symbol)
{
   double ask = 0.0;
   
   MqlTick last_tick; 
   if(SymbolInfoTick(symbol, last_tick)) ask = last_tick.ask;
   
   int d = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   return DoubleToString(ask, d);
}


string GetBid(string symbol)
{
   double bid = 0.0;
   
   MqlTick last_tick; 
   if(SymbolInfoTick(symbol, last_tick)) bid = last_tick.bid;
   
   int d = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   return DoubleToString(bid, d);
}


string GetAccountInfoString()
{
   return DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 4);
}


string GetSpread(string symbol)
{
   int spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);

   if(spread_points != WRONG_VALUE)
     {
      return IntegerToString(spread_points);
     }
   else
     {
      return "-1";
     }
}


string GetOpenOrderString(string& a[])
{
   string _symbol = a[1];

   double max_slippage = StringToDouble(a[8]);
   double spreadPoints = SymbolInfoInteger(_symbol, SYMBOL_SPREAD); // Spread en puntos

   if (spreadPoints > max_slippage)
   {
      return "-1";
   }

   double _price = 0.0;
   
   MqlTradeRequest request={};
   request.magic=0;
   request.symbol=_symbol;
   request.volume=StringToDouble(a[3]); // OK
   request.sl=StringToDouble(a[5]); // OK
   request.tp=StringToDouble(a[6]); // OK
   request.comment = a[7];
   
   int _type_int = StringToInteger(a[2]); // OK
   
   ENUM_ORDER_TYPE _type = NULL;
   switch(_type_int)
     {
      case(0):_type=ORDER_TYPE_BUY; break;
      case(1):_type=ORDER_TYPE_SELL; break;
      case(2):_type=ORDER_TYPE_BUY_LIMIT; break;
      case(3):_type=ORDER_TYPE_SELL_LIMIT; break;
      case(4):_type=ORDER_TYPE_BUY_STOP; break;
      case(5):_type=ORDER_TYPE_SELL_STOP; break;
     }
   
   if(_type_int == 0 || _type_int == 1) // OK
   {
      request.action=TRADE_ACTION_DEAL;
      
      MqlTick last_tick; 
      if(SymbolInfoTick(_symbol, last_tick))
      {
        _price = _type_int == 0 ? last_tick.ask : last_tick.bid;
      }
   } else if(2 <= _type_int <= 5) { // OK
      request.action=TRADE_ACTION_PENDING;
   
      _price = StringToDouble(a[4]);
   }
   
   request.type=_type;
   request.price=_price;
   
   MqlTradeResult result={};
   CTrade trade;
   if(!trade.OrderSend(request, result)) {
      return "0";
   }
   
   return IntegerToString(result.order);
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
                 "," + DoubleToString(PositionGetDouble(POSITION_PROFIT)) + 
                 "," + PositionGetString(POSITION_COMMENT);
    }
    
    return "["+zmq_ret+"]";
}


string GetAccountPendingString()
{
   string zmq_ret = "";
   int j = 0;
   ulong order_ticket;
   
   for(int i=OrdersTotal()-1; i>=0; i--) {
      if(order_ticket=OrderGetTicket(i) <= 0) continue;
      
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
   
   return "["+zmq_ret+"]"; 
 }


string CloseOrder(string& a[])
{
   ulong ticket = StringToInteger(a[1]);
   double lotsToClose = StringToDouble(a[2]);
   
   CTrade  trade;
   if(lotsToClose > 0) {
      if(trade.PositionClosePartial(ticket, lotsToClose)) {
         return "1";
      }
   } else {
      if(trade.PositionClose(ticket)) {
         return "1";
      }
   }
   
   return "0";
}


string DeletePending(string& a[])
{
    ulong ticket = StringToInteger(a[1]);
    
    CTrade  trade;
    if(trade.OrderDelete(ticket)) {
        return "1";
    }
    
    return "0";
}


string ModifySLTP(string& a[])
{
   ulong ticket = StringToInteger(a[1]);
   
   if(!PositionSelectByTicket(ticket))
     {
      PrintFormat("PositionSelectByTicket(%I64u) failed. Error %d", ticket, GetLastError());
      return "0";
     }
   
   ENUM_POSITION_TYPE type  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string             symbol= PositionGetString(POSITION_SYMBOL);
   int                digits= (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   double sl = NormalizeDouble(a[2], digits);
   double tp = NormalizeDouble(a[3], digits);
   
   double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * pointSize;
   
   CTrade  trade;
   
   MqlTick last_tick; 
   if(SymbolInfoTick(symbol, last_tick))
   {
     if(type==POSITION_TYPE_SELL) {
         if (last_tick.ask + stopLevel < sl) {
            if(trade.PositionModify(ticket, sl, tp)) {
               return "1";
            }
         } else { //CLOSE ORDER
            if(trade.PositionClose(ticket)) {
               return "1";
            }
         }
     } else if(type==POSITION_TYPE_BUY) {
         if (last_tick.bid - stopLevel > sl) {
            if(trade.PositionModify(ticket, sl, tp)) {
               return "1";
            }
         } else { //CLOSE ORDER
            if(trade.PositionClose(ticket)) {
               return "1";
            }
         }
     }
   }
   
   return "0";
}


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
   else if(str_eq(id, "LAST_NOHLC")) zmq_ret = GetN_OHLC(a);
   else if(str_eq(id, "ALL0")) zmq_ret = GetAll0(a);
   else if(str_eq(id, "MODIFY_SL_TP")) zmq_ret = ModifySLTP(a);
   else if(str_eq(id, "EQUITY")) zmq_ret = GetAccountInfoString();
   else if(str_eq(id, "BID")) zmq_ret = GetBid(a[1]);
   else if(str_eq(id, "ASK")) zmq_ret = GetAsk(a[1]);
   else if(str_eq(id, "SPREAD")) zmq_ret = GetSpread(a[1]);
   else if(str_eq(id, "SYMBOL_INFO")) zmq_ret = GetSymbolInfo(a[1]);
   
   return zmq_ret;
}


string GetDayName(ENUM_DAY_OF_WEEK day)
{
   switch(day)
   {
      case SUNDAY:    return "SUN";
      case MONDAY:    return "MON";
      case TUESDAY:   return "TUE";
      case WEDNESDAY: return "WED";
      case THURSDAY:  return "THU";
      case FRIDAY:    return "FRI";
      case SATURDAY:  return "SAT";
   }

   return "";
}


string GetTradingHoursForDay(
   string symbol,
   ENUM_DAY_OF_WEEK day
)
{
   string sessions = "";
   uint session_index = 0;

   while(true)
   {
      datetime from;
      datetime to;

      if(!SymbolInfoSessionTrade(
            symbol,
            day,
            session_index,
            from,
            to))
      {
         break;
      }

      string from_str = TimeToString(
         from,
         TIME_MINUTES
      );

      string to_str = TimeToString(
         to,
         TIME_MINUTES
      );

      if(sessions != "")
         sessions += "|";

      sessions += from_str + "-" + to_str;

      session_index++;
   }

   if(sessions == "")
      return "CLOSED";

   return sessions;
}


string GetTradingHours(string symbol)
{
   string result = "";

   for(int d = SUNDAY; d <= SATURDAY; d++)
   {
      ENUM_DAY_OF_WEEK day =
         (ENUM_DAY_OF_WEEK)d;

      string sessions =
         GetTradingHoursForDay(
            symbol,
            day
         );

      if(result != "")
         result += ";";

      result +=
         GetDayName(day)
         + "="
         + sessions;
   }

   return result;
}


string GetSymbolInfo(string symbol)
{
   double cs   = 0.0;
   double vmin = 0.0;

   if(!SymbolInfoDouble(
         symbol,
         SYMBOL_TRADE_CONTRACT_SIZE,
         cs))
   {
      PrintFormat(
         "No se pudo leer CONTRACT_SIZE de %s. Error=%d",
         symbol,
         GetLastError()
      );
   }

   if(!SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MIN,
         vmin))
   {
      PrintFormat(
         "No se pudo leer VOLUME_MIN de %s. Error=%d",
         symbol,
         GetLastError()
      );
   }

   string trading_hours =
      GetTradingHours(symbol);

   return
      DoubleToString(cs, 4)
      + ","
      + DoubleToString(vmin, 4)
      + ","
      + trading_hours;
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
   else if(str_eq(tf, "M2")) return PERIOD_M2;
   else if(str_eq(tf, "M3")) return PERIOD_M3;
   else if(str_eq(tf, "M5")) return PERIOD_M5;
   else if(str_eq(tf, "M6")) return PERIOD_M6;
   else if(str_eq(tf, "M10")) return PERIOD_M10;
   else if(str_eq(tf, "M12")) return PERIOD_M12;
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


string GetAll0(string& a[])
{
   string _symbol = a[1];
   ENUM_TIMEFRAMES tf = get_tf(a[2]);
   string times = a[3];

   ushort u_sep = StringGetCharacter(",", 0);
   string s_times[];
   int n = StringSplit(times, u_sep, s_times);

   int d = (int)SymbolInfoInteger(_symbol, SYMBOL_DIGITS);

   string zmq_ret = "";
   bool first = true;

   for(int i = 0; i < n; i++)
   {
      datetime dt = StringToTime(s_times[i]);
      if(dt <= 0) continue;

      int bar_index = iBarShift(_symbol, tf, dt, true); // exacto
      if(bar_index < 0) continue; // no hay vela exacta -> no devolvemos nada

      datetime t = iTime(_symbol, tf, bar_index);
      long t_ms = (long)t * 1000;

      if(!first) zmq_ret += ",";
      first = false;

      zmq_ret += (string)t_ms + ";" +
                 DoubleToString(iLow(_symbol, tf, bar_index),   d) + ";" +
                 DoubleToString(iHigh(_symbol, tf, bar_index),  d) + ";" +
                 DoubleToString(iClose(_symbol, tf, bar_index), d) + ";" +
                 DoubleToString(iOpen(_symbol, tf, bar_index),  d);
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


/*
  Devuelve true si pudo copiar datos.
  - symbol:           "EURUSD", "XAUUSD", etc. Usa _Symbol si quieres el actual
  - timeframe:        p.ej. PERIOD_M1, PERIOD_M5, PERIOD_H1...
  - n:                número de barras a recuperar
  - closed_only:      true -> SOLO barras cerradas (empieza en shift=1)
                      false -> incluye la barra actual (shift=0)
  - out_open/high/low/close/out_time: arrays de salida en ORDEN CRONOLÓGICO
*/
// Devuelve: "low;high;close;open,low;high;close;open,..." (N barras)
// a[] esperado: a[1]=symbol, a[2]=tf, a[3]=until_dt_str, a[4]=N
string GetN_OHLC(string& a[])
{
   string _symbol = a[1];
   ENUM_TIMEFRAMES tf = get_tf(a[2]);
   int n = (int)StringToInteger(a[3]);
   string before_str = a[4];

   if(n <= 0)
      return "";

   datetime before_dt = StringToTime(before_str);

   if(before_dt <= 0)
      return "";

   if(!SymbolSelect(_symbol, true))
      return "";

   int digits = (int)SymbolInfoInteger(_symbol, SYMBOL_DIGITS);
   int bars_total = Bars(_symbol, tf);

   if(bars_total <= 1)
      return "";

   /*
      iBarShift(..., false) devuelve la barra más reciente cuyo tiempo
      de apertura es menor o igual que before_dt.
   */
   int start = iBarShift(_symbol, tf, before_dt, false);

   if(start < 0)
      return "";

   // La barra 0 sigue abierta, por lo que nunca se incluye.
   if(start < 1)
      start = 1;

   /*
      La condición solicitada es estricta:
      bar_time < before_dt.

      Si la fecha coincide exactamente con la apertura de una barra,
      pasamos a la barra anterior.
   */
   while(start < bars_total &&
         iTime(_symbol, tf, start) >= before_dt)
   {
      start++;
   }

   if(start >= bars_total)
      return "";

   int take = MathMin(n, bars_total - start);
   string zmq_ret = "";

   for(int k = 0; k < take; k++)
   {
      int bar_index = start + k;
      datetime bar_time = iTime(_symbol, tf, bar_index);

      // Comprobación adicional por seguridad.
      if(bar_index < 1 || bar_time >= before_dt)
         continue;

      if(zmq_ret != "")
         zmq_ret += ",";

      string bar_time_str = TimeToString(
         bar_time,
         TIME_DATE | TIME_MINUTES
      );

      zmq_ret += bar_time_str + ";" +
                 DoubleToString(iLow(_symbol, tf, bar_index),   digits) + ";" +
                 DoubleToString(iHigh(_symbol, tf, bar_index),  digits) + ";" +
                 DoubleToString(iClose(_symbol, tf, bar_index), digits) + ";" +
                 DoubleToString(iOpen(_symbol, tf, bar_index),  digits);
   }

   return zmq_ret;
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
   string symbol = a[1];

   // a[8] representa el spread máximo permitido, expresado en puntos.
   double maxSpreadPoints = StringToDouble(a[8]);

   // La desviación de ejecución es independiente del spread.
   ulong maxDeviationPoints = (ulong)StringToInteger(a[9]);

   MqlTick lastTick;
   if(!SymbolInfoTick(symbol, lastTick))
   {
      PrintFormat("No se pudo obtener el precio actual de %s", symbol);
      return "-1";
   }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0)
   {
      PrintFormat("SYMBOL_POINT no válido para %s", symbol);
      return "-1";
   }

   double spreadPoints = (lastTick.ask - lastTick.bid) / point;

   if(spreadPoints > maxSpreadPoints)
   {
      PrintFormat(
         "Orden descartada: símbolo=%s spread=%.1f puntos máximo=%.1f",
         symbol,
         spreadPoints,
         maxSpreadPoints
      );
      return "-1";
   }

   int typeInt = StringToInteger(a[2]);

   ENUM_ORDER_TYPE orderType;

   switch(typeInt)
   {
      case 0:
         orderType = ORDER_TYPE_BUY;
         break;

      case 1:
         orderType = ORDER_TYPE_SELL;
         break;

      case 2:
         orderType = ORDER_TYPE_BUY_LIMIT;
         break;

      case 3:
         orderType = ORDER_TYPE_SELL_LIMIT;
         break;

      case 4:
         orderType = ORDER_TYPE_BUY_STOP;
         break;

      case 5:
         orderType = ORDER_TYPE_SELL_STOP;
         break;

      default:
         PrintFormat("Tipo de orden no válido: %d", typeInt);
         return "-1";
   }

   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.magic     = 0;
   request.symbol    = symbol;
   request.volume    = StringToDouble(a[3]);
   request.sl        = StringToDouble(a[5]);
   request.tp        = StringToDouble(a[6]);
   request.comment   = a[7];
   request.type      = orderType;
   request.deviation = maxDeviationPoints;

   if(typeInt == 0 || typeInt == 1)
   {
      request.action = TRADE_ACTION_DEAL;
      request.price = typeInt == 0
         ? lastTick.ask
         : lastTick.bid;
   }
   else if(typeInt >= 2 && typeInt <= 5)
   {
      request.action = TRADE_ACTION_PENDING;
      request.price = StringToDouble(a[4]);
   }

   CTrade trade;

   if(!trade.OrderSend(request, result))
   {
      PrintFormat(
         "OrderSend falló: retcode=%u comentario=%s",
         result.retcode,
         result.comment
      );
      return "0";
   }

   if(result.retcode != TRADE_RETCODE_DONE &&
      result.retcode != TRADE_RETCODE_PLACED &&
      result.retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      PrintFormat(
         "Orden rechazada: retcode=%u comentario=%s bid=%f ask=%f",
         result.retcode,
         result.comment,
         result.bid,
         result.ask
      );
      return "0";
   }

   PrintFormat(
      "Orden aceptada: order=%I64u deal=%I64u precio=%f spread=%.1f",
      result.order,
      result.deal,
      result.price,
      spreadPoints
   );

   if(result.order > 0)
      return IntegerToString(result.order);

   return IntegerToString(result.deal);
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

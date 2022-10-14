//+------------------------------------------------------------------+
//|                                                    Mt5Bridge.mq5 |
//|                                      Copyright 2022, Borja Gomez |
//|                           https://github.com/BorjaGomezSolorzano |
//+------------------------------------------------------------------+

#include <Mt5Bridgeh.mqh>

#property copyright "Copyright 2022, Borja Gomez"
#property link      "https://github.com/BorjaGomezSolorzano"
#property version   "1.00"

input int MILLISECOND_TIMER = 25;

string folderName = "BRIDGE";

string filePathSend = folderName + "/SEND.txt";
string filePathReceive = folderName + "/RECEIVE.txt";


void ResetFolder() 
{
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
      string dataStr = ReadFile(filePathReceive);
      if(dataStr == NULL) return;
      
      FileDelete(filePathReceive);
      
      string a[11];
      
      ushort u_sep = StringGetCharacter(";", 0);
      StringSplit(dataStr, u_sep, a);
      
      string zmq_ret = InterpretZmqMessage(a);
      
      if(WriteToFile(filePathSend, zmq_ret) < 0) return;
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
   
   if(str_eq(id, "OPENED_ORDERS"))  zmq_ret = GetAccountOrdersString();
   else if(str_eq(id, "OPEN_ORDER")) zmq_ret = GetOpenOrderString(a);
   else if(str_eq(id, "CLOSE_ORDER")) CloseOrder(a);
   else if(str_eq(id, "PRICES_INTERVAL")) zmq_ret = GetPricesInterval(a);
   else if(str_eq(id, "PRICES_SAMPLED")) zmq_ret = GetPricesSampled(a);
   else if(str_eq(id, "EQUITY")) zmq_ret = GetAccountInfoString();
   else if(str_eq(id, "BID_ASK")) zmq_ret = GetRatesString(a[1]);
   
   return zmq_ret;
}
  
//+------------------------------------------------------------------+
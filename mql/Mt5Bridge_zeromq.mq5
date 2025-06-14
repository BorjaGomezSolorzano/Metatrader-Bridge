//+------------------------------------------------------------------+
//|                                                    Mt5Bridge.mq5 |
//|                                      Copyright 2023, Borja Gomez |
//|                           https://github.com/BorjaGomezSolorzano |
//+------------------------------------------------------------------+

#include <Mt5Bridgeh.mqh>
#include <Zmq/Zmq.mqh>

#property copyright "Copyright 2023, Borja Gomez"
#property link      "https://github.com/BorjaGomezSolorzano"
#property version   "1.00"


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Context context("bridge");
   Socket socket(context, ZMQ_REP);

   socket.bind("tcp://127.0.0.1:5555");

   while(!IsStopped())
     {
      ZmqMsg request;
      
      // Wait for next request from client

      // MetaTrader note: this will block the script thread
      // and if you try to terminate this script, MetaTrader
      // will hang (and crash if you force closing it)
      if(socket.recv(request))
      {
         string dataStr = request.getData();
      
         string a[11];
         
         ushort u_sep = StringGetCharacter(";", 0);
         StringSplit(dataStr, u_sep, a);
         
         string zmq_ret = InterpretZmqMessage(a);
         
         ZmqMsg reply(zmq_ret);
         // Send reply back to client
         
         socket.send(reply);      
      }
      else
     {
      // Si no hay mensaje, esperar unos milisegundos para ceder la CPU
      Sleep(10);
     }

     }
    return INIT_SUCCEEDED;
}

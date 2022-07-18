#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Feb 11 23:28:24 2022
@author: borja
"""

from time import sleep
import numpy as np
import logging
import codecs
import os


class Client:
    
    
    def __init__(self, folderName):
        #folderName = "C:/Users/Borja/AppData/Roaming/MetaQuotes/Terminal/D0E8209F77C8CF37AD8BF550E51FF075/MQL5/Files/BRIDGE"
        #folderName = "/home/borja/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/BRIDGE"
        
        self.filePathSend = folderName + "/SEND.txt";
        self.filePathReceive = folderName + "/RECEIVE.txt";
        self._encoding = 'utf-8'    
    
    
    def remote_send(self, _data, secs_sleep=1):
        with codecs.open(self.filePathReceive,'w',encoding=self._encoding) as f:
            f.write(_data)
        
        sleep(secs_sleep)
    
    
    def read(self):
        with codecs.open(self.filePathSend,'r',encoding=self._encoding) as f:
            return f.read()
        
    
    def remote_recv(self, _data_to_send, secs_sleep=1):
        data = None
        
        i = 0
        while not os.path.exists(self.filePathSend) and i < 5:
            sleep(2)
            
            i += 1
        
        if os.path.exists(self.filePathSend):
            
            i = 0
            while i < 5:
                try:
                    data = self.read()
                except PermissionError:
                    logging.error('PERMISSION ERROR')
                    
                    sleep(2)
                    
                    i += 1
                    
                    continue
                
                if (data is not None and len(data) > 0): break 
                
                if data is None or len(data) == 0:
                    os.remove(self.filePathSend)
                    
                    self.remote_send(_data_to_send, secs_sleep)
                    
                    sleep(2)
                
                i += 1
            
            os.remove(self.filePathSend)
        
        if data is None or len(data) == 0: print('NO DATA')
        
        return data
    
    
    def open_order(self, _symbol = "EURUSD", _lots = 0.01, _type = 0, _sl = 0, _tp = 0, 
                   _max_slippage = 0.1): #0: Buy, 1: Sell
        
        _send = "OPEN_ORDER;{0};{1};{2};{3};{4};{5}".format(_symbol, _type, _lots, \
                                                _sl, _tp, _max_slippage)
        
        self.remote_send(_send)
        
        message = self.remote_recv(_send)
        
        logging.info(f'Open order {message}')
        
    
    def close_order(self, ticket, _symbol, _type, _lots, max_slippage):
        
        _send = "CLOSE_ORDER;{0};{1};{2};{3};{4}".format(ticket, _symbol, _type, _lots, \
                                                max_slippage)
        
        self.remote_send(_send)
        
        logging.info(f'Close order {ticket}')
            
    
    def opened_orders(self):
        _send = "OPENED_ORDERS"
        
        self.remote_send(_send)
        
        _opened = self.remote_recv(_send)
        
        if _opened == '': return []
        
        orders_str = _opened.split(';')
        
        orders = []
        for o_str in orders_str:
            
            o = o_str.split(',')
            
            orders.append( (
                int(o[0]), #OrderTicket
                int(o[1]), #MagicNumber
                o[2], #OrderSymbol
                float(o[3]), #OrderLots
                int(o[4]), #OrderType
                float(o[5]), #OpenPrice
                int(o[6]), #OpenTime
                float(o[7]), #StopLoss
                float(o[8]), #TakeProfit
                float(o[9]), #Profit
                o[10] #Comment
                ) )
        
        return orders
    
    
    def equity(self):
        _send = "EQUITY"
        
        self.remote_send(_send)
        
        message = self.remote_recv(_send)
        
        return float(message)
        
    
    def prices_temp(self, _symbol, _tf, _start, _end, _type='PRICES_INTERVAL', secs_sleep=1):
        
        _send = "{};{};{};{};{}".format(_type, _symbol, _tf, _start, _end)
        
        self.remote_send(_send, secs_sleep)
        
        message = self.remote_recv(_send, secs_sleep)
        
        vs = message.split(";")
        
        s = len(vs)
        
        prices = np.zeros(s, dtype=np.float32)
        ts = np.zeros(s, dtype=np.int64)
        for i, v in enumerate(vs):
            spt_v = v.split(",")
            
            ts[i] = int(spt_v[0])
            prices[i] = float(spt_v[1])
        
        return ts, prices
    
    
    def prices_interval(self, _symbol, _tf, _start, _end, secs_sleep=1):
        
        return self.prices_temp(_symbol, _tf, _start, _end, _type='PRICES_INTERVAL', secs_sleep=1)
    
    
    def prices_sampled(self, _symbol, _tf, times_str, secs_sleep=0.1):
        
        _send = "PRICES_SAMPLED;{0};{1};{2}".format(_symbol, _tf, times_str)
        
        self.remote_send(_send, secs_sleep)
        
        message = self.remote_recv(_send)
        
        vs = message.split(";")
        
        s = len(vs)
        
        low = np.zeros(s, dtype=np.float32)
        high = np.zeros(s, dtype=np.float32)
        close = np.zeros(s, dtype=np.float32)
        for i, v in enumerate(vs):
            spt_v = v.split(",")
            
            low[i] = float(spt_v[0])
            high[i] = float(spt_v[1])
            close[i] = float(spt_v[2])
        
        return low, high, close
        
    
    def bid_ask(self, _symbol = 'EURUSD'):
        _send = "BID_ASK;{0}".format(_symbol)
        
        self.remote_send(_send)
        
        message = self.remote_recv(_send)

        ba = message.split(";")
        
        return float(ba[0]), float(ba[1])
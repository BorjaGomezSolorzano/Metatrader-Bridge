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
    
    
    def __init__(self):
        #folderName = "C:/Users/Borja/AppData/Roaming/MetaQuotes/Terminal/50CA3DFB510CC5A8F28B48D1BF2A5702/MQL4/Files/BRIDGE"
        folderName = "/home/borja/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/DWX"
        
        self.filePathSend = folderName + "/SEND.txt";
        self.filePathReceive = folderName + "/RECEIVE.txt";
        self._encoding = 'utf-8'    
    
    
    def remote_send(self, _data):
        with codecs.open(self.filePathReceive,'w',encoding=self._encoding) as f:
            f.write(_data)
        
        sleep(1)
    
    
    def read(self):
        with codecs.open(self.filePathSend,'r',encoding=self._encoding) as f:
            return f.read()
        
    
    def remote_recv(self, _data_to_send):
        data = None
        
        i = 0
        while not os.path.exists(self.filePathSend) and i < 5:
            sleep(2)
            
            i += 1
        
        if os.path.exists(self.filePathSend):
            
            i = 0
            while i < 5:
                data = self.read()
                
                if (data is not None and len(data) > 0): break 
                
                if data is None or len(data) == 0:
                    os.remove(self.filePathSend)
                    
                    self.remote_send(_data_to_send)
                    
                    sleep(2)
                
                i += 1
            
            os.remove(self.filePathSend)
        
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
        
    
    def prices_interval(self, _symbol='USDJPY', _tf = 'H4', _start=1, _end=30):
        
        _send = "PRICES_INTERVAL;POSITION;{0};{1};{2};{3}".format(_symbol, _tf, _start, _end)
        
        self.remote_send(_send)
        
        message = self.remote_recv(_send)
        
        vs = message.split(";")
        
        s = _end-_start+1
        
        prices = np.zeros(s, dtype=np.float32)
        ts = np.zeros(s, dtype=np.int64)
        for i, v in enumerate(vs):
            spt_v = v.split(",")
            
            ts[i] = int(spt_v[0])
            prices[i] = float(spt_v[1])
        
        return ts, prices
    
    
    def prices_sampled(self, _symbol='USDJPY', _tf = 1, n=1, shift=30):
        
        _send = "PRICES_SAMPLED;{0};{1};{2};{3}".format(_symbol, _tf, n, shift)
        
        self.remote_send(_send)
        
        message = self.remote_recv(_send)
        
        ps = message.split(";")
        
        return np.array([float(p) for p in ps]) if ps[0] != '' else  np.array([])
        
    
    def bid_ask(self, _symbol = 'EURUSD'):
        _send = "BID_ASK;{0}".format(_symbol)
        
        self.remote_send(_send)
        
        message = self.remote_recv(_send)

        ba = message.split(";")
        
        return float(ba[0]), float(ba[1])
    

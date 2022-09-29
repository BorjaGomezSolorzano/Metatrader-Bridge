#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Feb 11 23:28:24 2022
@author: borja

https://github.com/BorjaGomezSolorzano/Metatrader-Bridge
"""

from datetime import datetime, timedelta
from time import sleep
import numpy as np
import logging
import codecs
import pytz
import os



class Client:
    
    local_tz = pytz.timezone("America/New_York")
    epoch = pytz.timezone("UTC").localize(datetime.utcfromtimestamp(0))
    
    offset = timedelta(seconds=3_600)
    
    _3H_secs = 3 * 60 * 60
    _2H_secs = 2 * 60 * 60
    
    
    def __init__(self):
        folderName = "C:/Users/Borja/AppData/Roaming/MetaQuotes/Terminal/FAA514E52C3E4D1EE11C384C6086D979/MQL5/Files/BRIDGE"
        
        self.filePathSend = folderName + "/SEND.txt";
        self.filePathReceive = folderName + "/RECEIVE.txt";
        self._encoding = 'utf-8'    
    
    
    def get_server_time_str(self, t_utc):
        dt_utc = datetime.utcfromtimestamp(t_utc)    
        td1 = self.local_tz.localize(dt_utc).dst()
        
        t_gmt3 = t_utc + (self._3H_secs if td1 == self.offset else self._2H_secs)
        
        dt = datetime.utcfromtimestamp(t_gmt3)
        
        return dt.strftime("%Y.%m.%d %H:%M:%S")

    
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
        
        if data is None or len(data) == 0: logging.info('NO DATA')
        
        return data
    
    
    def open_order(self, _symbol = "EURUSD", _lots = 0.01, _price=0.0, _type = 0, _sl = 0, _tp = 0, 
                   _max_slippage = 0.1): #0: Buy, 1: Sell, 2: Buy limit, 3: Sell limit, 4: Buy Stop, 5: Sell Stop
    
        _send = "OPEN_ORDER;{0};{1};{2};{3};{4};{5};{6}".format(_symbol, _type, _lots, _price, \
                                                                _sl, _tp, _max_slippage)
        
        self.remote_send(_send)
        
        message = self.remote_recv(_send)
        
        logging.info(f'Open order {message}')
        
    
    def close_order(self, ticket, _lots):
        
        _send = "CLOSE_ORDER;{0};{1}".format(ticket, _lots)
        
        self.remote_send(_send)
        
        logging.info(f'Close order {ticket}')
        
    
    def opened_orders(self):
        '''
        OrderTicket: 0, MagicNumber: 1, OrderSymbol: 2, OrderLots: 3, OrderType: 4, OpenPrice: 5
        OpenTime: 6, StopLoss: 7, TakeProfit: 8, Profit: 9, Comment: 10
        '''
        
        _send = "OPENED_ORDERS"
        
        self.remote_send(_send)
        
        _opened = self.remote_recv(_send)
        
        orders = []
        
        if _opened == '': return orders
        
        for o_str in _opened.split(';'):
            o = o_str.split(',')
            
            orders.append( (
                int(o[0]), int(o[1]), o[2], float(o[3]), int(o[4]), float(o[5]), 
                int(o[6]), float(o[7]), float(o[8]), float(o[9]), o[10] 
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
    
    
    def prices_sampled(self, _symbol, _tf, ts, secs_sleep=0.1):
        
        times_str = ','.join([self.get_server_time_str(t) for t in ts])
        
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
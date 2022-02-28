#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Feb 11 23:28:24 2022

@author: borja
"""

from time import sleep
import numpy as np
import logging
import zmq


class Client:
    
    def __init__(self):
        self.context = zmq.Context()
        
        self.sender = self.context.socket(zmq.PUSH)
        self.sender.connect("tcp://localhost:5555")
        
        self.receiver = self.context.socket(zmq.PULL)
        self.receiver.connect("tcp://localhost:5556")
        
    
    def open_order(self, _symbol = "EURUSD", _lots = 0.01, _type = 0, _sl = 0, _tp = 0, 
                   _max_slippage = 0.1): #0: Buy, 1: Sell
        
        _send = "OPEN_ORDER;{0};{1};{2};{3};{4};{5}".format(_symbol, _type, _lots, \
                                                _sl, _tp, _max_slippage).encode()
        
        self.sender.send(_send)
        
        sleep(1)
        
        message = self.receiver.recv()
        
        logging.info(f'Open order {message.decode("utf-8")}')
        
    
    def close_order(self, ticket, _symbol, _type, _lots, max_slippage):
        
        _send = "CLOSE_ORDER;{0};{1};{2};{3};{4}".format(ticket, _symbol, _type, _lots, \
                                                max_slippage).encode()
        
        self.sender.send(_send)
        
        logging.info(f'Close order {ticket}')
            
    
    def opened_orders(self):
        self.sender.send(b"OPENED_ORDERS")
        
        sleep(1)
        
        message = self.receiver.recv()
        
        _opened = message.decode("utf-8")
        
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
        self.sender.send(b"EQUITY")
        
        sleep(1)
        
        message = self.receiver.recv()
        
        return float(message.decode("utf-8"))
        
    
    def prices(self, _symbol='USDJPY', _tf = 1, _start=1, _end=30):
        
        _send = "PRICES;POSITION;{0};{1};{2};{3}".format(_symbol, _tf, _start, _end).encode()
        
        self.sender.send(_send)
        
        sleep(1)
        
        message = self.receiver.recv()
        
        ps = message.decode("utf-8").split(";")
        
        return np.array([float(p) for p in ps]) if ps[0] != '' else  np.array([])
    
    
    def bid_ask(self, _symbol = 'EURUSD'):
        _send = "BID_ASK;{0}".format(_symbol).encode()
        
        self.sender.send(_send)
        
        sleep(1)
        
        message = self.receiver.recv()

        ba = message.decode("utf-8").split(";")
        
        return float(ba[0]), float(ba[1]) if len(ba) == 2 else 0, 0
    
    
    def exit(self):
        self.sender.close()
        self.receiver.close()
        self.context.term()
            

def test():
    
    client = Client()
    
    #client.close_order(ticket=197709057, _symbol='EURUSD', _type=0, _lots=0.01, max_slippage=0.1)
    
    #client.open_order()
    
    #print('Open orders:', client.opened_orders())
    print('prices', client.prices(_symbol='GBPUSD'))
    
    '''
    print('equity', client.equity())
    print('bid/ask', client.bid_ask())
    '''

    client.exit()    
    

if __name__ == '__main__':
    
    test()
    

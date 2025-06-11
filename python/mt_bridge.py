#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Feb 11 23:28:24 2022
@author: Borja Gomez
"""

from time import sleep

import numpy as np

import zmq

import logging
logger = logging.getLogger(__name__)


TICKET=0
MAGIC_NUMBER=1
SYMBOL=2
LOTS=3
TYPE=4
PRICE=5
TIME=6
SL=7
TP=8
PROFIT=9
COMMENT=10


class Socket:
    
    
    def __init__(self):
        self.context = zmq.Context()
        
        self.socket = self.create_socket()

        self.poller = zmq.Poller()
        self.poller.register(self.socket, zmq.POLLIN)
    
    
    def create_socket(self):
        sock = self.context.socket(zmq.REQ)
        sock.connect("tcp://127.0.0.1:5555")
        return sock


    def remote_recv(self, send):
        for i in range(3):
            try:
                self.socket.send_string(send)
                
                socks = dict(self.poller.poll(10_000))
                if self.socket in socks and socks[self.socket] == zmq.POLLIN:
                    return self.socket.recv_string()
                else:
                    logger.error("No answer in 10 secs.")
                    
                    self.poller.unregister(self.socket)
                    self.socket.close()

                    sleep(10)

                    self.socket = self.create_socket()
                    self.poller.register(self.socket, zmq.POLLIN)
            except zmq.error.Again as e:
                logger.error("Timeout:", e)
                
                self.poller.unregister(self.socket)
                self.socket.close()

                sleep(10)

                self.socket = self.create_socket()
                self.poller.register(self.socket, zmq.POLLIN)
        
        return ''
    
    
    def close(self):
        self.socket.close()
        self.context.term()


class Client:
    
    
    def __init__(self, sender): self.sender = sender
    
    
    def deals(self, name):
        if (_opened := self.sender.remote_recv(name)) == '':
            logger.error(f'COULD NOT GET {name}')
            return None
        
        if _opened == '[]': return []
        
        orders = []
        for o_str in _opened[1:-1].split(';'):
            order = []
            for i, o in enumerate(o_str.split(',')):
                try:
                    if i in {0, 1, 4, 6}: order.append(int(o))
                    elif i in {3, 5, 7, 8, 9}: order.append(float(o))
                    else: order.append(o)
                except ValueError:
                    logger.error('WRONG {}'.format(_opened))
                    return None
            
            orders.append(tuple(order))
        
        return orders
    
    
    get_open_orders = lambda self: self.deals("OPENED_ORDERS")
    get_pending_orders = lambda self: self.deals("OPENED_PENDING")

    
    def open_order(self, symbol, lots, price, type_, sl, tp, expire_time, comment, max_slippage):

        x = self.sender.remote_recv(f'OPEN_ORDER;{symbol};{type_};{lots};{price};{sl};{tp};{comment};{max_slippage}')
        try:
            logger.info('OPEN ticket=%d, symbol=%s, comment=%s, type=%d, sl=%.4f, tp=%f, price=%.4f, lots=%.2f', 
                        ticket:=int(x), symbol, comment, type_, sl, tp, price, lots)
            return ticket
        except ValueError:
            logger.error('NO INTEGER TICKET {}'.format(x))
    
    
    def close_order(self, ticket, lots):
        if self.sender.remote_recv("CLOSE_ORDER;{0};{1}".format(ticket, lots)) == '1':
            logger.info('CLOSE ORDER ticket=%d lots=.%2f', ticket, lots)
        else: logger.error('COULD NOT CLOSE ORDER ticket={}, lots={}'.format(ticket, lots))
    
    
    def delete_pending(self, ticket):
        if self.sender.remote_recv("DELETE_PENDING;{0}".format(ticket)) == '1':
            logger.info('DELETE PENDING %d', ticket)
        else: logger.error('COULD NOT DELETE PENDING ticket %d', ticket)
    
    
    def modify_order(self, ticket, sl, tp):
        if self.sender.remote_recv("MODIFY_SL_TP;{0};{1};{2}".format(ticket, sl, tp)) == '1':
            logger.info('MODIFY SL/TP %d %.4f %.4f', ticket, sl, tp)
        else: logger.error('COULD NOT MODIFY SL/TP ticket=%d sl=%.4f tp=%.4f', ticket, sl, tp)
    
    
    def equity(self):
        if (message:=self.sender.remote_recv("EQUITY")) == '':
            logger.error('COULD NOT GET EQUITY')
            return 0
        
        try: return float(message)
        except ValueError: logger.error('EQUITY IS NOT A NUMBER')
        return 0
    
    
    def get_prices_by_time(self, _symbol, _tf, dts):
        send = "{0};{1};{2};{3}".format('ALL0', _symbol, _tf, ','.join([dt.strftime("%Y.%m.%d %H:%M:%S") for dt in dts]))
        
        a = np.zeros( (n:=len(dts), 4), np.float32)
        
        if n != len(_spt:=self.sender.remote_recv(send).split(',')): return a
        
        for i in range(n):
            if len(_spt1:=_spt[i].split(';')) != 4: return a
            
            for j in range(4):
                try: a[i][j] = float(_spt1[j])
                except ValueError:
                    logger.error('{} IS NOT A NUMBER {} {}'.format(('CLOSE', 'LOW', 'HIGH')[j], _symbol, _tf))
                    return a
        return a
    
    
    def current_price(self, name, _symbol):
        if (message:=self.sender.remote_recv("{0};{1}".format(name, _symbol))) == '':
            logger.error('COULD NOT GET {} {}'.format(_symbol, name))
        else:
            try: return float(message)
            except ValueError: logger.error('PRICE IS NOT A NUMBER {} {}'.format(_symbol, name))
        
        return 0.
        

    bid = lambda self, _symbol: self.current_price("BID", _symbol)
    ask = lambda self, _symbol: self.current_price("ASK", _symbol)
    

    def get_spread(self, _symbol):
        if (message:=self.sender.remote_recv("{0};{1}".format("SPREAD", _symbol))) == '-1':
            logger.error('COULD NOT GET {} SPREAD'.format(_symbol))
        else:
            try: return int(message)
            except ValueError: logger.error('SPREAD IS NOT A NUMBER {}'.format(_symbol))


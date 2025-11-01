#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Feb 11 23:28:24 2022
@author: Borja Gomez
https://github.com/BorjaGomezSolorzano/Metatrader-Bridge
"""

import zmq
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock
from collections import defaultdict

from datetime import datetime
from time import sleep, monotonic

import numpy as np
import numpy.typing as npt

import logging
logger = logging.getLogger(__name__)


# Ordenes de mercado en metatrader (también hay órdenes pendientes)
BUY=0
SELL=1
BUY_LIMIT=2
SELL_LIMIT=3
BUY_STOP=4
SELL_STOP=5

# indice del elemento correspondiente en una orden, que es de tipo tupla
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

    def __init__(self, port:int=5555):
        # Only one context shared
        self.port = port
        self.context = zmq.Context.instance()


    def remote_recv(self, send: str) -> str:
        """One REQ socket by call (thread-safe)."""
        for _ in range(3):
            sock = self.context.socket(zmq.REQ)
            try:
                sock.setsockopt(zmq.LINGER, 0)           # fast close
                sock.setsockopt(zmq.RCVTIMEO, 10_000)    # 10s to receive
                sock.setsockopt(zmq.SNDTIMEO, 5_000)     # 5s to send
                sock.connect(f"tcp://127.0.0.1:{self.port}")

                sock.send_string(send)                   # REQ: send -> recv
                return sock.recv_string()
            except zmq.Again:
                logger.error("Timeout waiting response (retry).")
                sleep(1)
            finally:
                sock.close()
        return ""  # no more trials

    def close(self):
        # Close context (if not shared)
        if not self.context.closed:
            self.context.term()
    
    # --- for with context ---
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        self.close()


class Client:
    
    
    def __init__(self, sender: Socket, max_workers: int = 8, min_gap_secs: float = 10.0):
        self.sender = sender
        self._pool = ThreadPoolExecutor(max_workers=max_workers)
        self._min_gap = min_gap_secs
        # State by symbol
        self._symbol_locks = defaultdict(Lock)
        self._next_allowed = defaultdict(float)  # symbol -> next time allowed
    

    def _throttle_symbol(self, symbol: str):
        """Min gap separation between sends with same symbol"""
        lock = self._symbol_locks[symbol]
        with lock:
            now = monotonic()
            wait = self._next_allowed[symbol] - now
            if wait > 0:
                sleep(wait)
                now = monotonic()
            # Next hole
            self._next_allowed[symbol] = now + self._min_gap


    def deals(self, name: str)->list[tuple]|None:
        """
        metodo para obtener las ordenes (en mercado o pendientes)

        args:
            name (str): <OPENED_ORDERS, OPENED_PENDING>
        
        return:
            (list[tuple]): lista de ordenes. Cada orden es una lista y el indice de cada
                           uno de los elementos esta definido arriba
        """
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


    def open_order(self, symbol:str, lots:float, price:float, type_:int, sl:float, tp:float, expire_time:int, comment:str, max_slippage:int)->int|None:
        """
        open market or pending order

        args:
            symbol (str): metatrader symbol name
            lots (float): metatrader lots 
            price (float): for pending orders or 0 for market orders
            type_ (int): <BUY, SELL, BUY_LIMIT, SELL_LIMIT, BUY_STOP, SELL_STOP>
            sl (float): sl price or 0 if not
            tp (float): tp price or 0 if not
            expire_time (not implemented)
            comment (str): order comment (31 characters max)
            max_slippage (int): max slippage in pips
        
        return:
            (int) order ticket
        """
        # Throttle by symbol
        self._throttle_symbol(symbol)

        x = self.sender.remote_recv(query:=f'OPEN_ORDER;{symbol};{type_};{lots};{price};{sl};{tp};{comment};{max_slippage}')
        try:
            logger.info('OPEN ticket=%d, symbol=%s, comment=%s, type=%d, sl=%.4f, tp=%f, price=%.4f, lots=%.2f', 
                        ticket:=int(x), symbol, comment, type_, sl, tp, price, lots)
            
            if ticket <= 0: logger.error('TRADE %s NOT EXECUTED', query)

            return ticket
        except ValueError:
            logger.error('NO INTEGER TICKET {}'.format(x))

    
    def close_order(self, symbol, ticket, lots):
        """
        close order total or partially

        args:
            symbol (str)
            ticket (int): order ticket metatrader 
            lots (float): metatrader lots to close (or 0 if close all)
        """

        self._throttle_symbol(symbol)

        x = self.sender.remote_recv("CLOSE_ORDER;{0};{1}".format(ticket, lots))
        if x == '1':
            logger.info('CLOSE ORDER %s ticket=%d lots=.%2f', 'ALL' if lots == 0 else 'PARTIAL', ticket, lots)
        else: logger.error('COULD NOT CLOSE ORDER ticket={}, lots={}'.format(ticket, lots))

        return ticket
    

    def delete_pending(self, ticket:int):
        """
        delete pending orders by ticket

        args:
            ticket (int): ticket order to delete
        """
        if self.sender.remote_recv("DELETE_PENDING;{0}".format(ticket)) == '1':
            logger.info('DELETE PENDING %d', ticket)
        else: logger.error('COULD NOT DELETE PENDING ticket %d', ticket)
    

    def current_price(self, name, _symbol):
        message = self.sender.remote_recv("{0};{1}".format(name, _symbol))
        if message == '':
            logger.error('COULD NOT GET {} {}'.format(_symbol, name))
        else:
            try: 
                ans = float(message)
                logger.info('%s, %s, %.5f', name, _symbol, ans)
                return float(message)
            except ValueError: logger.error('PRICE IS NOT A NUMBER {} {}'.format(_symbol, name))
        
        return 0


    def modify_order(self, ticket:int, sl:float, tp:float):
        """
        Modifica los sl/tp de una orden. Se modifican ambos a la vez en cada llamada.

        Ejemplo: Si la orden tiene colocados ambos sl y tp, y solo se quiere modificar el tp.
        El valor de sl que habrá que poner sera el de la orden. No 0, porque si no se estara
        suprimiendo el sl.

        args:
            ticket (int): order ticket to modify
            sl (float): sl price or 0 if not
            tp (float): tp price or 0 if not
        """
        if self.sender.remote_recv("MODIFY_SL_TP;{0};{1};{2}".format(ticket, sl, tp)) == '1':
            logger.info('MODIFY SL/TP %d %.4f %.4f', ticket, sl, tp)
        else: logger.error('COULD NOT MODIFY SL/TP ticket=%d sl=%.4f tp=%.4f', ticket, sl, tp)


    def equity(self)->float:
        """
        account equity

        return:
            (float) equity or 0 if not retrieved
        """
        if (message:=self.sender.remote_recv("EQUITY")) == '':
            logger.error('COULD NOT GET EQUITY')
            return 0
        
        try: return float(message)
        except ValueError: logger.error('EQUITY IS NOT A NUMBER')
        return 0
    

    def get_prices_by_time(self, _symbol:str, _tf:str, dts:list[datetime])->npt.NDArray[np.float64]:
        """

        args:
            _symbol (str): metatrader symbol
            _tf (str): <M1, M3, M5, M6, M10, M15, M20, M30, H1, H4, D1, W1, MN1>
            dts (list[datetime]): list of datetimes to query in server timezone (la misma fecha que la barra correspondiente de metatrader)
        
        return:
            (npt.NDArray[np.float64]) array of prices: <'LOW', 'HIGH', 'CLOSE', 'OPEN'> sorted by time asc
        """

        send = "{0};{1};{2};{3}".format('ALL0', _symbol, _tf, ','.join([dt.strftime("%Y.%m.%d %H:%M:%S") for dt in dts]))
        
        a = np.zeros( (n:=len(dts), 4), np.float32)
        
        if n != len(_spt:=self.sender.remote_recv(send).split(',')): return a
        
        for i in range(n):
            if len(_spt1:=_spt[i].split(';')) != 4: return a
            
            for j in range(4):
                try: a[i][j] = float(_spt1[j])
                except ValueError:
                    logger.error('{} IS NOT A NUMBER {} {}'.format(('LOW', 'HIGH', 'CLOSE', 'OPEN')[j], _symbol, _tf))
                    return a
        return a
    
    def get_lastn_ohlc(self, _symbol:str, _tf:str, n:int)->npt.NDArray[np.float64]:
        send = "{0};{1};{2};{3}".format('LAST_NOHLC', _symbol, n, _tf)
        
        a = np.zeros( (n, 5), np.float32)
        
        recv = self.sender.remote_recv(send)
        if n != len(_spt:=recv.split(';')): return a
        
        for i in range(n):
            if len(_spt1:=_spt[i].split(',')) != 5: return a
            
            for j in range(5):
                try: a[i][j] = float(_spt1[j])
                except ValueError:
                    logger.error('{} IS NOT A NUMBER {} {}'.format(('LOW', 'HIGH', 'CLOSE', 'OPEN')[j], _symbol, _tf))
                    return a
        return a
    

    def get_spread(self, _symbol:str)->int|None:
        """
        funcion para obtener el spread bid/ask en pipos

        args:
            symbol (str): simbolo de metatrader
        
        return:
            (int): spread en pipos
        """
        if (message:=self.sender.remote_recv("{0};{1}".format("SPREAD", _symbol))) == '-1':
            logger.error('COULD NOT GET {} SPREAD'.format(_symbol))
        else:
            try: return int(message)
            except ValueError: logger.error('SPREAD IS NOT A NUMBER {}'.format(_symbol))

    
    def symbol_info(self, symbol:str)->dict[str, float]:
        """
        get mt5 symbol info

        args
            symbol (str): 

        return:
            (dict[str, float]): <size, min_lots>
        """

        str_ = self.sender.remote_recv("SYMBOL_INFO;{0}".format(symbol))
        spt = str_.split(',')
        
        if (contract_size := float(spt[0])) == 0: logger.error('NO CONTRACT SIZE %s', symbol)
        if (min_lots := float(spt[1])) == 0: logger.error('NO MIN LOTS %s', symbol)
        logger.info('%s CONTRACT SIZE: %.4f, MIN LOTS: %.4f', symbol, contract_size, min_lots)

        return {'size': contract_size, 'min_lots': min_lots}


    # --------- async versions: parallel executed returns future -----------------

    def deals_async(self, *args, **kwargs):
        return self._pool.submit(self.deals, *args, **kwargs)

    def get_spread_async(self, *args, **kwargs):
        return self._pool.submit(self.get_spread, *args, **kwargs)

    def current_price_async(self, *args, **kwargs):
        return self._pool.submit(self.current_price, *args, **kwargs)
    
    def get_prices_by_time_async(self, *args, **kwargs):
        return self._pool.submit(self.get_prices_by_time, *args, **kwargs)
    
    def open_order_async(self, *args, **kwargs):
        return self._pool.submit(self.open_order, *args, **kwargs)
    
    def close_order_async(self,  *args, **kwargs):
        return self._pool.submit(self.close_order, *args, **kwargs)
    
    def delete_pending_async(self,  *args, **kwargs):
        return self._pool.submit(self.delete_pending, *args, **kwargs)

    def modify_order_async(self,  *args, **kwargs):
        return self._pool.submit(self.modify_order, *args, **kwargs)
    
    def equity_async(self,  *args, **kwargs):
        return self._pool.submit(self.equity, *args, **kwargs)
    
    def equity_async(self,  *args, **kwargs):
        return self._pool.submit(self.equity, *args, **kwargs)
    
    def symbol_info_async(self, *args, **kwargs):
        return self._pool.submit(self.symbol_info, *args, **kwargs)

    # -------------------------------------------------------------------------------

    def close(self):
        self._pool.shutdown(wait=True)
    
    # --- for with context ---
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        self.close()



if __name__ == '__main__':

    sock = Socket()
    client = Client(sock, max_workers=8)

    # lanzar varias órdenes a la vez
    # symbol, lots, price, type_, sl, tp, expire_time, comment, max_slippage

    futures = [
        client.open_order_async("XAUUSD", 0.01, 0, 0, 0, 0, 0, "test A", 5e3),
        client.open_order_async("XAUUSD", 0.01, 0, 0, 0, 0, 0, "test A1", 5e3),
        client.open_order_async("XAUUSD", 0.01, 0, 0, 0, 0, 0, "test A2", 5e3),
        client.open_order_async("NDX",   0.01,  0, 1, 0, 0, 0, "test B", 10e3),
        client.open_order_async("NDX",   0.01,  0, 1, 0, 0, 0, "test B2", 10e3),
        client.open_order_async("NDX",   0.01,  0, 1, 0, 0, 0, "test B3", 10e3),
        client.open_order_async("EURUSD", 0.02, 0, 0, 0, 0, 0, "test C", 2e3),
    ]

    # recoger resultados
    for fut in as_completed(futures):
        ticket = fut.result()
        print("ticket:", ticket)

    client.close()

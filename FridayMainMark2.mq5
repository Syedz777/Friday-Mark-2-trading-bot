//+------------------------------------------------------------------+
//|                                                 FridayMainMark2.mq5
//+------------------------------------------------------------------+
#property copyright "ChatGPT Copilot"
#property version   "1.05"
#property strict

input double Lots            = 0.1;
input int    Slippage        = 3;
input int    MagicNumber     = 20250730;
input int    StopLoss        = 300; // Points
input int    TakeProfit      = 600; // Points

input int    MA_Period       = 20;
input int    Stoch_K         = 14;
input int    Stoch_D         = 4;
input int    Stoch_Slow      = 4;
input int    CCI_Period      = 20;

datetime lastTradeBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   lastTradeBarTime=0;
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Check for open trades                                            |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
  {
   for(int i=0; i<PositionsTotal(); i++)
     {
      ulong ticket=PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
         if(PositionGetInteger(POSITION_MAGIC)==MagicNumber &&
            PositionGetString(POSITION_SYMBOL)==_Symbol)
            return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Check cross and trend direction                                  |
//+------------------------------------------------------------------+
int CrossDirection(double prevFast, double prevSlow, double currFast, double currSlow)
  {
   if(prevFast<prevSlow && currFast>currSlow)
      return(1);
   if(prevFast>prevSlow && currFast<currSlow)
      return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Get latest bar time
   datetime barTimes[2];
   if(CopyTime(_Symbol, _Period, 0, 2, barTimes)!=2) return;
   datetime currentBarTime = barTimes[0];
   if(currentBarTime == lastTradeBarTime) return;

   if(!IsTradeAllowed()) return;

   //--- SMA and WMA
   double sma[2], wma[2];
   int sma_handle = iMA(_Symbol, _Period, MA_Period, 0, MODE_SMA, PRICE_CLOSE);
   int wma_handle = iMA(_Symbol, _Period, MA_Period, 0, MODE_LWMA, PRICE_CLOSE);
   if(sma_handle == INVALID_HANDLE || wma_handle == INVALID_HANDLE) return;
   if(CopyBuffer(sma_handle, 0, 0, 2, sma) != 2 || CopyBuffer(wma_handle, 0, 0, 2, wma) != 2)
     {
      IndicatorRelease(sma_handle);
      IndicatorRelease(wma_handle);
      return;
     }
   IndicatorRelease(sma_handle);
   IndicatorRelease(wma_handle);

   //--- Stochastic
   int stoch_handle = iStochastic(_Symbol, _Period, Stoch_K, Stoch_D, Stoch_Slow, MODE_SMA, 0);
   if(stoch_handle==INVALID_HANDLE) return;
   double stoch_main[2], stoch_signal[2];
   if(CopyBuffer(stoch_handle, 0, 0, 2, stoch_main) != 2 || CopyBuffer(stoch_handle, 1, 0, 2, stoch_signal) != 2)
     {
      IndicatorRelease(stoch_handle);
      return;
     }
   IndicatorRelease(stoch_handle);

   //--- CCI
   int cci_handle = iCCI(_Symbol, _Period, CCI_Period, PRICE_TYPICAL);
   if(cci_handle == INVALID_HANDLE) return;
   double cci[2];
   if(CopyBuffer(cci_handle, 0, 0, 2, cci) != 2)
     {
      IndicatorRelease(cci_handle);
      return;
     }
   IndicatorRelease(cci_handle);

   //--- Cross Detection
   int cross = CrossDirection(wma[1], sma[1], wma[0], sma[0]);

   //--- Stochastic trend
   bool stoch_bull = stoch_main[0] > stoch_main[1] && stoch_signal[0] > stoch_signal[1];
   bool stoch_bear = stoch_main[0] < stoch_main[1] && stoch_signal[0] < stoch_signal[1];

   //--- CCI confirmation
   bool cci_bull = cci[0] > 0;
   bool cci_bear = cci[0] < 0;

   //--- Buy Signal
   if(cross==1 && stoch_bull && cci_bull)
     {
      OpenTrade(ORDER_TYPE_BUY);
      lastTradeBarTime = currentBarTime;
     }
   //--- Sell Signal
   else if(cross==-1 && stoch_bear && cci_bear)
     {
      OpenTrade(ORDER_TYPE_SELL);
      lastTradeBarTime = currentBarTime;
     }
  }

//+------------------------------------------------------------------+
//| Open trade                                                       |
//+------------------------------------------------------------------+
void OpenTrade(const ENUM_ORDER_TYPE orderType)
  {
   double price = (orderType==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl = 0, tp = 0;
   if(orderType==ORDER_TYPE_BUY)
     {
      sl = price - StopLoss * _Point;
      tp = price + TakeProfit * _Point;
     }
   else
     {
      sl = price + StopLoss * _Point;
      tp = price - TakeProfit * _Point;
     }

   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_DEAL;
   req.magic = MagicNumber;
   req.symbol = _Symbol;
   req.volume = Lots;
   req.type = orderType;
   req.price = price;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.deviation = Slippage;
   req.type_filling = ORDER_FILLING_IOC;
   req.type_time = ORDER_TIME_GTC;

   bool tradeResult = OrderSend(req, res);
   if(!tradeResult || res.retcode != TRADE_RETCODE_DONE)
     {
      Print("OrderSend failed: ", GetLastError(), " retcode: ", res.retcode);
     }
  }
//+------------------------------------------------------------------+
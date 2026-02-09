//+------------------------------------------------------------------+
//|                                                    SuperFibo.mq5 |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Javohir Abdullayev"
#property link      "https://pycoder.uz"
#property version   "1.00"
#property description "RSI Super Fibo - Pine Script dan MQL5 ga portlangan"

// Modullarni ulash
#include "modules/Settings.mqh"
#include "modules/RSICalculator.mqh"
#include "modules/PivotDetector.mqh"
#include "modules/FibonacciLevels.mqh"
#include "modules/ChartDrawing.mqh"
#include "modules/TradeManager.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETRLAR                                                |
//+------------------------------------------------------------------+

// ═══════════════════ RSI SOZLAMALARI ═══════════════════
input group "══════════ RSI Settings ══════════"
input int               InpRSIPeriod        = 14;       // RSI Period
input double            InpRSIOverbought    = 77.62;    // RSI Overbought
input double            InpRSIOversold      = 24.62;    // RSI Oversold

// ═══════════════════ PIVOT SOZLAMALARI ═══════════════════
input group "══════════ Pivot Settings ══════════"
input int               InpPivotLeft        = 5;        // Pivot Left Bars
input int               InpPivotRight       = 5;        // Pivot Right Bars
input bool              InpShowPivots       = false;    // Show Pivot Points
input bool              InpShowSR           = false;    // Show Support/Resistance
input int               InpSRLength         = 50;       // S/R Length (bars)

// ═══════════════════ FIBONACCI SOZLAMALARI ═══════════════════
input group "══════════ Fibonacci Settings ══════════"
input int               InpFiboBars         = 15;       // Fibo Line Length (bars)
input double            InpEntry1Level      = 1.0;      // Entry 1 Fib Level

input group "Entry 2"
input bool              InpShowEntry2       = false;    // Show Entry 2
input double            InpEntry2Level      = 1.6;      // Entry 2 Level
input color             InpEntry2Color      = clrBlue;  // Entry 2 Color

input group "Entry 3"
input bool              InpShowEntry3       = false;    // Show Entry 3
input double            InpEntry3Level      = 2.6;      // Entry 3 Level
input color             InpEntry3Color      = clrBlue;  // Entry 3 Color

input group "Stop Loss"
input bool              InpShowSL           = false;    // Show Stop Loss
input double            InpSLLevel          = 1.3;      // SL Fib Level
input color             InpSLColor          = clrRed;   // SL Color

input group "Take Profit"
input bool              InpShowTP1          = true;     // Show TP1
input double            InpTP1Level         = 0.562;    // TP1 Level
input color             InpTP1Color         = clrGreen; // TP1 Color

input bool              InpShowTP2          = true;     // Show TP2
input double            InpTP2Level         = 0.0;      // TP2 Level
input color             InpTP2Color         = clrGreen; // TP2 Color

// ═══════════════════ CHIZISH SOZLAMALARI ═══════════════════
input group "══════════ Drawing Settings ══════════"
input int               InpLabelSize        = 1;        // Label Size (0=Tiny, 1=Small, 2=Normal, 3=Large, 4=Huge)

// ═══════════════════ SAVDO SOZLAMALARI ═══════════════════
input group "══════════ Trade Settings ══════════"
input bool              InpEnableTrading    = false;    // Enable Trading

input group "Trade Mode"
sinput string           InpTradeModeNote    = "0=Fibo Levels, 1=Static Points"; // Mode Info
input int               InpTradeMode        = 0;        // Trade Mode (0=Fibo, 1=Points)

input group "Position Settings"
input double            InpLotSize          = 0.01;     // Lot Size
input int               InpSlippage         = 10;       // Slippage (points)
input int               InpMagic            = 202512;   // Magic Number
input string            InpComment          = "SuperFibo"; // Order Comment

input group "Risk Management"
input bool              InpUseBreakeven     = true;     // Use Breakeven
input bool              InpUseMartingale    = false;    // Use Martingale (2x lot per entry)

input group "Static Points Mode"
sinput string           InpStaticNote       = "Only for Static Points Mode"; // Note
input int               InpSLPoints         = 100;      // Stop Loss (points)
input int               InpTP1Points        = 50;       // Take Profit 1 (points)
input int               InpTP2Points        = 150;      // Take Profit 2 (points)

//+------------------------------------------------------------------+
//| GLOBAL O'ZGARUVCHILAR                                            |
//+------------------------------------------------------------------+
CRSICalculator*         g_rsi               = NULL;
CPivotDetector*         g_pivot             = NULL;
CFibonacciLevels*       g_fibo              = NULL;
CChartDrawing*          g_chart             = NULL;
CTradeManager*          g_trade             = NULL;

datetime                g_lastBarTime       = 0;
bool                    g_initSuccess       = false;

// Martingale uchun original Fibonacci
FiboStructure           g_originalBuyFibo;
FiboStructure           g_originalSellFibo;
bool                    g_buyFiboActive     = false;
bool                    g_sellFiboActive    = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("═══════════════════════════════════════════════════");
   Print("  SuperFibo EA Initialization");
   Print("  Pine Script -> MQL5 Port");
   Print("═══════════════════════════════════════════════════");
   
   // Modullarni yaratish
   g_rsi   = new CRSICalculator();
   g_pivot = new CPivotDetector();
   g_fibo  = new CFibonacciLevels();
   g_chart = new CChartDrawing();
   g_trade = new CTradeManager();
   
   // RSI sozlamalari
   RSISettings rsiSettings;
   rsiSettings.period      = InpRSIPeriod;
   rsiSettings.overbought  = InpRSIOverbought;
   rsiSettings.oversold    = InpRSIOversold;
   
   if(!g_rsi.Init(_Symbol, _Period, rsiSettings))
   {
      Print("RSI Initialization failed!");
      return INIT_FAILED;
   }
   
   // Pivot sozlamalari
   PivotSettings pivotSettings;
   pivotSettings.leftBars   = InpPivotLeft;
   pivotSettings.rightBars  = InpPivotRight;
   pivotSettings.showPivots = InpShowPivots;
   pivotSettings.showSR     = InpShowSR;
   pivotSettings.srLength   = InpSRLength;
   
   if(!g_pivot.Init(_Symbol, _Period, pivotSettings))
   {
      Print("Pivot Initialization failed!");
      return INIT_FAILED;
   }
   
   // Fibonacci sozlamalari
   FiboSettings fiboSettings;
   fiboSettings.lineBars     = InpFiboBars;
   fiboSettings.entry1Level  = InpEntry1Level;
   fiboSettings.showEntry2   = InpShowEntry2;
   fiboSettings.entry2Level  = InpEntry2Level;
   fiboSettings.entry2Color  = InpEntry2Color;
   fiboSettings.showEntry3   = InpShowEntry3;
   fiboSettings.entry3Level  = InpEntry3Level;
   fiboSettings.entry3Color  = InpEntry3Color;
   fiboSettings.showSL       = InpShowSL;
   fiboSettings.slLevel      = InpSLLevel;
   fiboSettings.slColor      = InpSLColor;
   fiboSettings.showTP1      = InpShowTP1;
   fiboSettings.tp1Level     = InpTP1Level;
   fiboSettings.tp1Color     = InpTP1Color;
   fiboSettings.showTP2      = InpShowTP2;
   fiboSettings.tp2Level     = InpTP2Level;
   fiboSettings.tp2Color     = InpTP2Color;
   
   if(!g_fibo.Init(_Symbol, _Period, fiboSettings))
   {
      Print("Fibonacci Initialization failed!");
      return INIT_FAILED;
   }
   
   // Chizish sozlamalari
   DrawSettings drawSettings;
   drawSettings.labelSize = InpLabelSize;
   
   if(!g_chart.Init(_Symbol, ChartID(), drawSettings))
   {
      Print("Chart Drawing Initialization failed!");
      return INIT_FAILED;
   }
   
   // Savdo sozlamalari
   TradeSettings tradeSettings;
   tradeSettings.enableTrading    = InpEnableTrading;
   tradeSettings.lotSize          = InpLotSize;
   tradeSettings.slippage         = InpSlippage;
   tradeSettings.magic            = InpMagic;
   tradeSettings.comment          = InpComment;
   tradeSettings.tradeMode        = (InpTradeMode == 0) ? TRADE_MODE_FIBO_LEVELS : TRADE_MODE_STATIC_POINTS;
   tradeSettings.useBreakeven     = InpUseBreakeven;
   tradeSettings.useMartingale    = InpUseMartingale;
   tradeSettings.slPoints         = InpSLPoints;
   tradeSettings.tp1Points        = InpTP1Points;
   tradeSettings.tp2Points        = InpTP2Points;
   
   if(!g_trade.Init(_Symbol, tradeSettings))
   {
      Print("Trade Manager Initialization failed!");
      return INIT_FAILED;
   }
   
   g_initSuccess = true;
   g_lastBarTime = iTime(_Symbol, _Period, 0);
   
   Print("═══════════════════════════════════════════════════");
   Print("  SuperFibo EA Initialized Successfully!");
   Print("  Trading: ", InpEnableTrading ? "ENABLED" : "DISABLED");
   Print("═══════════════════════════════════════════════════");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("SuperFibo EA Deinitialization. Reason: ", reason);
   
   // Modullarni tozalash
   if(g_rsi != NULL)
   {
      delete g_rsi;
      g_rsi = NULL;
   }
   
   if(g_pivot != NULL)
   {
      delete g_pivot;
      g_pivot = NULL;
   }
   
   if(g_fibo != NULL)
   {
      delete g_fibo;
      g_fibo = NULL;
   }
   
   if(g_chart != NULL)
   {
      delete g_chart;
      g_chart = NULL;
   }
   
   if(g_trade != NULL)
   {
      delete g_trade;
      g_trade = NULL;
   }
   
   Print("SuperFibo EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initSuccess)
      return;
   
   // Pozitsiyalarni boshqarish (breakeven monitoring)
   if(InpEnableTrading)
   {
      g_trade.ManagePositions();
      
      // Martingale monitoring (har tick)
      if(g_buyFiboActive)
      {
         g_trade.CheckMartingaleEntry2Buy(g_originalBuyFibo);
         g_trade.CheckMartingaleEntry3Buy(g_originalBuyFibo);
      }
      
      if(g_sellFiboActive)
      {
         g_trade.CheckMartingaleEntry2Sell(g_originalSellFibo);
         g_trade.CheckMartingaleEntry3Sell(g_originalSellFibo);
      }
   }
   
   // Yangi bar tekshiruvi
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);
   
   if(isNewBar)
   {
      g_lastBarTime = currentBarTime;
      
      // Modullarni yangilash
      g_rsi.Update();
      g_pivot.Update();
      
      // Pivot nuqtalarni chizish (agar yoqilgan bo'lsa)
      if(InpShowPivots)
      {
         PivotData pivotHigh, pivotLow;
         
         if(g_pivot.GetLastPivotHigh(pivotHigh))
         {
            g_chart.DrawPivotHigh(pivotHigh.time, pivotHigh.price);
         }
         
         if(g_pivot.GetLastPivotLow(pivotLow))
         {
            g_chart.DrawPivotLow(pivotLow.time, pivotLow.price);
         }
      }
      
      // S/R chiziqlarni chizish (agar yoqilgan bo'lsa)
      if(InpShowSR)
      {
         PivotData pivotHigh, pivotLow;
         
         if(g_pivot.GetLastPivotHigh(pivotHigh))
         {
            g_chart.DrawResistanceLine(pivotHigh.time, pivotHigh.price, InpSRLength);
         }
         
         if(g_pivot.GetLastPivotLow(pivotLow))
         {
            g_chart.DrawSupportLine(pivotLow.time, pivotLow.price, InpSRLength);
         }
      }
      
      // ═══════════════════ BUY SIGNAL TEKSHIRUVI ═══════════════════
      if(g_rsi.IsOversoldEntry())
      {
         Print("══════════════════════════════════════");
         Print(" BUY SIGNAL DETECTED!");
         Print("══════════════════════════════════════");
         
         PivotData lastPivotHigh;
         if(g_pivot.GetLastPivotHigh(lastPivotHigh))
         {
            double osLow = iLow(_Symbol, _Period, 1); // Oldingi bar Low
            
            // Fibonacci hisoblash
            if(g_fibo.CalculateBuyFibo(lastPivotHigh.price, osLow))
            {
               // Fibonacci chizish
               FiboStructure buyFibo;
               if(g_fibo.GetBuyFibo(buyFibo))
               {
                  g_chart.DrawBuyFibo(buyFibo, InpFiboBars);
                  
                  // Savdo (agar yoqilgan bo'lsa)
                  if(InpEnableTrading)
                  {
                     if(g_trade.ExecuteBuySetup(buyFibo))
                     {
                        Print("✓ BUY setup bajarildi - Entry1 pozitsiyalar ochildi!");
                        
                        // Original Fibo ni saqlash (martingale uchun)
                        g_originalBuyFibo = buyFibo;
                        g_buyFiboActive = true;
                     }
                  }
               }
            }
         }
         else
         {
            Print("BUY signal: Pivot High topilmadi!");
         }
      }
      
      // ═══════════════════ SELL SIGNAL TEKSHIRUVI ═══════════════════
      if(g_rsi.IsOverboughtEntry())
      {
         Print("══════════════════════════════════════");
         Print(" SELL SIGNAL DETECTED!");
         Print("══════════════════════════════════════");
         
         PivotData lastPivotLow;
         if(g_pivot.GetLastPivotLow(lastPivotLow))
         {
            double obHigh = iHigh(_Symbol, _Period, 1); // Oldingi bar High
            
            // Fibonacci hisoblash
            if(g_fibo.CalculateSellFibo(lastPivotLow.price, obHigh))
            {
               // Fibonacci chizish
               FiboStructure sellFibo;
               if(g_fibo.GetSellFibo(sellFibo))
               {
                  g_chart.DrawSellFibo(sellFibo, InpFiboBars);
                  
                  // Savdo (agar yoqilgan bo'lsa)
                  if(InpEnableTrading)
                  {
                     if(g_trade.ExecuteSellSetup(sellFibo))
                     {
                        Print("✓ SELL setup bajarildi - Entry1 pozitsiyalar ochildi!");
                        
                        // Original Fibo ni saqlash (martingale uchun)
                        g_originalSellFibo = sellFibo;
                        g_sellFiboActive = true;
                     }
                  }
               }
            }
         }
         else
         {
            Print("SELL signal: Pivot Low topilmadi!");
         }
      }
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                    SuperFibo.mq5 |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Javohir Abdullayev"
#property link      "https://pycoder.uz"
#property version   "1.01"
#property description "RSI Super Fibo with Sweep Logic & Flexible SL"

#include "modules/Settings.mqh"
#include "modules/RSICalculator.mqh"
#include "modules/PivotDetector.mqh"
#include "modules/FibonacciLevels.mqh"
#include "modules/ChartDrawing.mqh"
#include "modules/TradeManager.mqh"
#include "modules/TelegramNotifier.mqh"

// ═══════════════════ ISH VAQTI VA KUNLARI ═══════════════════
input group "══════════ Time & Day Filter Settings ══════════"
input bool   InpUseWorkTime     = true;       // Vaqt bo'yicha cheklash (on/off)
input string InpWorkTimeStart   = "06:00";    // Ish boshlanishi
input string InpWorkTimeEnd     = "16:00";    // Ish tugashi

input bool   InpMonday          = true;       // Dushanba
input bool   InpTuesday         = true;       // Seshanba
input bool   InpWednesday       = true;       // Chorshanba
input bool   InpThursday        = true;       // Payshanba
input bool   InpFriday          = true;       // Juma
input bool   InpSaturday        = false;      // Shanba
input bool   InpSunday          = false;      // Yakshanba

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

input group "Stop Loss Settings"
input ENUM_SL_MODE      InpSLMode           = SL_MODE_STATIC_OFFSET; // SL Mode (Offset vs Fibo)
input int               InpSLOffsetPoints   = 50;       // Static Offset (Points) from Sweep
input double            InpSLLevel          = 1.3;      // Dynamic Fibo SL Level
input color             InpSLColor          = clrRed;   // SL Color on Chart

input group "Take Profit"
input bool              InpShowTP1          = true;     // Show TP1
input double            InpTP1Level         = 0.562;    // TP1 Level
input color             InpTP1Color         = clrGreen; // TP1 Color

input bool              InpShowTP2          = true;     // Show TP2
input double            InpTP2Level         = 0.0;      // TP2 Level
input color             InpTP2Color         = clrGreen; // TP2 Color

// ═══════════════════ CHIZISH SOZLAMALARI ═══════════════════
input group "══════════ Drawing Settings ══════════"
input int               InpLabelSize        = 1;        // Label Size (0..4)

// ═══════════════════ SAVDO SOZLAMALARI ═══════════════════
input group "══════════ Trade Settings ══════════"
input bool              InpEnableTrading    = false;    // Enable Trading
input double            InpLotSize          = 0.01;     // Lot Size
input int               InpSlippage         = 10;       // Slippage (points)
input int               InpMagic            = 202512;   // Magic Number
input string            InpComment          = "SuperFibo"; // Order Comment

input group "Risk Management"
input bool              InpUseBreakeven     = true;     // Use Breakeven
input bool              InpUseMartingale    = false;    // Use Martingale (2x lot per entry)

// ═══════════════════ TELEGRAM SOZLAMALARI ═══════════════════
input group "══════════ Telegram Notifications ══════════"
input bool              InpUseTelegram      = false;          // Enable Telegram
input string            InpBotToken         = "";             // Bot Token
input string            InpChatIDs          = "";             // Chat IDs (comma separated)

//+------------------------------------------------------------------+
//| GLOBAL O'ZGARUVCHILAR                                            |
//+------------------------------------------------------------------+
CRSICalculator* g_rsi               = NULL;
CPivotDetector* g_pivot             = NULL;
CFibonacciLevels* g_fibo            = NULL;
CChartDrawing* g_chart              = NULL;
CTradeManager* g_trade              = NULL;
CTelegramNotifier* g_telegram       = NULL;
datetime                g_lastBarTime       = 0;
bool                    g_initSuccess       = false;

// Martingale uchun original Fibonacci
FiboStructure           g_originalBuyFibo;
FiboStructure           g_originalSellFibo;
bool                    g_buyFiboActive     = false;
bool                    g_sellFiboActive    = false;

// SWEEP STRATEGIYASI UCHUN O'ZGARUVCHILAR
bool     g_waitForBuySweep    = false;
double   g_buySignalLow       = 0;
datetime g_buySignalTime      = 0;

bool     g_waitForSellSweep   = false;
double   g_sellSignalHigh     = 0;
datetime g_sellSignalTime     = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_rsi   = new CRSICalculator();
   g_pivot = new CPivotDetector();
   g_fibo  = new CFibonacciLevels();
   g_chart = new CChartDrawing();
   g_trade = new CTradeManager();
   g_telegram = new CTelegramNotifier();
   
   RSISettings rsiSettings;
   rsiSettings.period      = InpRSIPeriod;
   rsiSettings.overbought  = InpRSIOverbought;
   rsiSettings.oversold    = InpRSIOversold;
   if(!g_rsi.Init(_Symbol, _Period, rsiSettings)) return INIT_FAILED;
   
   PivotSettings pivotSettings;
   pivotSettings.leftBars   = InpPivotLeft;
   pivotSettings.rightBars  = InpPivotRight;
   pivotSettings.showPivots = InpShowPivots;
   pivotSettings.showSR     = InpShowSR;
   pivotSettings.srLength   = InpSRLength;
   if(!g_pivot.Init(_Symbol, _Period, pivotSettings)) return INIT_FAILED;
   
   TelegramSettings tgSettings;
   tgSettings.enable  = InpUseTelegram;
   tgSettings.token   = InpBotToken;
   tgSettings.chatIDs = InpChatIDs;
   g_telegram.Init(_Symbol, tgSettings);
   
   FiboSettings fiboSettings;
   fiboSettings.lineBars     = InpFiboBars;
   fiboSettings.entry1Level  = InpEntry1Level;
   fiboSettings.showEntry2   = InpShowEntry2;
   fiboSettings.entry2Level  = InpEntry2Level;
   fiboSettings.entry2Color  = InpEntry2Color;
   fiboSettings.showEntry3   = InpShowEntry3;
   fiboSettings.entry3Level  = InpEntry3Level;
   fiboSettings.entry3Color  = InpEntry3Color;
   fiboSettings.showSL       = true; // SL har doim hisoblanadi (vizual ko'rsatish)
   fiboSettings.slLevel      = InpSLLevel;
   fiboSettings.slColor      = InpSLColor;
   fiboSettings.showTP1      = InpShowTP1;
   fiboSettings.tp1Level     = InpTP1Level;
   fiboSettings.tp1Color     = InpTP1Color;
   fiboSettings.showTP2      = InpShowTP2;
   fiboSettings.tp2Level     = InpTP2Level;
   fiboSettings.tp2Color     = InpTP2Color;
   if(!g_fibo.Init(_Symbol, _Period, fiboSettings)) return INIT_FAILED;
   
   DrawSettings drawSettings;
   drawSettings.labelSize = InpLabelSize;
   if(!g_chart.Init(_Symbol, ChartID(), drawSettings)) return INIT_FAILED;
   
   TradeSettings tradeSettings;
   tradeSettings.enableTrading    = InpEnableTrading;
   tradeSettings.lotSize          = InpLotSize;
   tradeSettings.slippage         = InpSlippage;
   tradeSettings.magic            = InpMagic;
   tradeSettings.comment          = InpComment;
   tradeSettings.useBreakeven     = InpUseBreakeven;
   tradeSettings.useMartingale    = InpUseMartingale;
   
   // YANGI SL SOZLAMALARI
   tradeSettings.slMode           = InpSLMode;
   tradeSettings.slOffsetPoints   = InpSLOffsetPoints;

   if(!g_trade.Init(_Symbol, tradeSettings)) return INIT_FAILED;
   
   g_initSuccess = true;
   g_lastBarTime = iTime(_Symbol, _Period, 0);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_rsi != NULL) { delete g_rsi; g_rsi = NULL; }
   if(g_pivot != NULL) { delete g_pivot; g_pivot = NULL; }
   if(g_fibo != NULL) { delete g_fibo; g_fibo = NULL; }
   if(g_chart != NULL) { delete g_chart; g_chart = NULL; }
   if(g_trade != NULL) { delete g_trade; g_trade = NULL; }
   if(g_telegram != NULL) { delete g_telegram; g_telegram = NULL; }
}

void OnTick()
{
   if(!g_initSuccess) return;

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);
   if(isNewBar) g_lastBarTime = currentBarTime;
   if(g_rsi != NULL) g_rsi.Update(isNewBar);

   // 2. VAQT VA KUN FILTRLARI
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   bool dayOk = false;
   switch(dt.day_of_week)
   {
      case 1: dayOk = InpMonday;    break;
      case 2: dayOk = InpTuesday;   break;
      case 3: dayOk = InpWednesday; break;
      case 4: dayOk = InpThursday;  break;
      case 5: dayOk = InpFriday;    break;
      case 6: dayOk = InpSaturday;  break;
      case 0: dayOk = InpSunday;    break;
   }

   string curTime = StringFormat("%02d:%02d", dt.hour, dt.min);
   bool workTimeOk = true;
   if(InpUseWorkTime)
   {
      if(InpWorkTimeStart < InpWorkTimeEnd)
         workTimeOk = (curTime >= InpWorkTimeStart && curTime < InpWorkTimeEnd);
      else
         workTimeOk = (curTime >= InpWorkTimeStart || curTime < InpWorkTimeEnd);
   }

   if(!dayOk || !workTimeOk) return; 

   // 3. SAVDO VA MONITORING
   if(InpEnableTrading)
   {
      g_trade.ManagePositions();
      if(g_buyFiboActive) {
         g_trade.CheckMartingaleEntry2Buy(g_originalBuyFibo);
         g_trade.CheckMartingaleEntry3Buy(g_originalBuyFibo);
      }
      if(g_sellFiboActive) {
         g_trade.CheckMartingaleEntry2Sell(g_originalSellFibo);
         g_trade.CheckMartingaleEntry3Sell(g_originalSellFibo);
      }
   }
   
   // RSI Label
   if(g_rsi != NULL && g_chart != NULL) {
      double rsiValue = g_rsi.GetCurrentRSI();
      string rsiText = "RSI: " + DoubleToString(rsiValue, 2);
      datetime labelTime = currentBarTime + 10 * PeriodSeconds(_Period);
      double currentPrice = iClose(_Symbol, _Period, 0);
      string objName = "SuperFibo_RSI_Center";
      if(ObjectFind(ChartID(), objName) < 0)
         g_chart.CreateLabel(objName, labelTime, currentPrice, rsiText, clrNONE, clrBlack, 0);
      ObjectMove(ChartID(), objName, 0, labelTime, currentPrice);
      ObjectSetString(ChartID(), objName, OBJPROP_TEXT, rsiText);
   }

   // 4. SIGNAL QIDIRISH (KUTISH REJIMI)
   if(isNewBar)
   {
      g_pivot.Update();
      
      if(InpShowPivots) {
         PivotData ph, pl;
         if(g_pivot.GetLastPivotHigh(ph)) g_chart.DrawPivotHigh(ph.time, ph.price);
         if(g_pivot.GetLastPivotLow(pl)) g_chart.DrawPivotLow(pl.time, pl.price);
      }
      if(InpShowSR) {
         PivotData ph, pl;
         if(g_pivot.GetLastPivotHigh(ph)) g_chart.DrawResistanceLine(ph.time, ph.price, InpSRLength);
         if(g_pivot.GetLastPivotLow(pl)) g_chart.DrawSupportLine(pl.time, pl.price, InpSRLength);
      }

      // Signal aniqlash -> Sweep kutishni boshlash
      if(g_rsi.IsOversoldEntry()) {
         Print("📡 RSI BUY Signal. Waiting for SWEEP...");
         g_waitForBuySweep = true;
         g_buySignalLow    = iLow(_Symbol, _Period, 1);
         g_buySignalTime   = iTime(_Symbol, _Period, 1);
      }
      
      if(g_rsi.IsOverboughtEntry()) {
         Print("📡 RSI SELL Signal. Waiting for SWEEP...");
         g_waitForSellSweep = true;
         g_sellSignalHigh   = iHigh(_Symbol, _Period, 1);
         g_sellSignalTime   = iTime(_Symbol, _Period, 1);
      }
   }

   // 5. SWEEP TEKSHIRUVI (Har tickda)
   // --- BUY SWEEP ---
   if(g_waitForBuySweep)
   {
      int barsPassed = iBarShift(_Symbol, _Period, g_buySignalTime);
      if(barsPassed > 5) g_waitForBuySweep = false;
      else
      {
         double currentLow = iLow(_Symbol, _Period, 0);
         // Sweep bo'ldimi?
         if(currentLow < g_buySignalLow)
         {
            Print("🔥 BUY SWEEP DETECTED!");
            PivotData lastPivotHigh;
            if(g_pivot.GetLastPivotHigh(lastPivotHigh))
            {
               // Fibo hisoblash (PivotHigh -> SweepLow)
               // SweepLow sifatida joriy Low yoki aniq signal Low olinadi
               double sweepPrice = currentLow; 
               
               if(g_fibo.CalculateBuyFibo(lastPivotHigh.price, sweepPrice))
               {
                  FiboStructure buyFibo;
                  if(g_fibo.GetBuyFibo(buyFibo))
                  {
                     // --- SL HISOBLASH ---
                     double slPrice = 0;
                     if(InpSLMode == SL_MODE_STATIC_OFFSET)
                     {
                        // Sweep narxidan pastroq (offset points)
                        slPrice = sweepPrice - InpSLOffsetPoints * _Point;
                     }
                     else if(InpSLMode == SL_MODE_DYNAMIC_FIBO)
                     {
                        // Fibo darajasi (Class ichida calculate qilingan bo'ladi)
                        slPrice = buyFibo.sl.price;
                     }
                     
                     g_chart.DrawBuyFibo(buyFibo, InpFiboBars);
                     
                     if(InpEnableTrading)
                     {
                        if(g_trade.ExecuteBuySetup(buyFibo, slPrice))
                        {
                           g_originalBuyFibo = buyFibo;
                           g_buyFiboActive = true;
                           if(g_telegram != NULL) g_telegram.SendSignal(true, buyFibo.entry1.price, buyFibo);
                        }
                     }
                     else if(InpUseTelegram) 
                     {
                        if(g_telegram != NULL) g_telegram.SendSignal(true, buyFibo.entry1.price, buyFibo);
                     }
                  }
               }
            }
            g_waitForBuySweep = false;
         }
      }
   }

   // --- SELL SWEEP ---
   if(g_waitForSellSweep)
   {
      int barsPassed = iBarShift(_Symbol, _Period, g_sellSignalTime);
      if(barsPassed > 5) g_waitForSellSweep = false;
      else
      {
         double currentHigh = iHigh(_Symbol, _Period, 0);
         // Sweep bo'ldimi?
         if(currentHigh > g_sellSignalHigh)
         {
            Print("🔥 SELL SWEEP DETECTED!");
            PivotData lastPivotLow;
            if(g_pivot.GetLastPivotLow(lastPivotLow))
            {
               double sweepPrice = currentHigh;
               
               if(g_fibo.CalculateSellFibo(lastPivotLow.price, sweepPrice))
               {
                  FiboStructure sellFibo;
                  if(g_fibo.GetSellFibo(sellFibo))
                  {
                     // --- SL HISOBLASH ---
                     double slPrice = 0;
                     if(InpSLMode == SL_MODE_STATIC_OFFSET)
                     {
                        // Sweep narxidan yuqoriroq (offset points)
                        slPrice = sweepPrice + InpSLOffsetPoints * _Point;
                     }
                     else if(InpSLMode == SL_MODE_DYNAMIC_FIBO)
                     {
                        slPrice = sellFibo.sl.price;
                     }

                     g_chart.DrawSellFibo(sellFibo, InpFiboBars);
                     
                     if(InpEnableTrading)
                     {
                        if(g_trade.ExecuteSellSetup(sellFibo, slPrice))
                        {
                           g_originalSellFibo = sellFibo;
                           g_sellFiboActive = true;
                           if(g_telegram != NULL) g_telegram.SendSignal(false, sellFibo.entry1.price, sellFibo);
                        }
                     }
                     else if(InpUseTelegram) 
                     {
                        if(g_telegram != NULL) g_telegram.SendSignal(false, sellFibo.entry1.price, sellFibo);
                     }
                  }
               }
            }
            g_waitForSellSweep = false;
         }
      }
   }
}
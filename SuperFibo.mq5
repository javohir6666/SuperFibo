//+------------------------------------------------------------------+
//|                                                    SuperFibo.mq5 |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Javohir Abdullayev"
#property link      "https://pycoder.uz"
#property version   "2.10"
#property description "SuperFibo EA - Smart Notifications & Dashboard"

// --- MODULLARNI ULASH ---
#include "modules/Settings.mqh"
#include "modules/RSICalculator.mqh"
#include "modules/PivotDetector.mqh"
#include "modules/FibonacciLevels.mqh"
#include "modules/ChartDrawing.mqh"
#include "modules/TradeManager.mqh"
#include "modules/TelegramManager.mqh"
#include "modules/NewsFilter.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETRLAR                                                |
//+------------------------------------------------------------------+
input group "══════════ Trade Settings ══════════"
input bool              InpEnableTrading    = true;     // Enable Trading

input group "Trade Mode"
sinput string           InpTradeModeNote    = "0=Fibo Levels, 1=Static Points"; 
input int               InpTradeMode        = 0;        // Trade Mode (0=Fibo, 1=Points)

input group "Position Settings"
input double            InpLotSize          = 0.01;     // Lot Size
input int               InpSlippage         = 10;       // Slippage (points)
input int               InpMagic            = 202512;   // Magic Number
input string            InpComment          = "SuperFibo"; // Order Comment

input group "Risk Management"
input bool              InpUseBreakeven     = true;     // Use Breakeven
input bool              InpUseMartingale    = false;    // Use Martingale
input double            InpDailyLossPercent = 5.0;      // Daily Loss Limit (%)

input group "══════════ Time Filter ══════════"
input string            InpStartTime        = "03:00";  // Start Time (HH:MM)
input string            InpEndTime          = "21:00";  // End Time (HH:MM)

input group "══════════ News Filter ══════════"
input bool      InpNewsEnabled      = true;  // Enable News Filter
input int       InpNewsBefore       = 15;    // Stop Before News (min)
input int       InpNewsAfter        = 15;    // Start After News (min)
input bool      InpNewsHigh         = true;  // Filter High Impact
input bool      InpNewsMedium       = true; // Filter Medium Impact

input group "Static Points Mode"
input int               InpSLPoints         = 100;      // Stop Loss (points)
input int               InpTP1Points        = 50;       // Take Profit 1 (points)
input int               InpTP2Points        = 150;      // Take Profit 2 (points)

input group "══════════ Telegram Settings ══════════"
input bool              InpTeleEnabled      = true;     // Enable Telegram
input string            InpTeleToken        = "7602310057:AAGWxHexO7QlZcApmHyZxuSaX_r-uJWWHb8"; // Bot Token
input string            InpTeleChatID       = "6509449401"; // Chat ID

input group "══════════ RSI Settings ══════════"
input int               InpRSIPeriod        = 14;       // RSI Period
input double            InpRSIOverbought    = 77.62;    // RSI Overbought
input double            InpRSIOversold      = 24.62;    // RSI Oversold

input group "══════════ Pivot Settings ══════════"
input int               InpPivotLeft        = 5;        // Pivot Left Bars
input int               InpPivotRight       = 5;        // Pivot Right Bars
input bool              InpShowPivots       = true;     // Show Pivot Points
input bool              InpShowSR           = false;    // Show Support/Resistance
input int               InpSRLength         = 50;       // S/R Length (bars)

input group "══════════ Fibonacci Settings ══════════"
input int               InpFiboBars         = 15;       // Fibo Line Length
input double            InpEntry1Level      = 1.0;      // Entry 1 Level
input bool              InpShowEntry2       = false;    // Show Entry 2
input double            InpEntry2Level      = 1.6;      // Entry 2 Level
input color             InpEntry2Color      = clrBlue;  
input bool              InpShowEntry3       = false;    // Show Entry 3
input double            InpEntry3Level      = 2.6;      // Entry 3 Level
input color             InpEntry3Color      = clrBlue;
input bool              InpShowSL           = false;    // Show SL
input double            InpSLLevel          = 1.3;      // SL Level
input color             InpSLColor          = clrRed;
input bool              InpShowTP1          = true;     // Show TP1
input double            InpTP1Level         = 0.562;    // TP1 Level
input color             InpTP1Color         = clrGreen;
input bool              InpShowTP2          = true;     // Show TP2
input double            InpTP2Level         = 0.0;      // TP2 Level
input color             InpTP2Color         = clrGreen;

input group "══════════ Dashboard Settings ══════════"
input int               InpLabelSize        = 1;        // Label Size

//+------------------------------------------------------------------+
//| GLOBAL O'ZGARUVCHILAR                                            |
//+------------------------------------------------------------------+
CRSICalculator* g_rsi       = NULL;
CPivotDetector* g_pivot     = NULL;
CFibonacciLevels* g_fibo      = NULL;
CChartDrawing* g_chart     = NULL;
CTradeManager* g_trade     = NULL;
CTelegramManager* g_telegram  = NULL;
CNewsFilter* g_news      = NULL;

datetime                g_lastBarTime = 0;
bool                    g_initSuccess = false;

// Martingale va Signal holati
FiboStructure           g_originalBuyFibo;
FiboStructure           g_originalSellFibo;
bool                    g_hasActiveBuy  = false;
bool                    g_hasActiveSell = false;

// Dashboard Log Bufferi (5 qator)
string                  g_logBuffer[5];

// --- STATUS XOTIRASI (Telegram uchun) ---
string                  g_prevStatusReason = "INIT"; 
bool                    g_prevTradingAllowed = true;

//+------------------------------------------------------------------+
//| YORDAMCHI: Log tizimi                                            |
//+------------------------------------------------------------------+
void AddLog(string msg)
{
   Print(msg); // Terminalga yozish
   
   // Bufferni surish (eng eskisi o'chadi)
   for(int i = 4; i > 0; i--) g_logBuffer[i] = g_logBuffer[i-1];
   
   // Yangi log vaqti bilan
   g_logBuffer[0] = TimeToString(TimeCurrent(), TIME_MINUTES) + " " + msg;
}

string GetLogText()
{
   string text = "";
   for(int i = 0; i < 5; i++) {
      if(g_logBuffer[i] != "") text += g_logBuffer[i] + "\n";
   }
   return text;
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Modullarni yaratish
   g_rsi      = new CRSICalculator();
   g_pivot    = new CPivotDetector();
   g_fibo     = new CFibonacciLevels();
   g_chart    = new CChartDrawing();
   g_trade    = new CTradeManager();
   g_telegram = new CTelegramManager();
   g_news     = new CNewsFilter();

   // 2. Sozlamalarni yuklash
   
   // Telegram
   g_telegram.Init(InpTeleToken, InpTeleChatID, InpTeleEnabled);
   
   // RSI
   RSISettings rsiSettings;
   rsiSettings.period = InpRSIPeriod;
   rsiSettings.overbought = InpRSIOverbought; 
   rsiSettings.oversold = InpRSIOversold;
   if(!g_rsi.Init(_Symbol, _Period, rsiSettings)) return INIT_FAILED;
   
   // Pivot
   PivotSettings pivotSettings;
   pivotSettings.leftBars = InpPivotLeft; 
   pivotSettings.rightBars = InpPivotRight;
   pivotSettings.showPivots = InpShowPivots; 
   pivotSettings.showSR = InpShowSR; 
   pivotSettings.srLength = InpSRLength;
   if(!g_pivot.Init(_Symbol, _Period, pivotSettings)) return INIT_FAILED;

   // Fibo
   FiboSettings fiboSettings;
   fiboSettings.lineBars = InpFiboBars; fiboSettings.entry1Level = InpEntry1Level;
   fiboSettings.showEntry2 = InpShowEntry2; fiboSettings.entry2Level = InpEntry2Level; fiboSettings.entry2Color = InpEntry2Color;
   fiboSettings.showEntry3 = InpShowEntry3; fiboSettings.entry3Level = InpEntry3Level; fiboSettings.entry3Color = InpEntry3Color;
   fiboSettings.showSL = InpShowSL; fiboSettings.slLevel = InpSLLevel; fiboSettings.slColor = InpSLColor;
   fiboSettings.showTP1 = InpShowTP1; fiboSettings.tp1Level = InpTP1Level; fiboSettings.tp1Color = InpTP1Color;
   fiboSettings.showTP2 = InpShowTP2; fiboSettings.tp2Level = InpTP2Level; fiboSettings.tp2Color = InpTP2Color;
   if(!g_fibo.Init(_Symbol, _Period, fiboSettings)) return INIT_FAILED;

   // Drawing
   DrawSettings drawSettings; drawSettings.labelSize = InpLabelSize;
   if(!g_chart.Init(_Symbol, ChartID(), drawSettings)) return INIT_FAILED;

   // Trade & News Settings
   TradeSettings ts;
   ts.enableTrading = InpEnableTrading;
   ts.lotSize = InpLotSize;
   ts.slippage = InpSlippage;
   ts.magic = InpMagic;
   ts.comment = InpComment;
   ts.tradeMode = (ENUM_TRADE_MODE)InpTradeMode;
   ts.useBreakeven = InpUseBreakeven;
   ts.useMartingale = InpUseMartingale;
   ts.dailyLossPercent = InpDailyLossPercent;
   ts.slPoints = InpSLPoints;
   ts.tp1Points = InpTP1Points;
   ts.tp2Points = InpTP2Points;
   ts.startTime = InpStartTime;
   ts.endTime = InpEndTime;
   ts.telegram.enabled = InpTeleEnabled;
   
   ts.news.enabled = InpNewsEnabled;
   ts.news.beforeMinutes = InpNewsBefore;
   ts.news.afterMinutes = InpNewsAfter;
   ts.news.includeHigh = InpNewsHigh;
   ts.news.includeMedium = InpNewsMedium;
   ts.news.includeLow = false;
   
   g_news.Init(_Symbol, ts.news);
   if(!g_trade.Init(_Symbol, ts)) return INIT_FAILED;
   
   g_initSuccess = true;
   g_lastBarTime = iTime(_Symbol, _Period, 0);
   
   AddLog("Robot ishga tushdi!");
   g_telegram.SendMessage("🚀 SuperFibo EA v2.1 ishga tushdi!\nSymbol: " + _Symbol);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_telegram != NULL) g_telegram.SendMessage("⚠️ SuperFibo to'xtatildi. Reason: " + IntegerToString(reason));
   Print("SuperFibo Deinit.");

   if(g_rsi != NULL) { delete g_rsi; g_rsi = NULL; }
   if(g_pivot != NULL) { delete g_pivot; g_pivot = NULL; }
   if(g_fibo != NULL) { delete g_fibo; g_fibo = NULL; }
   if(g_chart != NULL) { delete g_chart; g_chart = NULL; }
   if(g_telegram != NULL) { delete g_telegram; g_telegram = NULL; }
   if(g_trade != NULL) { delete g_trade; g_trade = NULL; }
   if(g_news != NULL) { delete g_news; g_news = NULL; }
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initSuccess) return;

   // 1. STATUS TEKSHIRUVI VA DASHBOARD MA'LUMOTLARI
   DashboardState state;
   
   bool dailyLoss = g_trade.IsDailyStopActive();
   bool isTradingTime = g_trade.IsTradingTime();
   bool isNewsTime = g_news.IsNewsTime();
   
   state.isTradingAllowed = true;
   state.statusReason = "";
   
   // Statusni aniqlash
   if(dailyLoss) { 
      state.isTradingAllowed = false; state.statusReason = "STOP: Daily Loss Limit"; 
   } else if(isNewsTime) { 
      state.isTradingAllowed = false; state.statusReason = "STOP: News Event"; 
   } else if(!isTradingTime) { 
      state.isTradingAllowed = false; state.statusReason = "STOP: Time Filter"; 
   } else if(!InpEnableTrading) { 
      state.isTradingAllowed = false; state.statusReason = "STOP: User Disabled"; 
   }
   
   // --- TELEGRAM NOTIFICATION LOGIC (Holat o'zgarganda) ---
   // Faqat holat o'zgarganda (masalan: Allowed -> News ga o'tganda)
   if(state.statusReason != g_prevStatusReason || state.isTradingAllowed != g_prevTradingAllowed)
   {
      // Init paytda xabar yubormaslik uchun tekshiruv
      if(g_prevStatusReason != "INIT")
      {
         string msg = "";
         string symbolTxt = "\nSymbol: " + _Symbol;
         
         // 1. Savdo to'xtatildi
         if(!state.isTradingAllowed && g_prevTradingAllowed) 
         {
            if(state.statusReason == "STOP: News Event") 
               msg = "🔴 News Event Started!\nTrading Paused." + symbolTxt;
            else if(state.statusReason == "STOP: Daily Loss Limit")
               msg = "⛔ DAILY LOSS LIMIT REACHED!\nTrading Stopped for Today." + symbolTxt + "\nProfit: " + DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT), 2);
            else if(state.statusReason == "STOP: Time Filter")
               msg = "🕒 Trading Time Ended.\nSession Closed." + symbolTxt;
            else
               msg = "⚠️ Trading Stopped.\nReason: " + state.statusReason + symbolTxt;
         }
         // 2. Savdo qayta tiklandi
         else if(state.isTradingAllowed && !g_prevTradingAllowed)
         {
            msg = "🟢 Trading Resumed!\nConditions are normal." + symbolTxt;
         }
         
         if(msg != "") {
            g_telegram.SendMessage(msg);
            AddLog("Status Change: " + state.statusReason);
         }
      }
      
      // Holatni yangilash
      g_prevStatusReason = state.statusReason;
      g_prevTradingAllowed = state.isTradingAllowed;
   }
   // -----------------------------------------------------
   
   // Signal statusi
   if(g_hasActiveBuy) {
      state.hasActiveSignal = true; state.signalType = "BUY";
      state.currentEntry = g_trade.GetCurrentEntry(true);
   } else if(g_hasActiveSell) {
      state.hasActiveSignal = true; state.signalType = "SELL";
      state.currentEntry = g_trade.GetCurrentEntry(false);
   } else {
      state.hasActiveSignal = false;
      state.signalType = "-";
      state.currentEntry = 0;
   }
   
   state.lastAction = g_trade.GetLastAction();
   state.newsText = g_news.GetUpcomingNewsList();
   state.logText = GetLogText();
   
   // 2. DASHBOARDNI CHIZISH
   g_chart.DrawDashboard(state);
   
   // 3. SAVDO BOSHQARUVI
   g_trade.ManagePositions();
   
   // Martingale tekshiruvi
   if(state.isTradingAllowed)
   {
      if(g_hasActiveBuy) {
         g_trade.CheckMartingaleEntry2Buy(g_originalBuyFibo);
         g_trade.CheckMartingaleEntry3Buy(g_originalBuyFibo);
      }
      if(g_hasActiveSell) {
         g_trade.CheckMartingaleEntry2Sell(g_originalSellFibo);
         g_trade.CheckMartingaleEntry3Sell(g_originalSellFibo);
      }
   }

   // 4. YANGI SIGNAL QIDIRISH (Har yangi barda)
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      g_rsi.Update();
      g_pivot.Update();

      // BUY SIGNAL
      if(g_rsi.IsOversoldEntry())
      {
         PivotData lastPivotHigh;
         if(g_pivot.GetLastPivotHigh(lastPivotHigh))
         {
            double osLow = iLow(_Symbol, _Period, 1);
            if(g_fibo.CalculateBuyFibo(lastPivotHigh.price, osLow))
            {
               FiboStructure buyFibo;
               if(g_fibo.GetBuyFibo(buyFibo))
               {
                  g_chart.DrawBuyFibo(buyFibo, InpFiboBars);
                  
                  if(!state.isTradingAllowed) {
                     AddLog("BUY signal (Ignored: " + state.statusReason + ")");
                  } else {
                     AddLog("BUY Signal Topildi! Entry: " + DoubleToString(buyFibo.entry1.price, _Digits));
                     g_telegram.SendMessage("🚀 BUY Signal\nPrice: " + DoubleToString(buyFibo.entry1.price, _Digits));
                     
                     if(g_trade.ExecuteBuySetup(buyFibo)) {
                        g_originalBuyFibo = buyFibo;
                        g_hasActiveBuy = true;
                        g_hasActiveSell = false; 
                     }
                  }
               }
            }
         }
      }

      // SELL SIGNAL
      if(g_rsi.IsOverboughtEntry())
      {
         PivotData lastPivotLow;
         if(g_pivot.GetLastPivotLow(lastPivotLow))
         {
            double obHigh = iHigh(_Symbol, _Period, 1);
            if(g_fibo.CalculateSellFibo(lastPivotLow.price, obHigh))
            {
               FiboStructure sellFibo;
               if(g_fibo.GetSellFibo(sellFibo))
               {
                  g_chart.DrawSellFibo(sellFibo, InpFiboBars);
                  
                  if(!state.isTradingAllowed) {
                     AddLog("SELL signal (Ignored: " + state.statusReason + ")");
                  } else {
                     AddLog("SELL Signal Topildi! Entry: " + DoubleToString(sellFibo.entry1.price, _Digits));
                     g_telegram.SendMessage("📉 SELL Signal\nPrice: " + DoubleToString(sellFibo.entry1.price, _Digits));
                     
                     if(g_trade.ExecuteSellSetup(sellFibo)) {
                        g_originalSellFibo = sellFibo;
                        g_hasActiveSell = true;
                        g_hasActiveBuy = false;
                     }
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+

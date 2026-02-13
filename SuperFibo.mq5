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
#include "modules/TelegramManager.mqh"
#include "modules/NewsFilter.mqh"
//+------------------------------------------------------------------+
//| INPUT PARAMETRLAR                                                |
//+------------------------------------------------------------------+

// ═══════════════════ SAVDO SOZLAMALARI ═══════════════════
input group "══════════ Trade Settings ══════════"
input bool              InpEnableTrading    = true;    // Enable Trading

input group "Trade Mode"
sinput string           InpTradeModeNote    = "0=Fibo Levels, 1=Static Points"; // Mode Info
input int               InpTradeMode        = 0;        // Trade Mode (0=Fibo, 1=Points)

input group "Position Settings"
input double            InpLotSize          = 0.01;     // Lot Size
input int               InpSlippage         = 10;       // Slippage (points)
input int               InpMagic            = 202512;   // Magic Number
input string            InpComment          = "SuperFibo123"; // Order Comment

input group "Risk Management"
input bool              InpUseBreakeven     = true;     // Use Breakeven
input bool              InpUseMartingale    = false;    // Use Martingale (2x lot per entry)

input group "══════════ Time Filter ══════════"
input string            InpStartTime        = "03:00";    // Savdo boshlanishi (HH:MM)
input string            InpEndTime          = "21:00";    // Savdo tugashi (HH:MM)

input group "══════════ News Filter ══════════"
input bool      InpNewsEnabled      = true;  // Enable News Filter
input int       InpNewsBefore       = 15;    // Stop Before News (min)
input int       InpNewsAfter        = 15;    // Start After News (min)
input bool      InpNewsHigh         = true;  // Filter High Impact
input bool      InpNewsMedium       = false; // Filter Medium Impact

input group "Static Points Mode"
sinput string           InpStaticNote       = "Only for Static Points Mode"; // Note
input int               InpSLPoints         = 100;      // Stop Loss (points)
input int               InpTP1Points        = 50;       // Take Profit 1 (points)
input int               InpTP2Points        = 150;      // Take Profit 2 (points)

input group "══════════ Telegram Settings ══════════"
input bool              InpTeleEnabled      = true;      // Enable Telegram
input string            InpTeleToken        = "7602310057:AAGWxHexO7QlZcApmHyZxuSaX_r-uJWWHb8"; // Bot Token
input string            InpTeleChatID       = "6509449401"; // Chat ID

// ═══════════════════ RSI SOZLAMALARI ═══════════════════
input group "══════════ RSI Settings ══════════"
input int               InpRSIPeriod        = 14;       // RSI Period
input double            InpRSIOverbought    = 77.62;    // RSI Overbought
input double            InpRSIOversold      = 24.62;    // RSI Oversold

// ═══════════════════ PIVOT SOZLAMALARI ═══════════════════
input group "══════════ Pivot Settings ══════════"
input int               InpPivotLeft        = 5;        // Pivot Left Bars
input int               InpPivotRight       = 5;        // Pivot Right Bars
input bool              InpShowPivots       = true;    // Show Pivot Points
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
//+------------------------------------------------------------------+
//| GLOBAL O'ZGARUVCHILAR                                            |
//+------------------------------------------------------------------+
CRSICalculator*         g_rsi               = NULL;
CPivotDetector*         g_pivot             = NULL;
CFibonacciLevels*       g_fibo              = NULL;
CChartDrawing*          g_chart             = NULL;
CTradeManager*          g_trade             = NULL;
CTelegramManager* g_telegram          = NULL;
CNewsFilter* g_news              = NULL;

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
   Print("═══════════════════════════════════════════════════");
   
   // Modullarni yaratish
   g_rsi      = new CRSICalculator();
   g_pivot    = new CPivotDetector();
   g_fibo     = new CFibonacciLevels();
   g_chart    = new CChartDrawing();
   g_trade    = new CTradeManager();
   g_telegram = new CTelegramManager();
   g_news     = new CNewsFilter(); // Yangi modul

   // Telegram Init
   g_telegram.Init(InpTeleToken, InpTeleChatID, InpTeleEnabled);
   
   // RSI Init
   RSISettings rsiSettings;
   rsiSettings.period = InpRSIPeriod;
   rsiSettings.overbought = InpRSIOverbought; rsiSettings.oversold = InpRSIOversold;
   if(!g_rsi.Init(_Symbol, _Period, rsiSettings)) return INIT_FAILED;
   
   // Pivot Init
   PivotSettings pivotSettings;
   pivotSettings.leftBars = InpPivotLeft; pivotSettings.rightBars = InpPivotRight;
   pivotSettings.showPivots = InpShowPivots; pivotSettings.showSR = InpShowSR; pivotSettings.srLength = InpSRLength;
   if(!g_pivot.Init(_Symbol, _Period, pivotSettings)) return INIT_FAILED;

   // Fibo Init
   FiboSettings fiboSettings;
   fiboSettings.lineBars = InpFiboBars; fiboSettings.entry1Level = InpEntry1Level;
   fiboSettings.showEntry2 = InpShowEntry2; fiboSettings.entry2Level = InpEntry2Level;
   fiboSettings.entry2Color = InpEntry2Color;
   fiboSettings.showEntry3 = InpShowEntry3; fiboSettings.entry3Level = InpEntry3Level; fiboSettings.entry3Color = InpEntry3Color;
   fiboSettings.showSL = InpShowSL; fiboSettings.slLevel = InpSLLevel;
   fiboSettings.slColor = InpSLColor;
   fiboSettings.showTP1 = InpShowTP1; fiboSettings.tp1Level = InpTP1Level; fiboSettings.tp1Color = InpTP1Color;
   fiboSettings.showTP2 = InpShowTP2; fiboSettings.tp2Level = InpTP2Level;
   fiboSettings.tp2Color = InpTP2Color;
   if(!g_fibo.Init(_Symbol, _Period, fiboSettings)) return INIT_FAILED;

   // Drawing Init
   DrawSettings drawSettings; drawSettings.labelSize = InpLabelSize;
   if(!g_chart.Init(_Symbol, ChartID(), drawSettings)) return INIT_FAILED;

   // Trade Manager Init
   TradeSettings tradeSettings;
   tradeSettings.enableTrading = InpEnableTrading;
   tradeSettings.lotSize = InpLotSize;
   tradeSettings.slippage = InpSlippage;
   tradeSettings.magic = InpMagic;
   tradeSettings.comment = InpComment;
   
   // --- TUZATILGAN QISM ---
   // Input int ni ENUM_TRADE_MODE ga majburiy o'tkazish (casting)
   tradeSettings.tradeMode = (ENUM_TRADE_MODE)InpTradeMode; 
   // -----------------------
   
   tradeSettings.useBreakeven = InpUseBreakeven;
   tradeSettings.useMartingale = InpUseMartingale;
   tradeSettings.slPoints = InpSLPoints;
   tradeSettings.tp1Points = InpTP1Points;
   tradeSettings.tp2Points = InpTP2Points;
   tradeSettings.startTime = InpStartTime;
   tradeSettings.endTime = InpEndTime;
   tradeSettings.telegram.enabled = InpTeleEnabled;
   tradeSettings.telegram.token = InpTeleToken;
   tradeSettings.telegram.chatID = InpTeleChatID;
   
   // News Settings to'ldirish (Agar struct Settings.mqh da bo'lsa)
   tradeSettings.news.enabled = InpNewsEnabled;
   tradeSettings.news.beforeMinutes = InpNewsBefore;
   tradeSettings.news.afterMinutes = InpNewsAfter;
   tradeSettings.news.includeHigh = InpNewsHigh;
   tradeSettings.news.includeMedium = InpNewsMedium;
   tradeSettings.news.includeLow = false;
   
   // News Filter Init
   g_news.Init(_Symbol, tradeSettings.news);

   if(!g_trade.Init(_Symbol, tradeSettings)) return INIT_FAILED;
   
   g_initSuccess = true;
   g_lastBarTime = iTime(_Symbol, _Period, 0);
   
   // Start Message
   string startMsg = "🚀 SuperFibo EA ishga tushdi!\nSymbol: " + _Symbol;
   g_telegram.SendMessage(startMsg);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // ROBOT O'CHIRILGANI HAQIDA HABAR
   string stopMsg = "⚠️ SuperFibo EA to'xtatildi!\n" + 
                    "Symbol: " + _Symbol + "\n" + 
                    "Sabab kodi: " + IntegerToString(reason);
   
   if(g_telegram != NULL) 
   {
      g_telegram.SendMessage(stopMsg);
   }

   Print("SuperFibo EA Deinitialization. Reason: ", reason);

   // Modullarni tozalash (obyektlarni o'chirish)
   if(g_rsi != NULL) { delete g_rsi; g_rsi = NULL; }
   if(g_pivot != NULL) { delete g_pivot; g_pivot = NULL; }
   if(g_fibo != NULL) { delete g_fibo; g_fibo = NULL; }
   if(g_chart != NULL) { delete g_chart; g_chart = NULL; }
   
   if(g_telegram != NULL) 
   {
      delete g_telegram;
      g_telegram = NULL;
   }
   
   if(g_trade != NULL) { delete g_trade; g_trade = NULL; }
   if(g_news != NULL) { delete g_news; g_news = NULL; }
   Print("SuperFibo EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initSuccess) return;
   
   // 1. Yangiliklar vaqtini tekshirish
   // CNewsFilter klassi ichida keshlash bor, shuning uchun har tickda chaqirish xavfsiz
   bool isNewsTime = g_news.IsNewsTime();
   
   // 2. Har tickda pozitsiyalarni boshqarish (Breakeven va Martingale)
   if(InpEnableTrading)
   {
      g_trade.ManagePositions();
      
      // Martingale (Averaging) monitoring
      // Eslatma: Agar siz yangilik vaqtida Martingale (usredneniye) ham qilmasligini xohlasangiz,
      // bu shartlarga "&& !isNewsTime" qo'shishingiz mumkin. 
      // Lekin odatda ochiq pozitsiyalarni qutqarish uchun bu qism ishlayvergani ma'qul.
      if(g_buyFiboActive) {
         g_trade.CheckMartingaleEntry2Buy(g_originalBuyFibo);
         g_trade.CheckMartingaleEntry3Buy(g_originalBuyFibo);
      }
      if(g_sellFiboActive) {
         g_trade.CheckMartingaleEntry2Sell(g_originalSellFibo);
         g_trade.CheckMartingaleEntry3Sell(g_originalSellFibo);
      }
   }
   
   // 3. Yangi bar ochilishini tekshirish (Yangi signallar uchun)
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      g_rsi.Update();
      g_pivot.Update();
      
      // ════════════════════ BUY SIGNAL ════════════════════
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
                  // 1. Grafikda chizish (Har doim chizamiz, vizual nazorat uchun)
                  g_chart.DrawBuyFibo(buyFibo, InpFiboBars);
                  
                  // 2. Yangilik vaqtini tekshirish
                  if(isNewsTime)
                  {
                     // Agar yangilik vaqti bo'lsa - Savdo QILMAYMIZ
                     Print("⛔ NEWS FILTER: BUY Signal bekor qilindi (Yangilik vaqti)");
                  }
                  else
                  {
                     // Yangilik yo'q bo'lsa - Normal rejim
                     
                     // Telegram Signal
                     string msg = "🚀 SuperFibo BUY Signal\nSymbol: " + _Symbol + "\nEntry: " + DoubleToString(buyFibo.entry1.price, _Digits);
                     g_telegram.SendMessage(msg);

                     // Savdoga kirish
                     if(InpEnableTrading) {
                        if(g_trade.ExecuteBuySetup(buyFibo)) {
                           g_originalBuyFibo = buyFibo; 
                           g_buyFiboActive = true;
                        }
                     }
                  }
               }
            }
         }
      }
      
      // ════════════════════ SELL SIGNAL ════════════════════
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
                  // 1. Grafikda chizish
                  g_chart.DrawSellFibo(sellFibo, InpFiboBars);
                  
                  // 2. Yangilik vaqtini tekshirish
                  if(isNewsTime)
                  {
                     // Agar yangilik vaqti bo'lsa - Savdo QILMAYMIZ
                     Print("⛔ NEWS FILTER: SELL Signal bekor qilindi (Yangilik vaqti)");
                  }
                  else
                  {
                     // Yangilik yo'q bo'lsa - Normal rejim

                     // Telegram Signal
                     string msg = "📉 SuperFibo SELL Signal\nSymbol: " + _Symbol + "\nEntry: " + DoubleToString(sellFibo.entry1.price, _Digits);
                     g_telegram.SendMessage(msg);

                     // Savdoga kirish
                     if(InpEnableTrading) {
                        if(g_trade.ExecuteSellSetup(sellFibo)) {
                           g_originalSellFibo = sellFibo; 
                           g_sellFiboActive = true;
                        }
                     }
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+

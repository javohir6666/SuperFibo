//+------------------------------------------------------------------+
//|                                            FibonacciLevels.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+

#include "Settings.mqh"

//+------------------------------------------------------------------+
//| Fibonacci Levels Calculator klassi                              |
//+------------------------------------------------------------------+
class CFibonacciLevels
{
private:
   FiboSettings      m_settings;         // Sozlamalar
   string            m_symbol;           // Symbol
   ENUM_TIMEFRAMES   m_timeframe;        // Timeframe
   
   FiboStructure     m_buyFibo;          // BUY Fibonacci
   FiboStructure     m_sellFibo;         // SELL Fibonacci
   
public:
   // Konstruktor
   CFibonacciLevels(void);
   ~CFibonacciLevels(void);
   
   // Initsializatsiya
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe, FiboSettings &settings);
   void Deinit(void);
   
   // Fibonacci hisoblash
   bool CalculateBuyFibo(double pivotHigh, double osLow);
   bool CalculateSellFibo(double pivotLow, double obHigh);
   
   // Ma'lumotlarni olish
   bool GetBuyFibo(FiboStructure &fibo);
   bool GetSellFibo(FiboStructure &fibo);
   
   // Faol Fibo borligini tekshirish
   bool HasActiveBuyFibo(void) { return m_buyFibo.isActive; }
   bool HasActiveSellFibo(void) { return m_sellFibo.isActive; }
   
   // Fibo ni o'chirish
   void ClearBuyFibo(void);
   void ClearSellFibo(void);
   
private:
   // Yordamchi funksiyalar
   void CalculateFiboLevel(double level0, double level1, double fibLevel, FiboLevel &result);
};

//+------------------------------------------------------------------+
//| Konstruktor                                                      |
//+------------------------------------------------------------------+
CFibonacciLevels::CFibonacciLevels(void)
{
   m_buyFibo.isActive = false;
   m_sellFibo.isActive = false;
}

//+------------------------------------------------------------------+
//| Destruktor                                                       |
//+------------------------------------------------------------------+
CFibonacciLevels::~CFibonacciLevels(void)
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initsializatsiya                                                 |
//+------------------------------------------------------------------+
bool CFibonacciLevels::Init(string symbol, ENUM_TIMEFRAMES timeframe, FiboSettings &settings)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_settings = settings;
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitsializatsiya                                               |
//+------------------------------------------------------------------+
void CFibonacciLevels::Deinit(void)
{
   ClearBuyFibo();
   ClearSellFibo();
}

//+------------------------------------------------------------------+
//| BUY Fibonacci hisoblash                                          |
//| Pine: 0 = Pivot High, 1 = OS Low                                |
//| Entry price = pivotH - range * fibLevel                         |
//+------------------------------------------------------------------+
bool CFibonacciLevels::CalculateBuyFibo(double pivotHigh, double osLow)
{
   // Diapazon
   double range = pivotHigh - osLow;
   
   if(range <= 0)
   {
      Print("BUY Fibo: Noto'g'ri diapazon - ", range);
      return false;
   }
   
   // Asosiy ma'lumotlar
   m_buyFibo.isActive = true;
   m_buyFibo.signalTime = TimeCurrent();
   m_buyFibo.signalBar = 0;
   m_buyFibo.level0 = pivotHigh;
   m_buyFibo.level1 = osLow;
   
   // Entry 1 (har doim ko'rsatiladi)
   m_buyFibo.entry1.price = pivotHigh - range * m_settings.entry1Level;
   m_buyFibo.entry1.name = "Buy 1";
   m_buyFibo.entry1.lineColor = clrBlue;
   m_buyFibo.entry1.show = true;
   
   // Entry 2
   if(m_settings.showEntry2)
   {
      m_buyFibo.entry2.price = pivotHigh - range * m_settings.entry2Level;
      m_buyFibo.entry2.name = "Entry 2";
      m_buyFibo.entry2.lineColor = m_settings.entry2Color;
      m_buyFibo.entry2.show = true;
   }
   else
   {
      m_buyFibo.entry2.show = false;
   }
   
   // Entry 3
   if(m_settings.showEntry3)
   {
      m_buyFibo.entry3.price = pivotHigh - range * m_settings.entry3Level;
      m_buyFibo.entry3.name = "Entry 3";
      m_buyFibo.entry3.lineColor = m_settings.entry3Color;
      m_buyFibo.entry3.show = true;
   }
   else
   {
      m_buyFibo.entry3.show = false;
   }
   
   // Stop Loss
   if(m_settings.showSL)
   {
      m_buyFibo.sl.price = pivotHigh - range * m_settings.slLevel;
      m_buyFibo.sl.name = "SL";
      m_buyFibo.sl.lineColor = m_settings.slColor;
      m_buyFibo.sl.show = true;
   }
   else
   {
      m_buyFibo.sl.show = false;
   }
   
   // TP1
   if(m_settings.showTP1)
   {
      m_buyFibo.tp1.price = pivotHigh - range * m_settings.tp1Level;
      m_buyFibo.tp1.name = "TP1";
      m_buyFibo.tp1.lineColor = m_settings.tp1Color;
      m_buyFibo.tp1.show = true;
   }
   else
   {
      m_buyFibo.tp1.show = false;
   }
   
   // TP2
   if(m_settings.showTP2)
   {
      m_buyFibo.tp2.price = pivotHigh - range * m_settings.tp2Level;
      m_buyFibo.tp2.name = "TP2";
      m_buyFibo.tp2.lineColor = m_settings.tp2Color;
      m_buyFibo.tp2.show = true;
   }
   else
   {
      m_buyFibo.tp2.show = false;
   }
   
   Print("BUY Fibonacci hisoblandi:");
   Print("  Pivot High: ", pivotHigh);
   Print("  OS Low: ", osLow);
   Print("  Range: ", range);
   Print("  Entry 1: ", m_buyFibo.entry1.price);
   if(m_buyFibo.entry2.show) Print("  Entry 2: ", m_buyFibo.entry2.price);
   if(m_buyFibo.entry3.show) Print("  Entry 3: ", m_buyFibo.entry3.price);
   if(m_buyFibo.tp1.show) Print("  TP1: ", m_buyFibo.tp1.price);
   if(m_buyFibo.tp2.show) Print("  TP2: ", m_buyFibo.tp2.price);
   
   return true;
}

//+------------------------------------------------------------------+
//| SELL Fibonacci hisoblash                                         |
//| Pine: 0 = Pivot Low, 1 = OB High                                |
//| Entry price = pivotL + range * fibLevel                         |
//+------------------------------------------------------------------+
bool CFibonacciLevels::CalculateSellFibo(double pivotLow, double obHigh)
{
   // Diapazon
   double range = obHigh - pivotLow;
   
   if(range <= 0)
   {
      Print("SELL Fibo: Noto'g'ri diapazon - ", range);
      return false;
   }
   
   // Asosiy ma'lumotlar
   m_sellFibo.isActive = true;
   m_sellFibo.signalTime = TimeCurrent();
   m_sellFibo.signalBar = 0;
   m_sellFibo.level0 = pivotLow;
   m_sellFibo.level1 = obHigh;
   
   // Entry 1 (har doim ko'rsatiladi)
   m_sellFibo.entry1.price = pivotLow + range * m_settings.entry1Level;
   m_sellFibo.entry1.name = "Sell 1";
   m_sellFibo.entry1.lineColor = clrMaroon;
   m_sellFibo.entry1.show = true;
   
   // Entry 2
   if(m_settings.showEntry2)
   {
      m_sellFibo.entry2.price = pivotLow + range * m_settings.entry2Level;
      m_sellFibo.entry2.name = "Entry 2";
      m_sellFibo.entry2.lineColor = m_settings.entry2Color;
      m_sellFibo.entry2.show = true;
   }
   else
   {
      m_sellFibo.entry2.show = false;
   }
   
   // Entry 3
   if(m_settings.showEntry3)
   {
      m_sellFibo.entry3.price = pivotLow + range * m_settings.entry3Level;
      m_sellFibo.entry3.name = "Entry 3";
      m_sellFibo.entry3.lineColor = m_settings.entry3Color;
      m_sellFibo.entry3.show = true;
   }
   else
   {
      m_sellFibo.entry3.show = false;
   }
   
   // Stop Loss
   if(m_settings.showSL)
   {
      m_sellFibo.sl.price = pivotLow + range * m_settings.slLevel;
      m_sellFibo.sl.name = "SL";
      m_sellFibo.sl.lineColor = m_settings.slColor;
      m_sellFibo.sl.show = true;
   }
   else
   {
      m_sellFibo.sl.show = false;
   }
   
   // TP1
   if(m_settings.showTP1)
   {
      m_sellFibo.tp1.price = pivotLow + range * m_settings.tp1Level;
      m_sellFibo.tp1.name = "TP1";
      m_sellFibo.tp1.lineColor = m_settings.tp1Color;
      m_sellFibo.tp1.show = true;
   }
   else
   {
      m_sellFibo.tp1.show = false;
   }
   
   // TP2
   if(m_settings.showTP2)
   {
      m_sellFibo.tp2.price = pivotLow + range * m_settings.tp2Level;
      m_sellFibo.tp2.name = "TP2";
      m_sellFibo.tp2.lineColor = m_settings.tp2Color;
      m_sellFibo.tp2.show = true;
   }
   else
   {
      m_sellFibo.tp2.show = false;
   }
   
   Print("SELL Fibonacci hisoblandi:");
   Print("  Pivot Low: ", pivotLow);
   Print("  OB High: ", obHigh);
   Print("  Range: ", range);
   Print("  Entry 1: ", m_sellFibo.entry1.price);
   if(m_sellFibo.entry2.show) Print("  Entry 2: ", m_sellFibo.entry2.price);
   if(m_sellFibo.entry3.show) Print("  Entry 3: ", m_sellFibo.entry3.price);
   if(m_sellFibo.tp1.show) Print("  TP1: ", m_sellFibo.tp1.price);
   if(m_sellFibo.tp2.show) Print("  TP2: ", m_sellFibo.tp2.price);
   
   return true;
}

//+------------------------------------------------------------------+
//| BUY Fibo ma'lumotlarini olish                                    |
//+------------------------------------------------------------------+
bool CFibonacciLevels::GetBuyFibo(FiboStructure &fibo)
{
   if(!m_buyFibo.isActive)
      return false;
   
   fibo = m_buyFibo;
   return true;
}

//+------------------------------------------------------------------+
//| SELL Fibo ma'lumotlarini olish                                   |
//+------------------------------------------------------------------+
bool CFibonacciLevels::GetSellFibo(FiboStructure &fibo)
{
   if(!m_sellFibo.isActive)
      return false;
   
   fibo = m_sellFibo;
   return true;
}

//+------------------------------------------------------------------+
//| BUY Fibo ni o'chirish                                            |
//+------------------------------------------------------------------+
void CFibonacciLevels::ClearBuyFibo(void)
{
   m_buyFibo.isActive = false;
}

//+------------------------------------------------------------------+
//| SELL Fibo ni o'chirish                                           |
//+------------------------------------------------------------------+
void CFibonacciLevels::ClearSellFibo(void)
{
   m_sellFibo.isActive = false;
}

//+------------------------------------------------------------------+

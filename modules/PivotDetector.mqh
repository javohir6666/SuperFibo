//+------------------------------------------------------------------+
//|                                               PivotDetector.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+

#include "Settings.mqh"

//+------------------------------------------------------------------+
//| Pivot Detector klassi - STATE MANAGEMENT BILAN                  |
//+------------------------------------------------------------------+
class CPivotDetector
{
private:
   PivotSettings     m_settings;         // Sozlamalar
   string            m_symbol;           // Symbol
   ENUM_TIMEFRAMES   m_timeframe;        // Timeframe
   
   PivotData         m_lastPivotHigh;    // Oxirgi Pivot High
   PivotData         m_lastPivotLow;     // Oxirgi Pivot Low
   
   datetime          m_lastBarTime;      // Oxirgi tekshirilgan bar vaqti
   
public:
   // Konstruktor
   CPivotDetector(void);
   ~CPivotDetector(void);
   
   // Initsializatsiya
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe, PivotSettings &settings);
   void Deinit(void);
   
   // Pivot aniqlash
   void ScanForPivots(void);             // Barcha pivotlarni skanerlash
   
   // Ma'lumotlarni olish
   bool GetLastPivotHigh(PivotData &data);
   bool GetLastPivotLow(PivotData &data);
   
   // Yordamchi funksiyalar
   void Update(void);
   
private:
   bool IsPivotHigh(int shift, double &pivotPrice);
   bool IsPivotLow(int shift, double &pivotPrice);
};

//+------------------------------------------------------------------+
//| Konstruktor                                                      |
//+------------------------------------------------------------------+
CPivotDetector::CPivotDetector(void)
{
   m_lastBarTime = 0;
   
   m_lastPivotHigh.isValid = false;
   m_lastPivotHigh.price = 0;
   m_lastPivotHigh.barIndex = 0;
   m_lastPivotHigh.time = 0;
   
   m_lastPivotLow.isValid = false;
   m_lastPivotLow.price = 0;
   m_lastPivotLow.barIndex = 0;
   m_lastPivotLow.time = 0;
}

//+------------------------------------------------------------------+
//| Destruktor                                                       |
//+------------------------------------------------------------------+
CPivotDetector::~CPivotDetector(void)
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initsializatsiya                                                 |
//+------------------------------------------------------------------+
bool CPivotDetector::Init(string symbol, ENUM_TIMEFRAMES timeframe, PivotSettings &settings)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_settings = settings;
      
   // Dastlabki skanerlash
   ScanForPivots();
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitsializatsiya                                               |
//+------------------------------------------------------------------+
void CPivotDetector::Deinit(void)
{
   // Bo'sh
}

//+------------------------------------------------------------------+
//| Barcha pivotlarni skanerlash                                     |
//| Har barda oxirgi N ta barni tekshirish                          |
//+------------------------------------------------------------------+
void CPivotDetector::ScanForPivots(void)
{
   int barsToCheck = 100;  // Oxirgi 100 barda qidirish
   int minBars = m_settings.leftBars + m_settings.rightBars + 1;
   
   if(Bars(m_symbol, m_timeframe) < minBars + 10)
   {
      //Print("Pivot: Yetarlicha bar yo'q");
      return;
   }
   
   // Tasdiqlanish uchun rightBars o'tishi kerak
   // Shuning uchun shift >= rightBars dan boshlaymiz
   for(int shift = m_settings.rightBars; shift < barsToCheck; shift++)
   {
      // Pivot High tekshirish
      double pivotHighPrice;
      if(IsPivotHigh(shift, pivotHighPrice))
      {
         datetime pivotTime = iTime(m_symbol, m_timeframe, shift);
         
         // Yangi pivot yoki yangiroq pivot topildi
         if(!m_lastPivotHigh.isValid || pivotTime > m_lastPivotHigh.time)
         {
            m_lastPivotHigh.price = pivotHighPrice;
            m_lastPivotHigh.barIndex = shift;
            m_lastPivotHigh.time = pivotTime;
            m_lastPivotHigh.isValid = true;
         }
      }
      
      // Pivot Low tekshirish
      double pivotLowPrice;
      if(IsPivotLow(shift, pivotLowPrice))
      {
         datetime pivotTime = iTime(m_symbol, m_timeframe, shift);
         
         // Yangi pivot yoki yangiroq pivot topildi
         if(!m_lastPivotLow.isValid || pivotTime > m_lastPivotLow.time)
         {
            m_lastPivotLow.price = pivotLowPrice;
            m_lastPivotLow.barIndex = shift;
            m_lastPivotLow.time = pivotTime;
            m_lastPivotLow.isValid = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Pivot High tekshirish                                            |
//| Pine: ta.pivothigh(high, pLeft, pRight)                          |
//+------------------------------------------------------------------+
bool CPivotDetector::IsPivotHigh(int shift, double &pivotPrice)
{
   // Yetarlicha bar borligini tekshirish
   if(Bars(m_symbol, m_timeframe) < shift + m_settings.leftBars + 1)
      return false;
   
   // Markaziy bar
   double centerHigh = iHigh(m_symbol, m_timeframe, shift);
   if(centerHigh <= 0)
      return false;
   
   // Chap tarafdagi barlar (kattaroq indeks = o'tmishdagi barlar)
   for(int i = 1; i <= m_settings.leftBars; i++)
   {
      double leftHigh = iHigh(m_symbol, m_timeframe, shift + i);
      if(leftHigh >= centerHigh)
         return false;  // Chap tarafda yuqoriroq yoki teng bar bor
   }
   
   // O'ng tarafdagi barlar (kichikroq indeks = yangi barlar)
   for(int i = 1; i <= m_settings.rightBars; i++)
   {
      // shift dan kichik bo'lishi kerak
      if(shift - i < 0)
         break;
         
      double rightHigh = iHigh(m_symbol, m_timeframe, shift - i);
      if(rightHigh >= centerHigh)
         return false;  // O'ng tarafda yuqoriroq yoki teng bar bor
   }
   
   // Pivot High topildi!
   pivotPrice = centerHigh;
   return true;
}

//+------------------------------------------------------------------+
//| Pivot Low tekshirish                                             |
//| Pine: ta.pivotlow(low, pLeft, pRight)                            |
//+------------------------------------------------------------------+
bool CPivotDetector::IsPivotLow(int shift, double &pivotPrice)
{
   // Yetarlicha bar borligini tekshirish
   if(Bars(m_symbol, m_timeframe) < shift + m_settings.leftBars + 1)
      return false;
   
   // Markaziy bar
   double centerLow = iLow(m_symbol, m_timeframe, shift);
   if(centerLow <= 0)
      return false;
   
   // Chap tarafdagi barlar
   for(int i = 1; i <= m_settings.leftBars; i++)
   {
      double leftLow = iLow(m_symbol, m_timeframe, shift + i);
      if(leftLow <= centerLow)
         return false;  // Chap tarafda pastroq yoki teng bar bor
   }
   
   // O'ng tarafdagi barlar
   for(int i = 1; i <= m_settings.rightBars; i++)
   {
      if(shift - i < 0)
         break;
         
      double rightLow = iLow(m_symbol, m_timeframe, shift - i);
      if(rightLow <= centerLow)
         return false;  // O'ng tarafda pastroq yoki teng bar bor
   }
   
   // Pivot Low topildi!
   pivotPrice = centerLow;
   return true;
}

//+------------------------------------------------------------------+
//| Oxirgi Pivot High ma'lumotlarini olish                           |
//+------------------------------------------------------------------+
bool CPivotDetector::GetLastPivotHigh(PivotData &data)
{
   if(!m_lastPivotHigh.isValid)
      return false;
   
   data = m_lastPivotHigh;
   return true;
}

//+------------------------------------------------------------------+
//| Oxirgi Pivot Low ma'lumotlarini olish                            |
//+------------------------------------------------------------------+
bool CPivotDetector::GetLastPivotLow(PivotData &data)
{
   if(!m_lastPivotLow.isValid)
      return false;
   
   data = m_lastPivotLow;
   return true;
}

//+------------------------------------------------------------------+
//| Ma'lumotlarni yangilash                                          |
//+------------------------------------------------------------------+
void CPivotDetector::Update(void)
{
   datetime currentBarTime = iTime(m_symbol, m_timeframe, 0);
   
   // Yangi bar - qayta skanerlash
   if(currentBarTime != m_lastBarTime)
   {
      m_lastBarTime = currentBarTime;
      ScanForPivots();
   }
}

//+------------------------------------------------------------------+

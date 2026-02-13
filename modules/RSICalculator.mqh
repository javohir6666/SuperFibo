//+------------------------------------------------------------------+
//|                                                RSICalculator.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+

#include "Settings.mqh"

//+------------------------------------------------------------------+
//| RSI Calculator klassi                                            |
//+------------------------------------------------------------------+
class CRSICalculator
{
private:
   int               m_handle;           // RSI indikator handle
   RSISettings       m_settings;         // Sozlamalar
   string            m_symbol;           // Symbol
   ENUM_TIMEFRAMES   m_timeframe;        // Timeframe
   
   double            m_rsiBuffer[];      // RSI qiymatlari bufferi
   double            m_prevRSI[2];       // Oldingi 2 ta RSI qiymati (crossover uchun)
   
public:
   // Konstruktor
   CRSICalculator(void);
   ~CRSICalculator(void);
   
   // Initsializatsiya
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe, RSISettings &settings);
   void Deinit(void);
   
   // RSI qiymatini olish
   bool GetRSI(int shift, double &value);
   double GetCurrentRSI(void);
   
   // Signal tekshirish
   bool IsOversoldEntry(void);          // OS zonaga kirish (BUY signal)
   bool IsOverboughtEntry(void);        // OB zonaga kirish (SELL signal)
   
   // Yordamchi funksiyalar
   bool Update(void);                    // Ma'lumotlarni yangilash
};

//+------------------------------------------------------------------+
//| Konstruktor                                                      |
//+------------------------------------------------------------------+
CRSICalculator::CRSICalculator(void)
{
   m_handle = INVALID_HANDLE;
   m_prevRSI[0] = 0;
   m_prevRSI[1] = 0;
   ArraySetAsSeries(m_rsiBuffer, true);
}

//+------------------------------------------------------------------+
//| Destruktor                                                       |
//+------------------------------------------------------------------+
CRSICalculator::~CRSICalculator(void)
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initsializatsiya                                                 |
//+------------------------------------------------------------------+
bool CRSICalculator::Init(string symbol, ENUM_TIMEFRAMES timeframe, RSISettings &settings)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_settings = settings;
   
   // RSI indikatorini yaratish
   m_handle = iRSI(m_symbol, m_timeframe, m_settings.period, PRICE_CLOSE);
   
   if(m_handle == INVALID_HANDLE)
   {
      Print("RSI indikatorini yaratishda xato: ", GetLastError());
      return false;
   }
   
   // Indikator ma'lumotlarini kutish (3 soniya gacha)
   int attempts = 0;
   while(attempts < 30)
   {
      if(BarsCalculated(m_handle) > m_settings.period)
         break;
      Sleep(100);
      attempts++;
   }
   
   if(BarsCalculated(m_handle) <= m_settings.period)
   {
      Print("RSI indikatori ma'lumotlari tayyor emas");
      return false;
   }
   
   // Dastlabki yangilanish
   if(!Update())
   {
      Print("RSI dastlabki yangilanishda xato");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitsializatsiya                                               |
//+------------------------------------------------------------------+
void CRSICalculator::Deinit(void)
{
   if(m_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_handle);
      m_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Ma'lumotlarni yangilash                                          |
//+------------------------------------------------------------------+
bool CRSICalculator::Update(void)
{
   if(m_handle == INVALID_HANDLE)
      return false;
   
   // RSI ma'lumotlarini olish (3 ta bar)
   if(CopyBuffer(m_handle, 0, 0, 3, m_rsiBuffer) < 3)
   {
      Print("RSI ma'lumotlarini olishda xato: ", GetLastError());
      return false;
   }
   
   // Oldingi qiymatlarni saqlash (crossover aniqlash uchun)
   m_prevRSI[1] = m_prevRSI[0];
   m_prevRSI[0] = m_rsiBuffer[1];
   
   return true;
}

//+------------------------------------------------------------------+
//| Berilgan shift bo'yicha RSI qiymatini olish                     |
//+------------------------------------------------------------------+
bool CRSICalculator::GetRSI(int shift, double &value)
{
   if(m_handle == INVALID_HANDLE)
      return false;
   
   double buffer[];
   ArraySetAsSeries(buffer, true);
   
   if(CopyBuffer(m_handle, 0, shift, 1, buffer) < 1)
      return false;
   
   value = buffer[0];
   return true;
}

//+------------------------------------------------------------------+
//| Joriy RSI qiymatini olish                                        |
//+------------------------------------------------------------------+
double CRSICalculator::GetCurrentRSI(void)
{
   if(ArraySize(m_rsiBuffer) > 0)
      return m_rsiBuffer[0];
   return 0;
}

//+------------------------------------------------------------------+
//| Oversold zonaga kirish tekshiruvi (BUY signal)                  |
//| Pine: osEnter = ta.crossunder(rsi, rsiOS)                       |
//+------------------------------------------------------------------+
bool CRSICalculator::IsOversoldEntry(void)
{
   // Avvalgi bar OS dan yuqorida, hozirgi bar OS dan pastda
   // Bu RSI OS darajasini yuqoridan pastga kesib o'tganligini bildiradi
   if(m_prevRSI[1] > 0 && m_prevRSI[0] > 0)
   {
      if(m_prevRSI[1] >= m_settings.oversold && m_prevRSI[0] < m_settings.oversold)
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Overbought zonaga kirish tekshiruvi (SELL signal)               |
//| Pine: obEnter = ta.crossover(rsi, rsiOB)                        |
//+------------------------------------------------------------------+
bool CRSICalculator::IsOverboughtEntry(void)
{
   // Avvalgi bar OB dan pastda, hozirgi bar OB dan yuqorida
   // Bu RSI OB darajasini pastdan yuqoriga kesib o'tganligini bildiradi
   if(m_prevRSI[1] > 0 && m_prevRSI[0] > 0)
   {
      if(m_prevRSI[1] <= m_settings.overbought && m_prevRSI[0] > m_settings.overbought)
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+

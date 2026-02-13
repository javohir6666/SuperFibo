//+------------------------------------------------------------------+
//|                                                   NewsFilter.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//+------------------------------------------------------------------+
#include "Settings.mqh"

class CNewsFilter
{
private:
   NewsSettings   m_settings;
   string         m_symbol;
   string         m_baseCurrency;
   string         m_quoteCurrency;
   datetime       m_lastCheckTime;
   bool           m_isNewsTime; // Keshlangan holat

public:
   CNewsFilter() : m_lastCheckTime(0), m_isNewsTime(false) {}
   ~CNewsFilter() {}

   // Initsializatsiya
   void Init(string symbol, NewsSettings &settings)
   {
      m_symbol = symbol;
      m_settings = settings;
      
      // Valyutalarni avtomatik aniqlash (Masalan: EURUSD -> EUR, USD)
      m_baseCurrency = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE);
      m_quoteCurrency = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);
      
      Print("NewsFilter: Valyutalar - ", m_baseCurrency, " va ", m_quoteCurrency);
   }

   // Asosiy tekshiruv funksiyasi
   bool IsNewsTime()
   {
      if(!m_settings.enabled) return false;

      // Har tikda so'rov yubormaslik uchun har 1 daqiqada yangilaymiz
      if(TimeCurrent() - m_lastCheckTime < 60) 
         return m_isNewsTime;

      m_lastCheckTime = TimeCurrent();
      m_isNewsTime = CheckCalendar();
      
      return m_isNewsTime;
   }

private:
   bool CheckCalendar()
   {
      MqlCalendarValue values[];
      datetime serverTime = TimeTradeServer();
      
      // Qidiruv oynasi: Hozirgi vaqtdan -4 soat va +4 soat
      datetime timeFrom = serverTime - 4 * 3600;
      datetime timeTo = serverTime + 4 * 3600;

      // 1. Barcha yangiliklarni olamiz
      if(CalendarValueHistory(values, timeFrom, timeTo, NULL, NULL))
      {
         int total = ArraySize(values);
         for(int i = 0; i < total; i++)
         {
            // 2. Hodisa tafsilotlarini olish (Event ID orqali)
            MqlCalendarEvent event;
            if(!CalendarEventById(values[i].event_id, event)) 
               continue;
            
            // 3. Mamlakat va Valyutani olish (Country ID orqali)
            // MqlCalendarEvent ichida currency yo'q, u MqlCalendarCountry da bor
            MqlCalendarCountry country;
            if(!CalendarCountryById(event.country_id, country))
               continue;

            // 4. Valyuta mosligini tekshirish
            // Bizga faqat shu paraga tegishli yoki USD yangiliklari kerak
            if(country.currency != m_baseCurrency && country.currency != m_quoteCurrency && country.currency != "USD") 
               continue;

            // 5. Muhimlik darajasini tekshirish
            if(event.importance == CALENDAR_IMPORTANCE_HIGH && !m_settings.includeHigh) continue;
            if(event.importance == CALENDAR_IMPORTANCE_MODERATE && !m_settings.includeMedium) continue;
            if(event.importance == CALENDAR_IMPORTANCE_LOW && !m_settings.includeLow) continue;
            if(event.importance == CALENDAR_IMPORTANCE_NONE) continue;

            // 6. Vaqt oralig'ini tekshirish
            datetime eventTime = values[i].time;
            
            // Yangilikdan oldingi taqiq vaqti (Start)
            datetime blockStart = eventTime - m_settings.beforeMinutes * 60;
            // Yangilikdan keyingi taqiq vaqti (End)
            datetime blockEnd = eventTime + m_settings.afterMinutes * 60;

            // Agar hozirgi vaqt taqiq oralig'iga tushsa
            if(serverTime >= blockStart && serverTime <= blockEnd)
            {
               // Print ichida event.name ishlatamiz (MqlCalendarEvent da name bor)
               // country.currency ishlatamiz (MqlCalendarCountry da currency bor)
               Print("⛔ NEWS FILTER: Savdo to'xtatildi! Yangilik: ", event.name, 
                     " | Valyuta: ", country.currency,
                     " | Vaqt: ", TimeToString(eventTime), 
                     " | Muhimlik: ", EnumToString(event.importance));
               return true; // Ha, hozir yangilik vaqti
            }
         }
      }
      
      return false; // Yangilik yo'q
   }
};
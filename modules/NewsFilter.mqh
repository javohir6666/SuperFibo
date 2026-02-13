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
      
      // Valyutalarni avtomatik aniqlash
      m_baseCurrency = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE);
      m_quoteCurrency = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);
      
      Print("NewsFilter: Valyutalar - ", m_baseCurrency, " va ", m_quoteCurrency);
   }

   // Asosiy tekshiruv funksiyasi (Savdoni bloklash uchun)
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
   
   // --- DASHBOARD UCHUN MA'LUMOT OLISH ---
   string GetNewsDashboardInfo(bool &isFilterActive)
   {
      isFilterActive = m_isNewsTime; // Hozir filtr yoqiqmi?
      
      if(!m_settings.enabled) return "News Filter: DISABLED";

      string text = "";
      MqlCalendarValue values[];
      datetime serverTime = TimeTradeServer();
      
      // Bugungi kun 00:00 dan 23:59 gacha bo'lgan yangiliklarni olamiz
      datetime dayStart = serverTime - (serverTime % 86400);
      datetime dayEnd = dayStart + 86400;

      if(CalendarValueHistory(values, dayStart, dayEnd, NULL, NULL))
      {
         int total = ArraySize(values);
         int count = 0;
         
         for(int i = 0; i < total; i++)
         {
            // O'tib ketgan yangiliklarni ko'rsatmaslik (ixtiyoriy)
            if(values[i].time < serverTime) continue;

            MqlCalendarEvent event;
            if(!CalendarEventById(values[i].event_id, event)) continue;
            
            MqlCalendarCountry country;
            if(!CalendarCountryById(event.country_id, country)) continue;

            // Valyuta filtri
            if(country.currency != m_baseCurrency && country.currency != m_quoteCurrency && country.currency != "USD") 
               continue;

            // Muhimlik filtri
            if(event.importance == CALENDAR_IMPORTANCE_HIGH && !m_settings.includeHigh) continue;
            if(event.importance == CALENDAR_IMPORTANCE_MODERATE && !m_settings.includeMedium) continue;
            if(event.importance == CALENDAR_IMPORTANCE_LOW && !m_settings.includeLow) continue;
            if(event.importance == CALENDAR_IMPORTANCE_NONE) continue;

            // Ro'yxatga qo'shish (Maksimum 5 ta kelgusi yangilik)
            if(count < 5)
            {
               string impact = (event.importance == CALENDAR_IMPORTANCE_HIGH) ? "🔴" : (event.importance == CALENDAR_IMPORTANCE_MODERATE) ? "🟠" : "🟢";
               string timeStr = TimeToString(values[i].time, TIME_MINUTES);
               
               // Nomini qisqartirish (uzun bo'lib ketmasligi uchun)
               string shortName = event.name;
               if(StringLen(shortName) > 20) shortName = StringSubstr(shortName, 0, 18) + "..";
               
               text += StringFormat("%s  %s %s  %s\n", timeStr, country.currency, impact, shortName);
               count++;
            }
         }
      }
      
      if(text == "") text = "No upcoming news today";
      return text;
   }

private:
   bool CheckCalendar()
   {
      MqlCalendarValue values[];
      datetime serverTime = TimeTradeServer();
      
      // Qidiruv oynasi: Hozirgi vaqtdan -4 soat va +4 soat
      datetime timeFrom = serverTime - 4 * 3600;
      datetime timeTo = serverTime + 4 * 3600;

      if(CalendarValueHistory(values, timeFrom, timeTo, NULL, NULL))
      {
         int total = ArraySize(values);
         for(int i = 0; i < total; i++)
         {
            MqlCalendarEvent event;
            if(!CalendarEventById(values[i].event_id, event)) continue;
            
            MqlCalendarCountry country;
            if(!CalendarCountryById(event.country_id, country)) continue;

            if(country.currency != m_baseCurrency && country.currency != m_quoteCurrency && country.currency != "USD") continue;

            if(event.importance == CALENDAR_IMPORTANCE_HIGH && !m_settings.includeHigh) continue;
            if(event.importance == CALENDAR_IMPORTANCE_MODERATE && !m_settings.includeMedium) continue;
            if(event.importance == CALENDAR_IMPORTANCE_LOW && !m_settings.includeLow) continue;
            if(event.importance == CALENDAR_IMPORTANCE_NONE) continue;

            datetime eventTime = values[i].time;
            datetime blockStart = eventTime - m_settings.beforeMinutes * 60;
            datetime blockEnd = eventTime + m_settings.afterMinutes * 60;

            if(serverTime >= blockStart && serverTime <= blockEnd)
            {
               Print("⛔ NEWS FILTER: Savdo to'xtatildi! Yangilik: ", event.name);
               return true;
            }
         }
      }
      return false;
   }
};

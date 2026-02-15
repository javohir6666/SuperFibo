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
   bool           m_isNewsTime;

public:
   CNewsFilter() : m_lastCheckTime(0), m_isNewsTime(false) {}
   ~CNewsFilter() {}

   void Init(string symbol, NewsSettings &settings)
   {
      m_symbol = symbol;
      m_settings = settings;
      m_baseCurrency = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE);
      m_quoteCurrency = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);
   }

   bool IsNewsTime()
   {
      if(!m_settings.enabled) return false;
      if(TimeCurrent() - m_lastCheckTime < 60) return m_isNewsTime;
      
      m_lastCheckTime = TimeCurrent();
      m_isNewsTime = CheckCalendar();
      return m_isNewsTime;
   }
   
   // --- DASHBOARD UCHUN ---
   string GetUpcomingNewsList()
   {
      if(!m_settings.enabled) return "News Filter: OFF";

      string text = "";
      MqlCalendarValue values[];
      datetime serverTime = TimeTradeServer();
      // Kelgusi 12 soatni ko'rsatish
      datetime timeFrom = serverTime; 
      datetime timeTo = serverTime + 12 * 3600;

      if(CalendarValueHistory(values, timeFrom, timeTo, NULL, NULL))
      {
         int total = ArraySize(values);
         int count = 0;
         
         for(int i = 0; i < total; i++)
         {
            MqlCalendarEvent event;
            if(!CalendarEventById(values[i].event_id, event)) continue;
            
            MqlCalendarCountry country;
            if(!CalendarCountryById(event.country_id, country)) continue;

            // Filtrlar
            if(country.currency != m_baseCurrency && country.currency != m_quoteCurrency && country.currency != "USD") continue;
            
            bool isHigh = (event.importance == CALENDAR_IMPORTANCE_HIGH);
            bool isMedium = (event.importance == CALENDAR_IMPORTANCE_MODERATE);
            
            if(isHigh && !m_settings.includeHigh) continue;
            if(isMedium && !m_settings.includeMedium) continue;
            if(event.importance == CALENDAR_IMPORTANCE_LOW && !m_settings.includeLow) continue;
            if(event.importance == CALENDAR_IMPORTANCE_NONE) continue;

            if(count < 4) // Maksimum 4 ta yangilik
            {
               string impact = isHigh ? "🔴" : (isMedium ? "🟠" : "🟢");
               string timeStr = TimeToString(values[i].time, TIME_MINUTES);
               string shortName = ShortenNewsName(event.name); // Nomni qisqartirish
               
               // Format: 14:30 USD 🔴 CPI m/m
               text += StringFormat("%s %s %s %s\n", timeStr, country.currency, impact, shortName);
               count++;
            }
         }
      }
      
      if(text == "") text = "No news in next 12h";
      return text;
   }

private:
   // Yangilik nomlarini qisqartirish logikasi
   string ShortenNewsName(string name)
   {
      if(StringFind(name, "Consumer Price Index") != -1) return "CPI";
      if(StringFind(name, "Gross Domestic Product") != -1) return "GDP";
      if(StringFind(name, "Interest Rate") != -1) return "Rate Decision";
      if(StringFind(name, "Non-Farm Employment") != -1) return "NFP";
      if(StringFind(name, "Unemployment Rate") != -1) return "Unemployment";
      if(StringFind(name, "Federal Open Market Committee") != -1) return "FOMC";
      if(StringFind(name, "Meeting Minutes") != -1) return "Minutes";
      if(StringFind(name, "Retail Sales") != -1) return "Retail Sales";
      if(StringFind(name, "Speech") != -1) return "Speech";
      if(StringFind(name, "Statement") != -1) return "Statement";
      if(StringFind(name, "Inventories") != -1) return "Inventories";
      
      // Agar kalit so'z topilmasa, shunchaki kesib qo'yamiz
      if(StringLen(name) > 15) return StringSubstr(name, 0, 13) + "..";
      return name;
   }

   bool CheckCalendar()
   {
      MqlCalendarValue values[];
      datetime serverTime = TimeTradeServer();
      datetime timeFrom = serverTime - 12 * 3600; // Sal oldinroqdan qidirish
      datetime timeTo = serverTime + 12 * 3600;

      if(CalendarValueHistory(values, timeFrom, timeTo, NULL, NULL))
      {
         for(int i=0; i<ArraySize(values); i++)
         {
            MqlCalendarEvent event;
            CalendarEventById(values[i].event_id, event);
            MqlCalendarCountry country;
            CalendarCountryById(event.country_id, country);

            if(country.currency != m_baseCurrency && country.currency != m_quoteCurrency && country.currency != "USD") continue;
            if(event.importance == CALENDAR_IMPORTANCE_HIGH && !m_settings.includeHigh) continue;
            if(event.importance == CALENDAR_IMPORTANCE_MODERATE && !m_settings.includeMedium) continue;
            
            datetime eventTime = values[i].time;
            datetime blockStart = eventTime - m_settings.beforeMinutes * 60;
            datetime blockEnd = eventTime + m_settings.afterMinutes * 60;

            if(serverTime >= blockStart && serverTime <= blockEnd) return true;
         }
      }
      return false;
   }
};
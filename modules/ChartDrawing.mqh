//+------------------------------------------------------------------+
//|                                               ChartDrawing.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//+------------------------------------------------------------------+
#include "Settings.mqh"

class CChartDrawing
{
private:
   DrawSettings      m_settings;
   string            m_symbol;
   long              m_chartID;
   string            m_prefix;
   
public:
   CChartDrawing(void) : m_chartID(0), m_prefix("SuperFibo_") {}
   ~CChartDrawing(void) { Deinit(); }

   bool Init(string symbol, long chartID, DrawSettings &settings, string prefix = "SuperFibo_")
   {
      m_symbol = symbol;
      m_chartID = chartID;
      m_settings = settings;
      m_prefix = prefix;
      return true;
   }

   void Deinit(void) { DeleteAllObjects(); }

   // --- YANGILIKLAR PANELINI CHIZISH ---
   void DrawNewsPanel(string newsText, bool isFilterActive)
   {
      string nameHeader = m_prefix + "NewsHeader";
      string nameBody = m_prefix + "NewsBody";
      
      color statusColor = isFilterActive ? clrRed : clrBlue;
      string statusText = isFilterActive ? "⛔ TRADING STOPPED (NEWS)" : "✅ TRADING ALLOWED";

      // 1. Status (Sarlavha)
      if(ObjectFind(m_chartID, nameHeader) < 0) ObjectCreate(m_chartID, nameHeader, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(m_chartID, nameHeader, OBJPROP_XDISTANCE, 20); // Chapdan masofa
      ObjectSetInteger(m_chartID, nameHeader, OBJPROP_YDISTANCE, 200); // Yuqoridan masofa
      ObjectSetInteger(m_chartID, nameHeader, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(m_chartID, nameHeader, OBJPROP_TEXT, statusText);
      ObjectSetString(m_chartID, nameHeader, OBJPROP_FONT, "Arial Black");
      ObjectSetInteger(m_chartID, nameHeader, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(m_chartID, nameHeader, OBJPROP_COLOR, statusColor);
      ObjectSetInteger(m_chartID, nameHeader, OBJPROP_BACK, false);

      // 2. Yangiliklar ro'yxati (Matn)
      if(ObjectFind(m_chartID, nameBody) < 0) ObjectCreate(m_chartID, nameBody, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(m_chartID, nameBody, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(m_chartID, nameBody, OBJPROP_YDISTANCE, 225);
      ObjectSetInteger(m_chartID, nameBody, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(m_chartID, nameBody, OBJPROP_TEXT, newsText);
      ObjectSetString(m_chartID, nameBody, OBJPROP_FONT, "Consolas"); // Tekis chiqishi uchun
      ObjectSetInteger(m_chartID, nameBody, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(m_chartID, nameBody, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(m_chartID, nameBody, OBJPROP_BACK, false);
      
      ChartRedraw(m_chartID);
   }

   // --- ESKI CHART CHIZISH FUNKSIYALARI ---
   bool DrawBuyFibo(FiboStructure &fibo, int lineBars)
   {
      if(!fibo.isActive) return false;
      DeleteBuyFibo();
      datetime t1 = TimeCurrent();
      datetime t2 = t1 + lineBars * PeriodSeconds(PERIOD_CURRENT);
      
      if(fibo.entry1.show) {
         CreateLine(m_prefix + "Buy_Entry1", t1, fibo.entry1.price, t2, fibo.entry1.price, fibo.entry1.lineColor, 2);
         CreateLabel(m_prefix + "Buy_Entry1_Lbl", t1, fibo.entry1.price, fibo.entry1.name, clrGreen, clrWhite);
      }
      if(fibo.entry2.show) {
         CreateLine(m_prefix + "Buy_Entry2", t1, fibo.entry2.price, t2, fibo.entry2.price, fibo.entry2.lineColor, 1);
      }
      if(fibo.entry3.show) {
         CreateLine(m_prefix + "Buy_Entry3", t1, fibo.entry3.price, t2, fibo.entry3.price, fibo.entry3.lineColor, 1);
      }
      if(fibo.tp1.show) {
         CreateLine(m_prefix + "Buy_TP1", t1, fibo.tp1.price, t2, fibo.tp1.price, fibo.tp1.lineColor, 1);
      }
      if(fibo.tp2.show) {
         CreateLine(m_prefix + "Buy_TP2", t1, fibo.tp2.price, t2, fibo.tp2.price, fibo.tp2.lineColor, 1);
      }
      ChartRedraw(m_chartID);
      return true;
   }

   bool DrawSellFibo(FiboStructure &fibo, int lineBars)
   {
      if(!fibo.isActive) return false;
      DeleteSellFibo();
      datetime t1 = TimeCurrent();
      datetime t2 = t1 + lineBars * PeriodSeconds(PERIOD_CURRENT);
      
      if(fibo.entry1.show) {
         CreateLine(m_prefix + "Sell_Entry1", t1, fibo.entry1.price, t2, fibo.entry1.price, fibo.entry1.lineColor, 2);
         CreateLabel(m_prefix + "Sell_Entry1_Lbl", t1, fibo.entry1.price, fibo.entry1.name, clrRed, clrWhite);
      }
      if(fibo.entry2.show) {
         CreateLine(m_prefix + "Sell_Entry2", t1, fibo.entry2.price, t2, fibo.entry2.price, fibo.entry2.lineColor, 1);
      }
      if(fibo.entry3.show) {
         CreateLine(m_prefix + "Sell_Entry3", t1, fibo.entry3.price, t2, fibo.entry3.price, fibo.entry3.lineColor, 1);
      }
      if(fibo.tp1.show) {
         CreateLine(m_prefix + "Sell_TP1", t1, fibo.tp1.price, t2, fibo.tp1.price, fibo.tp1.lineColor, 1);
      }
      if(fibo.tp2.show) {
         CreateLine(m_prefix + "Sell_TP2", t1, fibo.tp2.price, t2, fibo.tp2.price, fibo.tp2.lineColor, 1);
      }
      ChartRedraw(m_chartID);
      return true;
   }

   void DeleteBuyFibo(void) { DeleteObjectsByPrefix(m_prefix + "Buy_"); }
   void DeleteSellFibo(void) { DeleteObjectsByPrefix(m_prefix + "Sell_"); }
   void DeleteAllObjects(void) { DeleteObjectsByPrefix(m_prefix); }

private:
   bool CreateLine(string name, datetime t1, double p1, datetime t2, double p2, color clr, int w)
   {
      if(ObjectCreate(m_chartID, name, OBJ_TREND, 0, t1, p1, t2, p2)) {
         ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, clr);
         ObjectSetInteger(m_chartID, name, OBJPROP_WIDTH, w);
         ObjectSetInteger(m_chartID, name, OBJPROP_RAY_RIGHT, false);
         return true;
      }
      return false;
   }

   bool CreateLabel(string name, datetime t, double p, string txt, color bg, color txtColor)
   {
      if(ObjectCreate(m_chartID, name, OBJ_TEXT, 0, t, p)) {
         ObjectSetString(m_chartID, name, OBJPROP_TEXT, txt);
         ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, txtColor);
         ObjectSetInteger(m_chartID, name, OBJPROP_FONTSIZE, 8);
         return true;
      }
      return false;
   }

   void DeleteObjectsByPrefix(string prefix)
   {
      for(int i = ObjectsTotal(m_chartID) - 1; i >= 0; i--) {
         string name = ObjectName(m_chartID, i);
         if(StringFind(name, prefix) == 0) ObjectDelete(m_chartID, name);
      }
   }
};

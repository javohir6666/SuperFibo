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
   
   // Panel ranglari
   color             m_bgColor;
   color             m_textColor;
   color             m_greenColor;
   color             m_redColor;

public:
   CChartDrawing(void) : m_chartID(0), m_prefix("SF_Dash_") {
      m_bgColor = C'30,30,30'; // To'q kulrang fon
      m_textColor = clrWhite;
      m_greenColor = C'46,204,113';
      m_redColor = C'231,76,60';
   }
   ~CChartDrawing(void) { Deinit(); }

   bool Init(string symbol, long chartID, DrawSettings &settings)
   {
      m_symbol = symbol;
      m_chartID = chartID;
      m_settings = settings;
      return true;
   }

   void Deinit(void) { ObjectsDeleteAll(m_chartID, m_prefix); }

   // --- MAIN DASHBOARD ---
   void DrawDashboard(DashboardState &state)
   {
      int x = 10;
      int y = 20;
      int w = 220; // Kenglik
      int h = 300; // Balandlik
      int lineHeight = 18;
      
      // 1. Asosiy Fon (Main Background)
      CreateRect("BG", x, y, w, h, m_bgColor, true);
      
      // 2. Header (SuperFibo EA)
      CreateLabel("Header", x + 10, y + 10, "⚡ SUPER FIBO EA v2.0", clrGold, 10, true);
      CreateLabel("SubHeader", x + 10, y + 28, m_symbol + " | " + TimeToString(TimeCurrent(), TIME_MINUTES), clrGray, 8);
      
      y += 50;
      
      // 3. Trading Status Box
      color statusColor = state.isTradingAllowed ? m_greenColor : m_redColor;
      string statusText = state.isTradingAllowed ? "TRADING ALLOWED" : state.statusReason;
      
      CreateRect("StatusBG", x + 5, y, w - 10, 25, statusColor, true);
      CreateLabel("StatusTxt", x + w/2, y + 5, statusText, clrWhite, 9, true, ANCHOR_UPPER); // O'rtada
      
      y += 35;
      
      // 4. Trade Info
      CreateLabel("Lbl_Signal", x + 10, y, "Signal:", clrGray);
      string sigTxt = state.hasActiveSignal ? (state.signalType + " (Entry " + IntegerToString(state.currentEntry) + ")") : "No Signal";
      CreateLabel("Val_Signal", x + 80, y, sigTxt, state.hasActiveSignal ? (state.signalType=="BUY"?m_greenColor:m_redColor) : clrWhite);
      
      y += lineHeight;
      CreateLabel("Lbl_Action", x + 10, y, "Action:", clrGray);
      CreateLabel("Val_Action", x + 80, y, state.lastAction, clrWhite);
      
      y += lineHeight + 5;
      
      // --- TUZATILGAN QATOR (filled = true qo'shildi) ---
      CreateRect("Sep1", x + 10, y, w - 20, 1, clrGray, true); 
      y += 10;
      
      // 5. News Section
      CreateLabel("Lbl_News", x + 10, y, "📅 UPCOMING NEWS:", clrGold);
      y += lineHeight;
      
      // Yangiliklar ro'yxatini alohida qatorlarga bo'lib yozish
      string newsLines[];
      StringSplit(state.newsText, '\n', newsLines);
      for(int i=0; i<ArraySize(newsLines); i++)
      {
         if(newsLines[i] == "") continue;
         CreateLabel("News_"+IntegerToString(i), x + 10, y, newsLines[i], clrWhite, 8);
         y += 14;
      }
      
      y += 10;
      
      // --- TUZATILGAN QATOR (filled = true qo'shildi) ---
      CreateRect("Sep2", x + 10, y, w - 20, 1, clrGray, true);
      y += 10;
      
      // 6. Logs Section
      CreateLabel("Lbl_Log", x + 10, y, "📝 LIVE LOGS:", clrGold);
      y += lineHeight;
      
      string logLines[];
      StringSplit(state.logText, '\n', logLines);
      for(int i=0; i<ArraySize(logLines); i++)
      {
         if(logLines[i] == "") continue;
         CreateLabel("Log_"+IntegerToString(i), x + 10, y, "• " + logLines[i], clrSilver, 7);
         y += 12;
      }
      
      ChartRedraw(m_chartID);
   }
   
   // --- FIBO LINE DRAWING ---
   void DrawBuyFibo(FiboStructure &fibo, int lineBars)
   {
      DeleteObjectsByPrefix("SF_Buy_"); // Tozalash
      
      datetime t1 = fibo.signalTime; // Signal vaqti
      datetime t2 = t1 + lineBars * PeriodSeconds(PERIOD_CURRENT);
      
      // Entry 1
      CreateLine("SF_Buy_E1", t1, fibo.entry1.price, t2, fibo.entry1.price, clrBlue, 2);
      CreateText("SF_Buy_T_E1", t2, fibo.entry1.price, " Buy 1", clrBlue);
      
      // TP1
      if(fibo.tp1.show) {
         CreateLine("SF_Buy_TP1", t1, fibo.tp1.price, t2, fibo.tp1.price, clrGreen, 1);
         CreateText("SF_Buy_T_TP1", t2, fibo.tp1.price, " TP1", clrGreen);
      }
      // TP2
      if(fibo.tp2.show) {
         CreateLine("SF_Buy_TP2", t1, fibo.tp2.price, t2, fibo.tp2.price, clrGreen, 1);
         CreateText("SF_Buy_T_TP2", t2, fibo.tp2.price, " TP2", clrGreen);
      }
      // SL
      if(fibo.sl.show) {
         CreateLine("SF_Buy_SL", t1, fibo.sl.price, t2, fibo.sl.price, clrRed, 1);
         CreateText("SF_Buy_T_SL", t2, fibo.sl.price, " SL", clrRed);
      }
      
      ChartRedraw(m_chartID);
   }
   
   void DrawSellFibo(FiboStructure &fibo, int lineBars)
   {
      DeleteObjectsByPrefix("SF_Sell_"); // Tozalash
      
      datetime t1 = fibo.signalTime;
      datetime t2 = t1 + lineBars * PeriodSeconds(PERIOD_CURRENT);
      
      // Entry 1
      CreateLine("SF_Sell_E1", t1, fibo.entry1.price, t2, fibo.entry1.price, clrBlue, 2);
      CreateText("SF_Sell_T_E1", t2, fibo.entry1.price, " Sell 1", clrBlue);
      
      // TP1
      if(fibo.tp1.show) {
         CreateLine("SF_Sell_TP1", t1, fibo.tp1.price, t2, fibo.tp1.price, clrGreen, 1);
         CreateText("SF_Sell_T_TP1", t2, fibo.tp1.price, " TP1", clrGreen);
      }
      // TP2
      if(fibo.tp2.show) {
         CreateLine("SF_Sell_TP2", t1, fibo.tp2.price, t2, fibo.tp2.price, clrGreen, 1);
         CreateText("SF_Sell_T_TP2", t2, fibo.tp2.price, " TP2", clrGreen);
      }
      // SL
      if(fibo.sl.show) {
         CreateLine("SF_Sell_SL", t1, fibo.sl.price, t2, fibo.sl.price, clrRed, 1);
         CreateText("SF_Sell_T_SL", t2, fibo.sl.price, " SL", clrRed);
      }

      ChartRedraw(m_chartID);
   }
   
   // --- OLDINGI KODLAR UCHUN STUB ---
   void DrawNewsPanel(string info, bool active) { }

private:
   // Primitivlar
   void CreateRect(string name, int x, int y, int w, int h, color bg, bool filled)
   {
      string objName = m_prefix + name;
      if(ObjectFind(m_chartID, objName) < 0) ObjectCreate(m_chartID, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(m_chartID, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chartID, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(m_chartID, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(m_chartID, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(m_chartID, objName, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(m_chartID, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(m_chartID, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chartID, objName, OBJPROP_BACK, false);
   }

   void CreateLabel(string name, int x, int y, string text, color clr, int size=8, bool bold=false, ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER)
   {
      string objName = m_prefix + name;
      if(ObjectFind(m_chartID, objName) < 0) ObjectCreate(m_chartID, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(m_chartID, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chartID, objName, OBJPROP_YDISTANCE, y);
      ObjectSetString(m_chartID, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chartID, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chartID, objName, OBJPROP_FONTSIZE, size);
      ObjectSetString(m_chartID, objName, OBJPROP_FONT, bold ? "Arial Black" : "Consolas");
      ObjectSetInteger(m_chartID, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chartID, objName, OBJPROP_ANCHOR, anchor);
   }
   
   void CreateLine(string name, datetime t1, double p1, datetime t2, double p2, color clr, int width)
   {
      if(ObjectFind(m_chartID, name) < 0) ObjectCreate(m_chartID, name, OBJ_TREND, 0, 0, 0);
      ObjectSetInteger(m_chartID, name, OBJPROP_TIME, 0, t1);
      ObjectSetDouble(m_chartID, name, OBJPROP_PRICE, 0, p1);
      ObjectSetInteger(m_chartID, name, OBJPROP_TIME, 1, t2);
      ObjectSetDouble(m_chartID, name, OBJPROP_PRICE, 1, p2);
      ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chartID, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(m_chartID, name, OBJPROP_RAY_RIGHT, false);
   }
   
   void CreateText(string name, datetime t, double p, string text, color clr)
   {
      if(ObjectFind(m_chartID, name) < 0) ObjectCreate(m_chartID, name, OBJ_TEXT, 0, 0, 0);
      ObjectSetInteger(m_chartID, name, OBJPROP_TIME, t);
      ObjectSetDouble(m_chartID, name, OBJPROP_PRICE, p);
      ObjectSetString(m_chartID, name, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chartID, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   
   void DeleteObjectsByPrefix(string prefix)
   {
      for(int i = ObjectsTotal(m_chartID) - 1; i >= 0; i--) {
         string name = ObjectName(m_chartID, i);
         if(StringFind(name, prefix) >= 0) ObjectDelete(m_chartID, name);
      }
   }
};

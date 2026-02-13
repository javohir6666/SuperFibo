//+------------------------------------------------------------------+
//|                                               ChartDrawing.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+

#include "Settings.mqh"

//+------------------------------------------------------------------+
//| Chart Drawing Manager klassi                                    |
//+------------------------------------------------------------------+
class CChartDrawing
{
private:
   DrawSettings      m_settings;         // Sozlamalar
   string            m_symbol;           // Symbol
   long              m_chartID;          // Chart ID
   
   string            m_prefix;           // Obyekt nomlari prefiksi
   
public:
   // Konstruktor
   CChartDrawing(void);
   ~CChartDrawing(void);
   
   // Initsializatsiya
   bool Init(string symbol, long chartID, DrawSettings &settings, string prefix = "SuperFibo_");
   void Deinit(void);
   
   // Fibo chizish
   bool DrawBuyFibo(FiboStructure &fibo, int lineBars);
   bool DrawSellFibo(FiboStructure &fibo, int lineBars);
   
   // Pivot chizish
   bool DrawPivotHigh(datetime time, double price);
   bool DrawPivotLow(datetime time, double price);
   
   // S/R chiziqlar
   bool DrawSupportLine(datetime time, double price, int length);
   bool DrawResistanceLine(datetime time, double price, int length);
   
   // Tozalash
   void DeleteBuyFibo(void);
   void DeleteSellFibo(void);
   void DeleteAllObjects(void);
   
private:
   // Yordamchi funksiyalar
   bool CreateLine(string name, datetime time1, double price1, datetime time2, double price2, color clr, int width = 1);
   bool CreateLabel(string name, datetime time, double price, string text, color bgColor, color textColor, int corner = CORNER_LEFT_UPPER);
   void DeleteObjectsByPrefix(string prefix);
};

//+------------------------------------------------------------------+
//| Konstruktor                                                      |
//+------------------------------------------------------------------+
CChartDrawing::CChartDrawing(void)
{
   m_chartID = 0;
   m_prefix = "SuperFibo_";
}

//+------------------------------------------------------------------+
//| Destruktor                                                       |
//+------------------------------------------------------------------+
CChartDrawing::~CChartDrawing(void)
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initsializatsiya                                                 |
//+------------------------------------------------------------------+
bool CChartDrawing::Init(string symbol, long chartID, DrawSettings &settings, string prefix = "SuperFibo_")
{
   m_symbol = symbol;
   m_chartID = chartID;
   m_settings = settings;
   m_prefix = prefix;
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitsializatsiya                                               |
//+------------------------------------------------------------------+
void CChartDrawing::Deinit(void)
{
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| BUY Fibonacci chizish                                            |
//+------------------------------------------------------------------+
bool CChartDrawing::DrawBuyFibo(FiboStructure &fibo, int lineBars)
{
   if(!fibo.isActive)
      return false;
   
   // Eski BUY Fibo ni o'chirish
   DeleteBuyFibo();
   
   datetime startTime = TimeCurrent();
   datetime endTime = startTime + lineBars * PeriodSeconds(PERIOD_CURRENT);
   
   // Entry 1 (asosiy, har doim ko'rsatiladi)
   if(fibo.entry1.show)
   {
      CreateLine(m_prefix + "Buy_Entry1", startTime, fibo.entry1.price, endTime, fibo.entry1.price, 
                 fibo.entry1.lineColor, 2);
      CreateLabel(m_prefix + "Buy_Entry1_Label", startTime, fibo.entry1.price, fibo.entry1.name,
                  clrGreen, clrWhite);
   }
   
   // Entry 2
   if(fibo.entry2.show)
   {
      CreateLine(m_prefix + "Buy_Entry2", startTime, fibo.entry2.price, endTime, fibo.entry2.price, 
                 fibo.entry2.lineColor, 1);
      string labelText = fibo.entry2.name + " (" + DoubleToString(fibo.entry2.price, _Digits) + ")";
      CreateLabel(m_prefix + "Buy_Entry2_Label", endTime, fibo.entry2.price, labelText,
                  fibo.entry2.lineColor, clrWhite);
   }
   
   // Entry 3
   if(fibo.entry3.show)
   {
      CreateLine(m_prefix + "Buy_Entry3", startTime, fibo.entry3.price, endTime, fibo.entry3.price, 
                 fibo.entry3.lineColor, 1);
      string labelText = fibo.entry3.name + " (" + DoubleToString(fibo.entry3.price, _Digits) + ")";
      CreateLabel(m_prefix + "Buy_Entry3_Label", endTime, fibo.entry3.price, labelText,
                  fibo.entry3.lineColor, clrWhite);
   }
   
   // TP1
   if(fibo.tp1.show)
   {
      CreateLine(m_prefix + "Buy_TP1", startTime, fibo.tp1.price, endTime, fibo.tp1.price, 
                 fibo.tp1.lineColor, 1);
      string labelText = fibo.tp1.name + " (" + DoubleToString(fibo.tp1.price, _Digits) + ")";
      CreateLabel(m_prefix + "Buy_TP1_Label", endTime, fibo.tp1.price, labelText,
                  fibo.tp1.lineColor, clrWhite);
   }
   
   // TP2
   if(fibo.tp2.show)
   {
      CreateLine(m_prefix + "Buy_TP2", startTime, fibo.tp2.price, endTime, fibo.tp2.price, 
                 fibo.tp2.lineColor, 1);
      string labelText = fibo.tp2.name + " (" + DoubleToString(fibo.tp2.price, _Digits) + ")";
      CreateLabel(m_prefix + "Buy_TP2_Label", endTime, fibo.tp2.price, labelText,
                  fibo.tp2.lineColor, clrWhite);
   }
   
   ChartRedraw(m_chartID);
   return true;
}

//+------------------------------------------------------------------+
//| SELL Fibonacci chizish                                           |
//+------------------------------------------------------------------+
bool CChartDrawing::DrawSellFibo(FiboStructure &fibo, int lineBars)
{
   if(!fibo.isActive)
      return false;
   
   // Eski SELL Fibo ni o'chirish
   DeleteSellFibo();
   
   datetime startTime = TimeCurrent();
   datetime endTime = startTime + lineBars * PeriodSeconds(PERIOD_CURRENT);
   
   // Entry 1 (asosiy, har doim ko'rsatiladi)
   if(fibo.entry1.show)
   {
      CreateLine(m_prefix + "Sell_Entry1", startTime, fibo.entry1.price, endTime, fibo.entry1.price, 
                 fibo.entry1.lineColor, 2);
      CreateLabel(m_prefix + "Sell_Entry1_Label", startTime, fibo.entry1.price, fibo.entry1.name,
                  clrRed, clrWhite);
   }
   
   // Entry 2
   if(fibo.entry2.show)
   {
      CreateLine(m_prefix + "Sell_Entry2", startTime, fibo.entry2.price, endTime, fibo.entry2.price, 
                 fibo.entry2.lineColor, 1);
      string labelText = fibo.entry2.name + " (" + DoubleToString(fibo.entry2.price, _Digits) + ")";
      CreateLabel(m_prefix + "Sell_Entry2_Label", endTime, fibo.entry2.price, labelText,
                  fibo.entry2.lineColor, clrWhite);
   }
   
   // Entry 3
   if(fibo.entry3.show)
   {
      CreateLine(m_prefix + "Sell_Entry3", startTime, fibo.entry3.price, endTime, fibo.entry3.price, 
                 fibo.entry3.lineColor, 1);
      string labelText = fibo.entry3.name + " (" + DoubleToString(fibo.entry3.price, _Digits) + ")";
      CreateLabel(m_prefix + "Sell_Entry3_Label", endTime, fibo.entry3.price, labelText,
                  fibo.entry3.lineColor, clrWhite);
   }
   
   // TP1
   if(fibo.tp1.show)
   {
      CreateLine(m_prefix + "Sell_TP1", startTime, fibo.tp1.price, endTime, fibo.tp1.price, 
                 fibo.tp1.lineColor, 1);
      string labelText = fibo.tp1.name + " (" + DoubleToString(fibo.tp1.price, _Digits) + ")";
      CreateLabel(m_prefix + "Sell_TP1_Label", endTime, fibo.tp1.price, labelText,
                  fibo.tp1.lineColor, clrWhite);
   }
   
   // TP2
   if(fibo.tp2.show)
   {
      CreateLine(m_prefix + "Sell_TP2", startTime, fibo.tp2.price, endTime, fibo.tp2.price, 
                 fibo.tp2.lineColor, 1);
      string labelText = fibo.tp2.name + " (" + DoubleToString(fibo.tp2.price, _Digits) + ")";
      CreateLabel(m_prefix + "Sell_TP2_Label", endTime, fibo.tp2.price, labelText,
                  fibo.tp2.lineColor, clrWhite);
   }
   
   ChartRedraw(m_chartID);
   return true;
}

//+------------------------------------------------------------------+
//| Pivot High chizish                                               |
//+------------------------------------------------------------------+
bool CChartDrawing::DrawPivotHigh(datetime time, double price)
{
   string name = m_prefix + "PH_" + TimeToString(time);
   
   if(ObjectCreate(m_chartID, name, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(m_chartID, name, OBJPROP_TEXT, "PH");
      ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(m_chartID, name, OBJPROP_FONTSIZE, 8);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Pivot Low chizish                                                |
//+------------------------------------------------------------------+
bool CChartDrawing::DrawPivotLow(datetime time, double price)
{
   string name = m_prefix + "PL_" + TimeToString(time);
   
   if(ObjectCreate(m_chartID, name, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(m_chartID, name, OBJPROP_TEXT, "PL");
      ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(m_chartID, name, OBJPROP_FONTSIZE, 8);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Support chiziq chizish                                           |
//+------------------------------------------------------------------+
bool CChartDrawing::DrawSupportLine(datetime time, double price, int length)
{
   string name = m_prefix + "Support_" + TimeToString(time);
   datetime endTime = time + length * PeriodSeconds(PERIOD_CURRENT);
   
   return CreateLine(name, time, price, endTime, price, clrGreen, 1);
}

//+------------------------------------------------------------------+
//| Resistance chiziq chizish                                        |
//+------------------------------------------------------------------+
bool CChartDrawing::DrawResistanceLine(datetime time, double price, int length)
{
   string name = m_prefix + "Resistance_" + TimeToString(time);
   datetime endTime = time + length * PeriodSeconds(PERIOD_CURRENT);
   
   return CreateLine(name, time, price, endTime, price, clrRed, 1);
}

//+------------------------------------------------------------------+
//| BUY Fibo ni o'chirish                                            |
//+------------------------------------------------------------------+
void CChartDrawing::DeleteBuyFibo(void)
{
   DeleteObjectsByPrefix(m_prefix + "Buy_");
}

//+------------------------------------------------------------------+
//| SELL Fibo ni o'chirish                                           |
//+------------------------------------------------------------------+
void CChartDrawing::DeleteSellFibo(void)
{
   DeleteObjectsByPrefix(m_prefix + "Sell_");
}

//+------------------------------------------------------------------+
//| Barcha obyektlarni o'chirish                                     |
//+------------------------------------------------------------------+
void CChartDrawing::DeleteAllObjects(void)
{
   DeleteObjectsByPrefix(m_prefix);
}

//+------------------------------------------------------------------+
//| Chiziq yaratish                                                  |
//+------------------------------------------------------------------+
bool CChartDrawing::CreateLine(string name, datetime time1, double price1, datetime time2, double price2, color clr, int width = 1)
{
   if(ObjectCreate(m_chartID, name, OBJ_TREND, 0, time1, price1, time2, price2))
   {
      ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chartID, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(m_chartID, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(m_chartID, name, OBJPROP_BACK, false);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Label yaratish                                                   |
//+------------------------------------------------------------------+
bool CChartDrawing::CreateLabel(string name, datetime time, double price, string text, color bgColor, color textColor, int corner = CORNER_LEFT_UPPER)
{
   if(ObjectCreate(m_chartID, name, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(m_chartID, name, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(m_chartID, name, OBJPROP_FONTSIZE, GetLabelSize(m_settings.labelSize));
      ObjectSetInteger(m_chartID, name, OBJPROP_BACK, false);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Prefiks bo'yicha obyektlarni o'chirish                          |
//+------------------------------------------------------------------+
void CChartDrawing::DeleteObjectsByPrefix(string prefix)
{
   int total = ObjectsTotal(m_chartID);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(m_chartID, i);
      
      if(StringFind(name, prefix) == 0)
      {
         ObjectDelete(m_chartID, name);
      }
   }
}

//+------------------------------------------------------------------+

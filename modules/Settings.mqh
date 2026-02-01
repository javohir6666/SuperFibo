//+------------------------------------------------------------------+
//|                                                     Settings.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| SL Qo'yish rejimi                                                |
//+------------------------------------------------------------------+
enum ENUM_SL_MODE
{
   SL_MODE_DYNAMIC_FIBO,      // Fibo darajasi bo'yicha (masalan 1.3)
   SL_MODE_STATIC_OFFSET      // Sweep narxidan ma'lum masofada (Points)
};

struct TradeSettings
{
   bool     enableTrading;       // Savdo yoqilganmi
   double   lotSize;             // Lot hajmi
   int      slippage;            // Slippage
   int      magic;               // Magic raqam
   string   comment;             // Izoh
   
   // Risk Management
   bool     useBreakeven;        // Breakeven ishlatish
   bool     useMartingale;       // Martingale ishlatish
   
   // SL Sozlamalari
   ENUM_SL_MODE slMode;          // SL turi
   int      slOffsetPoints;      // Agar Static Offset bo'lsa, qancha masofa (points)
};

// RSI sozlamalari
struct RSISettings
{
   int      period;
   double   overbought;
   double   oversold;
};

// Pivot sozlamalari
struct PivotSettings
{
   int      leftBars;
   int      rightBars;
   bool     showPivots;
   bool     showSR;
   int      srLength;
};

// Fibonacci sozlamalari
struct FiboSettings
{
   int      lineBars;
   double   entry1Level;
   
   bool     showEntry2;
   double   entry2Level;
   color    entry2Color;
   
   bool     showEntry3;
   double   entry3Level;
   color    entry3Color;
   
   bool     showSL;
   double   slLevel;
   color    slColor;
   
   bool     showTP1;
   double   tp1Level;
   color    tp1Color;
   
   bool     showTP2;
   double   tp2Level;
   color    tp2Color;
};

// Chizish sozlamalari
struct DrawSettings
{
   int      labelSize;
};

// Pivot Data
struct PivotData
{
   double   price;
   int      barIndex;
   datetime time;
   bool     isValid;
};

// Fibonacci Level
struct FiboLevel
{
   double   price;
   string   name;
   color    lineColor;
   bool     show;
};

// Fibo Structure
struct FiboStructure
{
   bool           isActive;
   datetime       signalTime;
   int            signalBar;
   
   double         level0;        // Pivot
   double         level1;        // Sweep Point (Entry trigger)
   
   FiboLevel      entry1;
   FiboLevel      entry2;
   FiboLevel      entry3;
   FiboLevel      sl;
   FiboLevel      tp1;
   FiboLevel      tp2;
};

// Telegram Settings
struct TelegramSettings
{
   bool     enable;
   string   token;
   string   chatIDs;
};

// Label o'lchami
int GetLabelSize(int size)
{
   switch(size)
   {
      case 0:  return 6;
      case 1:  return 7;
      case 2:  return 8;
      case 3:  return 10;
      case 4:  return 12;
      default: return 7;
   }
}
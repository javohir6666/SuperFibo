//+------------------------------------------------------------------+
//|                                                     Settings.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Umumiy sozlamalar va strukturalar                                |
//+------------------------------------------------------------------+

struct DashboardState
{
   bool     isTradingAllowed;    // Savdo ruxsat etilganmi
   string   statusReason;        // Ruxsat yo'qligi sababi (News, Time, Risk)
   
   bool     hasActiveSignal;     // Signal bormi
   string   signalType;          // BUY yoki SELL
   int      currentEntry;        // Nechanchi entry (1, 2, 3)
   double   currentProfit;       // Joriy foyda
   string   lastAction;          // Oxirgi harakat (masalan: "TP1 Hit, Moved to BE")
   
   string   newsText;            // Yangiliklar ro'yxati
   string   logText;             // Loglar ro'yxati
};

// RSI sozlamalari
struct RSISettings
{
   int      period;              // RSI periodi
   double   overbought;          // Overbought darajasi
   double   oversold;            // Oversold darajasi
};

// Pivot sozlamalari
struct PivotSettings
{
   int      leftBars;            // Chap tarafdagi barlar soni
   int      rightBars;           // O'ng tarafdagi barlar soni
   bool     showPivots;          // Pivot nuqtalarni ko'rsatish
   bool     showSR;              // Support/Resistance chiziqlarni ko'rsatish
   int      srLength;            // S/R chiziq uzunligi (barlar)
};

// Fibonacci sozlamalari
struct FiboSettings
{
   int      lineBars;            // Fibo chiziq uzunligi (barlar)
   double   entry1Level;         // Entry 1 darajasi
   
   bool     showEntry2;          // Entry 2 ni ko'rsatish
   double   entry2Level;         // Entry 2 darajasi
   color    entry2Color;         // Entry 2 rangi
   
   bool     showEntry3;          // Entry 3 ni ko'rsatish
   double   entry3Level;         // Entry 3 darajasi
   color    entry3Color;         // Entry 3 rangi
   
   bool     showSL;              // SL ni ko'rsatish
   double   slLevel;             // SL darajasi (Fibo level)
   color    slColor;             // SL rangi
   
   bool     showTP1;             // TP1 ni ko'rsatish
   double   tp1Level;            // TP1 darajasi
   color    tp1Color;            // TP1 rangi
   
   bool     showTP2;             // TP2 ni ko'rsatish
   double   tp2Level;            // TP2 darajasi
   color    tp2Color;            // TP2 rangi
};

// Chizish sozlamalari
struct DrawSettings
{
   int      labelSize;           // Label o'lchami (0=Tiny, 1=Small, 2=Normal, 3=Large, 4=Huge)
   color    dashboardColor;      // Dashboard foni
};

// Pivot ma'lumotlari
struct PivotData
{
   double   price;               // Pivot narxi
   int      barIndex;            // Bar indeksi
   datetime time;                // Vaqt
   bool     isValid;             // Ma'lumot mavjudmi
};

// Fibonacci daraja ma'lumoti
struct FiboLevel
{
   double   price;               // Narx
   string   name;                // Nom (Entry 1, Entry 2, TP1, va h.k.)
   color    lineColor;           // Chiziq rangi
   bool     show;                // Ko'rsatish kerakmi
};

// Fibonacci struktura (BUY yoki SELL uchun)
struct FiboStructure
{
   bool           isActive;      // Faolmi
   datetime       signalTime;    // Signal vaqti
   int            signalBar;     // Signal bar indeksi
   
   double         level0;        // 0-daraja (Pivot)
   double         level1;        // 1-daraja (OS Low yoki OB High)
   
   FiboLevel      entry1;        // Entry 1
   FiboLevel      entry2;        // Entry 2
   FiboLevel      entry3;        // Entry 3
   FiboLevel      sl;            // Stop Loss
   FiboLevel      tp1;           // Take Profit 1
   FiboLevel      tp2;           // Take Profit 2
};

// Label o'lchamlarini olish
int GetLabelSize(int size)
{
   switch(size)
   {
      case 0:  return 6;   // Tiny
      case 1:  return 7;   // Small
      case 2:  return 8;   // Normal
      case 3:  return 10;  // Large
      case 4:  return 12;  // Huge
      default: return 7;   // Small
   }
}

// Telegram sozlamalari
struct TelegramSettings
{
   string   token;       // Bot Token
   string   chatID;      // Chat ID
   bool     enabled;     // Telegram xabarnomalarini yoqish
};

struct NewsSettings
{
   bool     enabled;             // Filtrn yoqish/o'chirish
   bool     closeOpenPositions;  // Yangilikdan oldin ochiq pozitsiyalarni yopish
   int      beforeMinutes;       // Yangilikdan necha daqiqa oldin to'xtash
   int      afterMinutes;        // Yangilikdan necha daqiqa keyin ishlash
   bool     includeHigh;         // Kuchli yangiliklar (3 ta buqa)
   bool     includeMedium;       // O'rta yangiliklar (2 ta buqa)
   bool     includeLow;          // Kuchsiz yangiliklar (1 ta buqa)
};

//+------------------------------------------------------------------+

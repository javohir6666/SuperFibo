//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+

#include "Settings.mqh"

//+------------------------------------------------------------------+
//| Trade sozlamalari                                                |
//+------------------------------------------------------------------+
enum ENUM_TRADE_MODE
{
   TRADE_MODE_FIBO_LEVELS,       // Fibonacci Levels
   TRADE_MODE_STATIC_POINTS      // Static Points
};

struct TradeSettings
{
   bool     enableTrading;       // Savdo yoqilganmi
   double   lotSize;             // Lot hajmi (har bir pozitsiya uchun)
   int      slippage;            // Slippage (nuqtalar)
   int      magic;               // Magic raqam
   string   comment;             // Buyurtma izohi
   
   ENUM_TRADE_MODE tradeMode;    // Savdo rejimi (Fibo yoki Points)
   bool     useBreakeven;        // Breakeven ishlatish
   bool     useMartingale;       // Martingale ishlatish
   
   // Static Points uchun (agar tradeMode = STATIC_POINTS)
   int      slPoints;            // Stop Loss (points)
   int      tp1Points;           // Take Profit 1 (points)
   int      tp2Points;           // Take Profit 2 (points)
};

//+------------------------------------------------------------------+
//| Trade pozitsiya ma'lumotlari                                     |
//+------------------------------------------------------------------+
struct PositionInfo
{
   ulong    ticket;              // Ticket raqami
   double   openPrice;           // Ochilgan narx
   double   tp;                  // Take Profit
   string   comment;             // Izoh
   bool     isTP1Position;       // TP1 pozitsiyami (breakeven uchun)
};

//+------------------------------------------------------------------+
//| Trade Manager klassi - Multi-Position bilan                     |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   TradeSettings     m_settings;         // Sozlamalar
   string            m_symbol;           // Symbol
   
   // Pozitsiyalar ro'yxati (breakeven tracking)
   PositionInfo      m_buyPositions[];
   PositionInfo      m_sellPositions[];
   
   // Martingale tracking
   int               m_currentBuyEntry;      // Hozirgi BUY entry darajasi (1, 2, 3)
   int               m_currentSellEntry;     // Hozirgi SELL entry darajasi
   double            m_buyPivotPrice;        // BUY martingale uchun pivot narx
   double            m_sellPivotPrice;       // SELL martingale uchun pivot narx
   
   // Signal ID tracking (har signal uchun unique)
   long              m_currentBuySignalID;   // Hozirgi BUY signal ID
   long              m_currentSellSignalID;  // Hozirgi SELL signal ID
   
public:
   // Konstruktor
   CTradeManager(void);
   ~CTradeManager(void);
   
   // Initsializatsiya
   bool Init(string symbol, TradeSettings &settings);
   void Deinit(void);
   
   // Savdo operatsiyalari - Fibonacci bilan
   bool ExecuteBuySetup(FiboStructure &fibo);
   bool ExecuteSellSetup(FiboStructure &fibo);
   
   // Martingale entry monitoring
   void CheckMartingaleEntry2Buy(FiboStructure &originalFibo);
   void CheckMartingaleEntry2Sell(FiboStructure &originalFibo);
   void CheckMartingaleEntry3Buy(FiboStructure &originalFibo);
   void CheckMartingaleEntry3Sell(FiboStructure &originalFibo);
   
   // Pozitsiyalarni boshqarish
   void ManagePositions(void);
   void CheckBreakeven(void);
   void CheckAndCloseSignalOrders(bool isBuy);  // Signal orderlari yopish
   
   // Ma'lumotlarni olish
   int GetOpenBuyPositionsCount(void);
   int GetOpenSellPositionsCount(void);
   bool HasOpenBuyPosition(void);
   bool HasOpenSellPosition(void);
   
private:
   // Yordamchi funksiyalar
   bool OpenPosition(ENUM_ORDER_TYPE type, double price, double sl, double tp, string comment, bool isTP1);
   bool OpenPositionWithCustomLot(ENUM_ORDER_TYPE type, double price, double sl, double tp, string comment, bool isTP1, double customLot);
   bool ModifyPosition(ulong ticket, double sl, double tp);
   double NormalizePrice(double price);
   double CalculateSL(ENUM_ORDER_TYPE type, double entryPrice, FiboStructure &fibo);
   double CalculateTP(ENUM_ORDER_TYPE type, double entryPrice, double fiboTP, int tpNumber);
   
   void UpdatePositionsList(void);
   bool IsPositionClosed(ulong ticket);
};

//+------------------------------------------------------------------+
//| Konstruktor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager(void)
{
   m_symbol = "";
   ArrayResize(m_buyPositions, 0);
   ArrayResize(m_sellPositions, 0);
   
   // Martingale initsializatsiya
   m_currentBuyEntry = 0;
   m_currentSellEntry = 0;
   m_buyPivotPrice = 0;
   m_sellPivotPrice = 0;
   
   // Signal ID initsializatsiya
   m_currentBuySignalID = 0;
   m_currentSellSignalID = 0;
}

//+------------------------------------------------------------------+
//| Destruktor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager(void)
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initsializatsiya                                                 |
//+------------------------------------------------------------------+
bool CTradeManager::Init(string symbol, TradeSettings &settings)
{
   m_symbol = symbol;
   m_settings = settings;
   
   if(!SymbolSelect(m_symbol, true))
   {
      Print("Symbol topilmadi: ", m_symbol);
      return false;
   }
   
   Print("Trade Manager: Lot=", m_settings.lotSize, " Magic=", m_settings.magic);
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitsializatsiya                                               |
//+------------------------------------------------------------------+
void CTradeManager::Deinit(void)
{
   ArrayResize(m_buyPositions, 0);
   ArrayResize(m_sellPositions, 0);
}

//+------------------------------------------------------------------+
//| BUY Setup - Faqat Entry1 (Martingale Entry2/3 ni CheckMartingale chaqiradi) |
//+------------------------------------------------------------------+
bool CTradeManager::ExecuteBuySetup(FiboStructure &fibo)
{
   if(!m_settings.enableTrading)
      return false;
   
   if(!fibo.isActive)
      return false;
   
   Print("═══════════════════════════════════════");
   Print(" Executing BUY Setup Entry1");
   Print(" Mode: ", m_settings.tradeMode == TRADE_MODE_FIBO_LEVELS ? "Fibo Levels" : "Static Points");
   Print(" Martingale: ", m_settings.useMartingale ? "ON" : "OFF");
   Print("═══════════════════════════════════════");
   
   // Yangi signal ID generatsiya qilish
   m_currentBuySignalID = TimeCurrent();
   Print("📊 Yangi BUY Signal ID: ", m_currentBuySignalID);
   
   bool success = true;
   int totalPositions = 0;
   
   // Lot hajmini aniqlash (martingale bo'lsa 1x, standart bo'lsa base lot)
   double currentLot = m_settings.lotSize;
   
   // ═════════ ENTRY 1 FAQAT ═════════
   double entry1Price = NormalizePrice(fibo.entry1.price);
   double slPrice = CalculateSL(ORDER_TYPE_BUY, entry1Price, fibo);
   
   if(fibo.tp1.show)
   {
      double tp1Price = CalculateTP(ORDER_TYPE_BUY, entry1Price, fibo.tp1.price, 1);
      
      // Comment formatiga signal ID qo'shish
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E1-TP1";
      
      if(OpenPosition(ORDER_TYPE_BUY, entry1Price, slPrice, tp1Price, comment, true))
      {
         totalPositions++;
         Print("✓ Entry1-TP1: Lot=", currentLot, " Entry=", entry1Price, " TP=", tp1Price);
      }
      else
      {
         success = false;
      }
   }
   
   if(fibo.tp2.show)
   {
      double tp2Price = CalculateTP(ORDER_TYPE_BUY, entry1Price, fibo.tp2.price, 2);
      
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E1-TP2";
      
      if(OpenPosition(ORDER_TYPE_BUY, entry1Price, slPrice, tp2Price, comment, false))
      {
         totalPositions++;
         Print("✓ Entry1-TP2: Lot=", currentLot, " Entry=", entry1Price, " TP=", tp2Price);
      }
      else
      {
         success = false;
      }
   }
   
   Print("═══════════════════════════════════════");
   Print(" Entry1: ", totalPositions, " ta pozitsiya ochildi");
   Print("═══════════════════════════════════════");
   
   // Martingale tracking
   if(success && totalPositions > 0)
   {
      m_currentBuyEntry = 1;
      m_buyPivotPrice = fibo.level0;  // Pivot High
      Print("📊 BUY Entry1 faollashtirildi. Pivot: ", m_buyPivotPrice);
   }
   
   // Pozitsiyalar ro'yxatini yangilash
   UpdatePositionsList();
   
   return success && totalPositions > 0;
}

//+------------------------------------------------------------------+
//| SELL Setup - Faqat Entry1 (Martingale Entry2/3 ni CheckMartingale chaqiradi) |
//+------------------------------------------------------------------+
bool CTradeManager::ExecuteSellSetup(FiboStructure &fibo)
{
   if(!m_settings.enableTrading)
      return false;
   
   if(!fibo.isActive)
      return false;
   
   // Signal ID yaratish
   m_currentSellSignalID = TimeCurrent();
   m_currentSellEntry = 1;  // Entry1 boshlanmoqda
   
   Print("═══════════════════════════════════════");
   Print(" Executing SELL Setup Entry1");
   Print(" Signal ID: ", m_currentSellSignalID);
   Print(" Mode: ", m_settings.tradeMode == TRADE_MODE_FIBO_LEVELS ? "Fibo Levels" : "Static Points");
   Print(" Martingale: ", m_settings.useMartingale ? "ON" : "OFF");
   Print("═══════════════════════════════════════");
   
   bool success = true;
   int totalPositions = 0;
   
   double currentLot = m_settings.lotSize;
   
   // ═════════ ENTRY 1 FAQAT ═════════
   double entry1Price = NormalizePrice(fibo.entry1.price);
   double slPrice = CalculateSL(ORDER_TYPE_SELL, entry1Price, fibo);
   
   if(fibo.tp1.show)
   {
      double tp1Price = CalculateTP(ORDER_TYPE_SELL, entry1Price, fibo.tp1.price, 1);
      
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E1-TP1";
      
      if(OpenPosition(ORDER_TYPE_SELL, entry1Price, slPrice, tp1Price, 
                      comment, true))
      {
         totalPositions++;
         Print("✓ Entry1-TP1: Lot=", currentLot, " Entry=", entry1Price, " TP=", tp1Price);
      }
      else
      {
         success = false;
      }
   }
   
   if(fibo.tp2.show)
   {
      double tp2Price = CalculateTP(ORDER_TYPE_SELL, entry1Price, fibo.tp2.price, 2);
      
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E1-TP2";
      
      if(OpenPosition(ORDER_TYPE_SELL, entry1Price, slPrice, tp2Price, 
                      comment, false))
      {
         totalPositions++;
         Print("✓ Entry1-TP2: Lot=", currentLot, " Entry=", entry1Price, " TP=", tp2Price);
      }
      else
      {
         success = false;
      }
   }
   
   Print("═══════════════════════════════════════");
   Print(" Entry1: ", totalPositions, " ta pozitsiya ochildi");
   Print("═══════════════════════════════════════");
   
   // Martingale tracking
   if(success && totalPositions > 0)
   {
      m_currentSellEntry = 1;
      m_sellPivotPrice = fibo.level0;  // Pivot Low
      Print("📊 SELL Entry1 faollashtirildi. Pivot: ", m_sellPivotPrice);
   }
   
   // Pozitsiyalar ro'yxatini yangilash
   UpdatePositionsList();
   
   return success && totalPositions > 0;
}

//+------------------------------------------------------------------+
//| Pozitsiyalarni boshqarish (breakeven tekshirish)                |
//+------------------------------------------------------------------+
void CTradeManager::ManagePositions(void)
{
   CheckBreakeven();
   
   // TP hit detection va signal orderlarini yopish
   CheckAndCloseSignalOrders(true);   // BUY
   CheckAndCloseSignalOrders(false);  // SELL
}

//+------------------------------------------------------------------+
//| Breakeven tekshirish - TP1 yopilsa, TP2 ni breakevenga o'tkazish |
//+------------------------------------------------------------------+
void CTradeManager::CheckBreakeven(void)
{
   // Breakeven o'chirilgan bo'lsa, tekshirmay chiqamiz
   if(!m_settings.useBreakeven)
      return;
   
   // BUY pozitsiyalar uchun
   int buyCount = ArraySize(m_buyPositions);
   for(int i = 0; i < buyCount; i++)
   {
      if(!m_buyPositions[i].isTP1Position)
         continue;  // Faqat TP1 pozitsiyalarni tekshiramiz
      
      // TP1 pozitsiya yopildimi?
      if(IsPositionClosed(m_buyPositions[i].ticket))
      {
         Print("✓ TP1 pozitsiya yopildi: #", m_buyPositions[i].ticket);
         Print("  Mos TP2 pozitsiyalarni breakevenga o'tkazish...");
         
         // Shu entry ning TP2 pozitsiyasini topish va breakevenga o'tkazish
         string baseComment = StringSubstr(m_buyPositions[i].comment, 0, 
                                          StringFind(m_buyPositions[i].comment, "-TP1"));
         
         for(int j = 0; j < buyCount; j++)
         {
            if(j == i || m_buyPositions[j].isTP1Position)
               continue;
            
            // Shu setup ga tegishlimi? (masalan: "SuperFibo BUY E1")
            if(StringFind(m_buyPositions[j].comment, baseComment) == 0)
            {
               // Hali ochiqmi?
               if(!IsPositionClosed(m_buyPositions[j].ticket))
               {
                  // Breakevenga o'tkazish (SL = open price)
                  double breakeven = m_buyPositions[j].openPrice;
                  
                  if(ModifyPosition(m_buyPositions[j].ticket, breakeven, 0))
                  {
                     Print("✓ Pozitsiya #", m_buyPositions[j].ticket, 
                           " breakevenga o'tkazildi: ", breakeven);
                  }
               }
            }
         }
         
         // Bu pozitsiyani ro'yxatdan o'chirish
         m_buyPositions[i].ticket = 0;
      }
   }
   
   // SELL pozitsiyalar uchun
   int sellCount = ArraySize(m_sellPositions);
   for(int i = 0; i < sellCount; i++)
   {
      if(!m_sellPositions[i].isTP1Position)
         continue;
      
      if(IsPositionClosed(m_sellPositions[i].ticket))
      {
         Print("✓ TP1 pozitsiya yopildi: #", m_sellPositions[i].ticket);
         Print("  Mos TP2 pozitsiyalarni breakevenga o'tkazish...");
         
         string baseComment = StringSubstr(m_sellPositions[i].comment, 0, 
                                          StringFind(m_sellPositions[i].comment, "-TP1"));
         
         for(int j = 0; j < sellCount; j++)
         {
            if(j == i || m_sellPositions[j].isTP1Position)
               continue;
            
            if(StringFind(m_sellPositions[j].comment, baseComment) == 0)
            {
               if(!IsPositionClosed(m_sellPositions[j].ticket))
               {
                  double breakeven = m_sellPositions[j].openPrice;
                  
                  if(ModifyPosition(m_sellPositions[j].ticket, breakeven, 0))
                  {
                     Print("✓ Pozitsiya #", m_sellPositions[j].ticket, 
                           " breakevenga o'tkazildi: ", breakeven);
                  }
               }
            }
         }
         
         m_sellPositions[i].ticket = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Signal bo'yicha orderlarni yopish (TP hit detection)           |
//+------------------------------------------------------------------+
void CTradeManager::CheckAndCloseSignalOrders(bool isBuy)
{
   if(isBuy)
   {
      // BUY signal uchun tekshirish
      if(m_currentBuySignalID == 0 || m_currentBuyEntry == 0)
         return;  // Signal aktiv emas
      
      // Barcha pozitsiyalarni tekshiramiz
      int total = PositionsTotal();
      bool anyOrderClosed = false;
      
      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         
         if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic)
            continue;
         
         string comment = PositionGetString(POSITION_COMMENT);
         
         // Signal ID ni tekshiramiz
         string searchPattern = "SF-BUY-" + IntegerToString(m_currentBuySignalID);
         if(StringFind(comment, searchPattern) == -1)
            continue;  // Bu boshqa signalga tegishli
         
         // Agar order yopilgan bo'lsa (TP hit)
         if(PositionGetDouble(POSITION_PROFIT) > 0)
         {
            anyOrderClosed = true;
            break;
         }
      }
      
      // Agar biror order TP hit qilgan bo'lsa, barcha signal orderlarini yopamiz
      if(anyOrderClosed)
      {
         Print("⚠ BUY Signal ", m_currentBuySignalID, " TP hit - barcha orderlarni yopish...");
         
         for(int i = total - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            
            if(PositionGetString(POSITION_SYMBOL) != m_symbol)
               continue;
            
            if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic)
               continue;
            
            string comment = PositionGetString(POSITION_COMMENT);
            string searchPattern = "SF-BUY-" + IntegerToString(m_currentBuySignalID);
            
            if(StringFind(comment, searchPattern) != -1)
            {
               MqlTradeRequest request;
               MqlTradeResult result;
               
               ZeroMemory(request);
               ZeroMemory(result);
               
               request.action = TRADE_ACTION_DEAL;
               request.position = ticket;
               request.symbol = m_symbol;
               request.volume = PositionGetDouble(POSITION_VOLUME);
               request.type = ORDER_TYPE_SELL;  // Close BUY = SELL
               request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
               request.deviation = m_settings.slippage;
               
               if(OrderSend(request, result))
               {
                  Print("✓ Signal order yopildi: #", ticket, " - ", comment);
               }
               else
               {
                  Print("✗ Order yopishda xatolik: #", ticket, " - ", GetLastError());
               }
            }
         }
         
         // State ni reset qilamiz
         m_currentBuyEntry = 0;
         m_currentBuySignalID = 0;
         Print("✓ BUY Signal state reset qilindi");
      }
   }
   else
   {
      // SELL signal uchun tekshirish
      if(m_currentSellSignalID == 0 || m_currentSellEntry == 0)
         return;
      
      int total = PositionsTotal();
      bool anyOrderClosed = false;
      
      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         
         if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic)
            continue;
         
         string comment = PositionGetString(POSITION_COMMENT);
         string searchPattern = "SF-SELL-" + IntegerToString(m_currentSellSignalID);
         
         if(StringFind(comment, searchPattern) == -1)
            continue;
         
         if(PositionGetDouble(POSITION_PROFIT) > 0)
         {
            anyOrderClosed = true;
            break;
         }
      }
      
      if(anyOrderClosed)
      {
         Print("⚠ SELL Signal ", m_currentSellSignalID, " TP hit - barcha orderlarni yopish...");
         
         for(int i = total - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            
            if(PositionGetString(POSITION_SYMBOL) != m_symbol)
               continue;
            
            if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic)
               continue;
            
            string comment = PositionGetString(POSITION_COMMENT);
            string searchPattern = "SF-SELL-" + IntegerToString(m_currentSellSignalID);
            
            if(StringFind(comment, searchPattern) != -1)
            {
               MqlTradeRequest request;
               MqlTradeResult result;
               
               ZeroMemory(request);
               ZeroMemory(result);
               
               request.action = TRADE_ACTION_DEAL;
               request.position = ticket;
               request.symbol = m_symbol;
               request.volume = PositionGetDouble(POSITION_VOLUME);
               request.type = ORDER_TYPE_BUY;  // Close SELL = BUY
               request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
               request.deviation = m_settings.slippage;
               
               if(OrderSend(request, result))
               {
                  Print("✓ Signal order yopildi: #", ticket, " - ", comment);
               }
               else
               {
                  Print("✗ Order yopishda xatolik: #", ticket, " - ", GetLastError());
               }
            }
         }
         
         m_currentSellEntry = 0;
         m_currentSellSignalID = 0;
         Print("✓ SELL Signal state reset qilindi");
      }
   }
}

//+------------------------------------------------------------------+
//| Pozitsiya ochish                                                 |
//+------------------------------------------------------------------+
bool CTradeManager::OpenPosition(ENUM_ORDER_TYPE type, double price, double sl, double tp, string comment, bool isTP1)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = m_symbol;
   request.volume = m_settings.lotSize;
   request.type = type;
   request.price = type == ORDER_TYPE_BUY ? 
                  SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(m_symbol, SYMBOL_BID);
   request.sl = sl;
   request.tp = tp;
   request.deviation = m_settings.slippage;
   request.magic = m_settings.magic;
   request.comment = comment;
   request.type_filling = ORDER_FILLING_IOC;
   
   if(!OrderSend(request, result))
   {
      request.type_filling = ORDER_FILLING_FOK;
      if(!OrderSend(request, result))
      {
         Print("Buyurtma yuborishda xato: ", GetLastError(), " Kod: ", result.retcode);
         return false;
      }
   }
   
   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
   {
      Print("✓ Pozitsiya ochildi: #", result.order, " ", comment, " TP=", tp);
      return true;
   }
   
   Print("✗ Pozitsiya rad etildi: ", result.retcode);
   return false;
}

//+------------------------------------------------------------------+
//| Pozitsiyani o'zgartirish (SL/TP)                                |
//+------------------------------------------------------------------+
bool CTradeManager::ModifyPosition(ulong ticket, double sl, double tp)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = m_symbol;
   request.sl = NormalizePrice(sl);
   request.tp = tp > 0 ? NormalizePrice(tp) : PositionGetDouble(POSITION_TP);
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
         return true;
   }
   
   Print("Pozitsiyani o'zgartirishda xato: #", ticket, " Kod: ", result.retcode);
   return false;
}

//+------------------------------------------------------------------+
//| Narxni normalizatsiya qilish                                     |
//+------------------------------------------------------------------+
double CTradeManager::NormalizePrice(double price)
{
   double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   return NormalizeDouble(MathRound(price / tickSize) * tickSize, _Digits);
}

//+------------------------------------------------------------------+
//| Stop Loss hisoblash (Fibo yoki Static Points)                   |
//+------------------------------------------------------------------+
double CTradeManager::CalculateSL(ENUM_ORDER_TYPE type, double entryPrice, FiboStructure &fibo)
{
   double slPrice = 0;
   
   if(m_settings.tradeMode == TRADE_MODE_FIBO_LEVELS)
   {
      // Fibonacci Levels rejimi
      if(fibo.sl.show)
      {
         slPrice = fibo.sl.price;
      }
      // Agar SL yo'q bo'lsa, 0 qaytaradi (SL o'rnatilmaydi)
   }
   else if(m_settings.tradeMode == TRADE_MODE_STATIC_POINTS)
   {
      // Static Points rejimi
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      if(type == ORDER_TYPE_BUY)
      {
         slPrice = entryPrice - m_settings.slPoints * point;
      }
      else // SELL
      {
         slPrice = entryPrice + m_settings.slPoints * point;
      }
   }
   
   return NormalizePrice(slPrice);
}

//+------------------------------------------------------------------+
//| Take Profit hisoblash (Fibo yoki Static Points)                 |
//+------------------------------------------------------------------+
double CTradeManager::CalculateTP(ENUM_ORDER_TYPE type, double entryPrice, double fiboTP, int tpNumber)
{
   double tpPrice = 0;
   
   if(m_settings.tradeMode == TRADE_MODE_FIBO_LEVELS)
   {
      // Fibonacci Levels rejimi - fiboTP dan foydalanish
      tpPrice = fiboTP;
   }
   else if(m_settings.tradeMode == TRADE_MODE_STATIC_POINTS)
   {
      // Static Points rejimi
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int tpPoints = (tpNumber == 1) ? m_settings.tp1Points : m_settings.tp2Points;
      
      if(type == ORDER_TYPE_BUY)
      {
         tpPrice = entryPrice + tpPoints * point;
      }
      else // SELL
      {
         tpPrice = entryPrice - tpPoints * point;
      }
   }
   
   return NormalizePrice(tpPrice);
}

//+------------------------------------------------------------------+
//| Pozitsiyalar ro'yxatini yangilash                               |
//+------------------------------------------------------------------+
void CTradeManager::UpdatePositionsList(void)
{
   ArrayResize(m_buyPositions, 0);
   ArrayResize(m_sellPositions, 0);
   
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
   {
      if(PositionGetSymbol(i) == m_symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == m_settings.magic)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double tp = PositionGetDouble(POSITION_TP);
            string comment = PositionGetString(POSITION_COMMENT);
            long posType = PositionGetInteger(POSITION_TYPE);
            
            bool isTP1 = StringFind(comment, "-TP1") >= 0;
            
            PositionInfo info;
            info.ticket = ticket;
            info.openPrice = openPrice;
            info.tp = tp;
            info.comment = comment;
            info.isTP1Position = isTP1;
            
            if(posType == POSITION_TYPE_BUY)
            {
               int size = ArraySize(m_buyPositions);
               ArrayResize(m_buyPositions, size + 1);
               m_buyPositions[size] = info;
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               int size = ArraySize(m_sellPositions);
               ArrayResize(m_sellPositions, size + 1);
               m_sellPositions[size] = info;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Pozitsiya yopildimi?                                             |
//+------------------------------------------------------------------+
bool CTradeManager::IsPositionClosed(ulong ticket)
{
   return !PositionSelectByTicket(ticket);
}

//+------------------------------------------------------------------+
//| Ochiq BUY pozitsiyalar soni                                      |
//+------------------------------------------------------------------+
int CTradeManager::GetOpenBuyPositionsCount(void)
{
   int count = 0;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
   {
      if(PositionGetSymbol(i) == m_symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == m_settings.magic)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Ochiq SELL pozitsiyalar soni                                     |
//+------------------------------------------------------------------+
int CTradeManager::GetOpenSellPositionsCount(void)
{
   int count = 0;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
   {
      if(PositionGetSymbol(i) == m_symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == m_settings.magic)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| BUY pozitsiya borligini tekshirish                               |
//+------------------------------------------------------------------+
bool CTradeManager::HasOpenBuyPosition(void)
{
   return GetOpenBuyPositionsCount() > 0;
}

//+------------------------------------------------------------------+
//| SELL pozitsiya borligini tekshirish                              |
//+------------------------------------------------------------------+
bool CTradeManager::HasOpenSellPosition(void)
{
   return GetOpenSellPositionsCount() > 0;
}

//+------------------------------------------------------------------+
//| Martingale Entry2 BUY - Narx Entry2 ga kelganini tekshirish     |
//+------------------------------------------------------------------+
void CTradeManager::CheckMartingaleEntry2Buy(FiboStructure &originalFibo)
{
   // Martingale o'chirilgan yoki Entry2 ko'rsatilmagan
   if(!m_settings.useMartingale || !originalFibo.entry2.show)
      return;
   
   // Hali Entry1 davom etayotganmi? (State = 1 bo'lishi kerak)
   if(m_currentBuyEntry != 1)
      return;
   
   // Entry1 orderlar hali ochiq ekanligini tekshirish
   bool hasEntry1Orders = false;
   int total = PositionsTotal();
   string searchComment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E1";
   
   for(int i = 0; i < total; i++)
   {
      if(PositionGetSymbol(i) == m_symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == m_settings.magic)
         {
            string comment = PositionGetString(POSITION_COMMENT);
            if(StringFind(comment, searchComment) >= 0)
            {
               hasEntry1Orders = true;
               break;
            }
         }
      }
   }
   
   // Agar Entry1 orderlar yo'q bo'lsa, state ni reset qilish
   if(!hasEntry1Orders)
   {
      Print("⚠️ Entry1 orderlar yopildi. BUY signal tugadi.");
      m_currentBuyEntry = 0;
      m_currentBuySignalID = 0;
      return;
   }
   
   // Narx Entry2 ga yetdimi?
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(currentPrice > originalFibo.entry2.price)
      return;  // Hali yetmagan
   
   Print("═══════════════════════════════════════");
   Print(" 🔥 MARTINGALE Entry2 BUY triggered!");
   Print(" Price: ", currentPrice, " <= Entry2: ", originalFibo.entry2.price);
   Print("═══════════════════════════════════════");
   
   // Yangi Fibonacci hisoblash
   // Level 0 = Entry1 ning pivot (m_buyPivotPrice)
   // Level 1 = Entry2 price
   double level0 = m_buyPivotPrice;
   double level1 = originalFibo.entry2.price;
   double range = level0 - level1;
   
   if(range <= 0)
   {
      Print("❌ Martingale E2: Noto'g'ri diapazon");
      return;
   }
   
   // TP level qiymatlarini originalFibo dan olish
   // originalFibo.tp1.price va tp2.price dan level ni teskari hisoblash
   double origRange = level0 - originalFibo.entry1.price;
   double tp1Level = 0.5;  // Default
   double tp2Level = 0.0;  // Default
   
   if(origRange > 0)
   {
      tp1Level = (level0 - originalFibo.tp1.price) / origRange;
      tp2Level = (level0 - originalFibo.tp2.price) / origRange;
   }
   
   // TP1 va TP2 hisoblash (yangi Fibonacci dan)
   double tp1Price = level0 - range * tp1Level;
   double tp2Price = level0 - range * tp2Level;
   
   // 2x lot
   double martingaleLot = m_settings.lotSize * 2.0;
   
   Print("📊 Martingale E2: Pivot=", level0, " Entry2=", level1);
   Print("   TP1=", tp1Price, " TP2=", tp2Price, " Lot=", martingaleLot);
   
   // SL hisoblash
   double slPrice = 0;
   if(originalFibo.sl.show)
   {
      double slLevel = 0;
      if(origRange > 0)
      {
         slLevel = (level0 - originalFibo.sl.price) / origRange;
      }
      slPrice = level0 - range * slLevel;
   }
   
   // Pozitsiyalar ochish (2x lot bilan)
   bool success = true;
   
   if(originalFibo.tp1.show)
   {
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E2-TP1-M";
      
      if(OpenPositionWithCustomLot(ORDER_TYPE_BUY, level1, slPrice, tp1Price, 
                                    comment, true, martingaleLot))
      {
         Print("✓ Martingale E2-TP1: Lot=", martingaleLot);
      }
      else
         success = false;
   }
   
   if(originalFibo.tp2.show)
   {
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E2-TP2-M";
      
      if(OpenPositionWithCustomLot(ORDER_TYPE_BUY, level1, slPrice, tp2Price, 
                                    comment, false, martingaleLot))
      {
         Print("✓ Martingale E2-TP2: Lot=", martingaleLot);
      }
      else
         success = false;
   }
   
   if(success)
   {
      m_currentBuyEntry = 2;
      m_buyPivotPrice = level1;  // Entry2 yangi pivot bo'ladi
      Print("📊 BUY Entry2 faollashtirildi. Yangi Pivot: ", m_buyPivotPrice);
   }
   
   UpdatePositionsList();
}

//+------------------------------------------------------------------+
//| Martingale Entry3 BUY                                            |
//+------------------------------------------------------------------+
void CTradeManager::CheckMartingaleEntry3Buy(FiboStructure &originalFibo)
{
   if(!m_settings.useMartingale || !originalFibo.entry3.show)
      return;
   
   if(m_currentBuyEntry != 2)
      return;
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(currentPrice > originalFibo.entry3.price)
      return;
   
   Print("═══════════════════════════════════════");
   Print(" 🔥 MARTINGALE Entry3 BUY triggered!");
   Print("═══════════════════════════════════════");
   
   double level0 = m_buyPivotPrice;  // Entry2
   double level1 = originalFibo.entry3.price;
   double range = level0 - level1;
   
   if(range <= 0)
   {
      Print("❌ Martingale E3: Noto'g'ri diapazon");
      return;
   }
   
   // TP level qiymatlarini originalFibo dan olish
   double origRange = m_buyPivotPrice - originalFibo.entry1.price;
   double tp1Level = 0.5;
   double tp2Level = 0.0;
   
   if(origRange > 0)
   {
      tp1Level = (m_buyPivotPrice - originalFibo.tp1.price) / origRange;
      tp2Level = (m_buyPivotPrice - originalFibo.tp2.price) / origRange;
   }
   
   double tp1Price = level0 - range * tp1Level;
   double tp2Price = level0 - range * tp2Level;
   
   // 4x lot (2x * 2)
   double martingaleLot = m_settings.lotSize * 4.0;
   
   Print("📊 Martingale E3: Pivot=", level0, " Entry3=", level1);
   Print("   TP1=", tp1Price, " TP2=", tp2Price, " Lot=", martingaleLot);
   
   double slPrice = 0;
   if(originalFibo.sl.show)
   {
      double slLevel = 0;
      if(origRange > 0)
      {
         slLevel = (m_buyPivotPrice - originalFibo.sl.price) / origRange;
      }
      slPrice = level0 - range * slLevel;
   }
   
   bool success = true;
   
   if(originalFibo.tp1.show)
   {
      if(OpenPositionWithCustomLot(ORDER_TYPE_BUY, level1, slPrice, tp1Price, 
                                    "SuperFibo BUY E3-TP1 [M]", true, martingaleLot))
      {
         Print("✓ Martingale E3-TP1: Lot=", martingaleLot);
      }
      else
         success = false;
   }
   
   if(originalFibo.tp2.show)
   {
      if(OpenPositionWithCustomLot(ORDER_TYPE_BUY, level1, slPrice, tp2Price, 
                                    "SuperFibo BUY E3-TP2 [M]", false, martingaleLot))
      {
         Print("✓ Martingale E3-TP2: Lot=", martingaleLot);
      }
      else
         success = false;
   }
   
   if(success)
   {
      m_currentBuyEntry = 3;
      Print("📊 BUY Entry3 faollashtirildi (oxirgi daraja)");
   }
   
   UpdatePositionsList();
}

//+------------------------------------------------------------------+
//| Martingale Entry2 SELL                                           |
//+------------------------------------------------------------------+
void CTradeManager::CheckMartingaleEntry2Sell(FiboStructure &originalFibo)
{
   if(!m_settings.useMartingale || !originalFibo.entry2.show)
      return;
   
   if(m_currentSellEntry != 1 || m_currentSellSignalID == 0)
      return;
   
   // Entry1 hali ochiq ekanligini tekshirish
   bool hasEntry1Orders = false;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != m_symbol)
         continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic)
         continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      string searchPattern = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E1";
      
      if(StringFind(comment, searchPattern) != -1)
      {
         hasEntry1Orders = true;
         break;
      }
   }
   
   // Agar Entry1 yopilgan bo'lsa, state ni reset qilish
   if(!hasEntry1Orders)
   {
      Print("⚠ SELL Entry1 yopilgan - state reset");
      m_currentSellEntry = 0;
      m_currentSellSignalID = 0;
      return;
   }
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   if(currentPrice < originalFibo.entry2.price)
      return;
   
   Print("═══════════════════════════════════════");
   Print(" 🔥 MARTINGALE Entry2 SELL triggered!");
   Print(" Signal ID: ", m_currentSellSignalID);
   Print("═══════════════════════════════════════");
   
   double level0 = m_sellPivotPrice;  // Pivot Low
   double level1 = originalFibo.entry2.price;
   double range = level1 - level0;
   
   if(range <= 0)
   {
      Print("❌ Martingale E2: Noto'g'ri diapazon");
      return;
   }
   
   // TP level qiymatlarini originalFibo dan olish
   double origRange = originalFibo.entry1.price - level0;
   double tp1Level = 0.5;
   double tp2Level = 0.0;
   
   if(origRange > 0)
   {
      tp1Level = (originalFibo.tp1.price - level0) / origRange;
      tp2Level = (originalFibo.tp2.price - level0) / origRange;
   }
   
   double tp1Price = level0 + range * tp1Level;
   double tp2Price = level0 + range * tp2Level;
   double martingaleLot = m_settings.lotSize * 2.0;
   
   Print("📊 Martingale E2: Pivot=", level0, " Entry2=", level1);
   Print("   TP1=", tp1Price, " TP2=", tp2Price, " Lot=", martingaleLot);
   
   double slPrice = 0;
   if(originalFibo.sl.show)
   {
      double slLevel = 0;
      if(origRange > 0)
      {
         slLevel = (originalFibo.sl.price - level0) / origRange;
      }
      slPrice = level0 + range * slLevel;
   }
   
   bool success = true;
   
   if(originalFibo.tp1.show)
   {
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E2-TP1-M";
      
      if(OpenPositionWithCustomLot(ORDER_TYPE_SELL, level1, slPrice, tp1Price, 
                                    comment, true, martingaleLot))
      {
         Print("✓ Martingale E2-TP1: Lot=", martingaleLot);
      }
      else
         success = false;
   }
   
   if(originalFibo.tp2.show)
   {
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E2-TP2-M";
      
      if(OpenPositionWithCustomLot(ORDER_TYPE_SELL, level1, slPrice, tp2Price, 
                                    comment, false, martingaleLot))
      {
         Print("✓ Martingale E2-TP2: Lot=", martingaleLot);
      }
      else
         success = false;
   }
   
   if(success)
   {
      m_currentSellEntry = 2;
      m_sellPivotPrice = level1;
      Print("📊 SELL Entry2 faollashtirildi. Yangi Pivot: ", m_sellPivotPrice);
   }
   
   UpdatePositionsList();
}

//+------------------------------------------------------------------+
//| Martingale Entry3 SELL                                           |
//+------------------------------------------------------------------+
void CTradeManager::CheckMartingaleEntry3Sell(FiboStructure &originalFibo)
{
   if(!m_settings.useMartingale || !originalFibo.entry3.show)
      return;
   
   if(m_currentSellEntry != 2 || m_currentSellSignalID == 0)
      return;
   
   // Entry2 hali ochiq ekanligini tekshirish
   bool hasEntry2Orders = false;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != m_symbol)
         continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic)
         continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      string searchPattern = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E2";
      
      if(StringFind(comment, searchPattern) != -1)
      {
         hasEntry2Orders = true;
         break;
      }
   }
   
   if(!hasEntry2Orders)
   {
      Print("⚠ SELL Entry2 yopilgan - Entry3 bekor qilindi");
      return;
   }
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   if(currentPrice < originalFibo.entry3.price)
      return;
   
   Print("═══════════════════════════════════════");
   Print(" 🔥 MARTINGALE Entry3 SELL triggered!");
   Print(" Signal ID: ", m_currentSellSignalID);
   Print("═══════════════════════════════════════");
   
   double level0 = m_sellPivotPrice;
   double level1 = originalFibo.entry3.price;
   double range = level1 - level0;
   
   if(range <= 0)
   {
      Print("❌ Martingale E3: Noto'g'ri diapazon");
      return;
   }
   
   // TP level qiymatlarini originalFibo dan olish
   double origRange = originalFibo.entry1.price - m_sellPivotPrice;
   double tp1Level = 0.5;
   double tp2Level = 0.0;
   
   if(origRange > 0)
   {
      tp1Level = (originalFibo.tp1.price - m_sellPivotPrice) / origRange;
      tp2Level = (originalFibo.tp2.price - m_sellPivotPrice) / origRange;
   }
   
   double tp1Price = level0 + range * tp1Level;
   double tp2Price = level0 + range * tp2Level;
   double martingaleLot = m_settings.lotSize * 4.0;
   
   Print("📊 Martingale E3: Pivot=", level0, " Entry3=", level1);
   Print("   TP1=", tp1Price, " TP2=", tp2Price, " Lot=", martingaleLot);
   
   double slPrice = 0;
   if(originalFibo.sl.show)
   {
      double slLevel = 0;
      if(origRange > 0)
      {
         slLevel = (originalFibo.sl.price - m_sellPivotPrice) / origRange;
      }
      slPrice = level0 + range * slLevel;
   }
   
   bool success = true;
   
   if(originalFibo.tp1.show)
   {
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E3-TP1-M";
      
      if(OpenPositionWithCustomLot(ORDER_TYPE_SELL, level1, slPrice, tp1Price, 
                                    comment, true, martingaleLot))
      {
         Print("✓ Martingale E3-TP1: Lot=", martingaleLot);
      }
      else
         success = false;
   }
   
   if(originalFibo.tp2.show)
   {
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E3-TP2-M";
      
      if(OpenPositionWithCustomLot(ORDER_TYPE_SELL, level1, slPrice, tp2Price, 
                                    comment, false, martingaleLot))
      {
         Print("✓ Martingale E3-TP2: Lot=", martingaleLot);
      }
      else
         success = false;
   }
   
   if(success)
   {
      m_currentSellEntry = 3;
      Print("📊 SELL Entry3 faollashtirildi (oxirgi daraja)");
   }
   
   UpdatePositionsList();
}

//+------------------------------------------------------------------+
//| Custom lot bilan pozitsiya ochish                                |
//+------------------------------------------------------------------+
bool CTradeManager::OpenPositionWithCustomLot(ENUM_ORDER_TYPE type, double price, 
                                               double sl, double tp, string comment, 
                                               bool isTP1, double customLot)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = m_symbol;
   request.volume = customLot;
   request.type = type;
   request.price = type == ORDER_TYPE_BUY ? 
                  SymbolInfoDouble(m_symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(m_symbol, SYMBOL_BID);
   request.sl = sl;
   request.tp = tp;
   request.deviation = m_settings.slippage;
   request.magic = m_settings.magic;
   request.comment = comment;
   request.type_filling = ORDER_FILLING_IOC;
   
   if(!OrderSend(request, result))
   {
      request.type_filling = ORDER_FILLING_FOK;
      if(!OrderSend(request, result))
      {
         Print("Martingale buyurtma xatosi: ", GetLastError());
         return false;
      }
   }
   
   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+

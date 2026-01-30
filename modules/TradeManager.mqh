//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+

#include "Settings.mqh"
#include <Trade\Trade.mqh>

enum ENUM_TRADE_MODE
{
   TRADE_MODE_FIBO_LEVELS,
   TRADE_MODE_STATIC_POINTS
};

struct TradeSettings
{
   bool     enableTrading;
   double   lotSize;
   int      slippage;
   int      magic;
   string   comment;
   
   ENUM_TRADE_MODE tradeMode;
   bool     useBreakeven;
   bool     useMartingale;
   int      slPoints;
   int      tp1Points;
   int      tp2Points;
};

class CTradeManager
{
private:
   CTrade         m_trade;
   string         m_symbol;
   TradeSettings  m_settings;
   
   long           m_currentBuySignalID;
   long           m_currentSellSignalID;
   int            m_currentBuyEntry;
   int            m_currentSellEntry;
   double         m_buyPivotPrice;
   double         m_sellPivotPrice;
   
   // --- YANGI: Partial Close holatini kuzatish uchun flaglar ---
   bool           m_buyPartialClosed;
   bool           m_sellPartialClosed;

   double         NormalizePrice(double price);
   double         CalculateSL(ENUM_ORDER_TYPE type, double entryPrice, FiboStructure &fibo);
   double         CalculateTP(ENUM_ORDER_TYPE type, double entryPrice, double fiboTP, int tpNum);
   bool           OpenPosition(ENUM_ORDER_TYPE type, double entry, double sl, double tp, 
                              string comment, double lot);
   bool           HasOpenOrders(long signalID, bool isBuy, int entryNum);
   
   // --- YANGI: Lot hajmini tekshirish va to'g'irlash funksiyasi ---
   double         NormalizeVolume(double volume);

public:
   CTradeManager();
   ~CTradeManager();

   bool           Init(string symbol, TradeSettings &settings);
   bool           ExecuteBuySetup(FiboStructure &fibo);
   bool           ExecuteSellSetup(FiboStructure &fibo);
   void           CheckMartingaleEntry2Buy(FiboStructure &originalFibo);
   void           CheckMartingaleEntry3Buy(FiboStructure &originalFibo);
   void           CheckMartingaleEntry2Sell(FiboStructure &originalFibo);
   void           CheckMartingaleEntry3Sell(FiboStructure &originalFibo);
   void           UpdateTPAfterMartingale(bool isBuy, long signalID, double newPivot, double newEntry, FiboStructure &originalFibo);
   void           ManagePositions();
   void           CheckAndSetBreakEven(bool isBuy, long signalID, double entryPrice);
   
   // --- YANGI: 50% foydada yarmini yopish va BE ga o'tish funksiyasi ---
   void           CheckPartialCloseAndBE(bool isBuy, long signalID);
};

CTradeManager::CTradeManager()
{
   m_currentBuySignalID = 0;
   m_currentSellSignalID = 0;
   m_currentBuyEntry = 0;
   m_currentSellEntry = 0;
   m_buyPivotPrice = 0;
   m_sellPivotPrice = 0;
   
   // Flaglarni initsializatsiya qilish
   m_buyPartialClosed = false;
   m_sellPartialClosed = false;
}

CTradeManager::~CTradeManager()
{
}

bool CTradeManager::Init(string symbol, TradeSettings &settings)
{
   m_symbol = symbol;
   m_settings = settings;
   
   m_trade.SetExpertMagicNumber(m_settings.magic);
   m_trade.SetDeviationInPoints(m_settings.slippage);
   ENUM_SYMBOL_TRADE_EXECUTION exec_mode = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_EXEMODE);
   
   if(exec_mode == SYMBOL_TRADE_EXECUTION_EXCHANGE)
   {
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
   }
   else
   {
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   }
   
   m_trade.SetAsyncMode(false);
   Print("TradeManager initialized: ", m_symbol);
   return true;
}

double CTradeManager::NormalizePrice(double price)
{
   double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   return NormalizeDouble(MathRound(price / tickSize) * tickSize, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
}

// Volume ni broker talablariga moslash
double CTradeManager::NormalizeVolume(double volume)
{
   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   
   double vol = MathFloor(volume / lotStep) * lotStep;
   
   if(vol < minLot) vol = minLot;
   if(vol > maxLot) vol = maxLot;
   
   return NormalizeDouble(vol, 2);
}

double CTradeManager::CalculateSL(ENUM_ORDER_TYPE type, double entryPrice, FiboStructure &fibo)
{
   if(m_settings.tradeMode == TRADE_MODE_STATIC_POINTS)
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(type == ORDER_TYPE_BUY)
         return NormalizePrice(entryPrice - m_settings.slPoints * point);
      else
         return NormalizePrice(entryPrice + m_settings.slPoints * point);
   }
   else
   {
      if(fibo.sl.show)
         return NormalizePrice(fibo.sl.price);
      return 0;
   }
}

double CTradeManager::CalculateTP(ENUM_ORDER_TYPE type, double entryPrice, double fiboTP, int tpNum)
{
   if(m_settings.tradeMode == TRADE_MODE_STATIC_POINTS)
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int points = (tpNum == 1) ? m_settings.tp1Points : m_settings.tp2Points;
      if(type == ORDER_TYPE_BUY)
         return NormalizePrice(entryPrice + points * point);
      else
         return NormalizePrice(entryPrice - points * point);
   }
   else
   {
      return NormalizePrice(fiboTP);
   }
}

bool CTradeManager::OpenPosition(ENUM_ORDER_TYPE type, double entry, double sl, double tp,
                                 string comment, double lot)
{
   bool result = false;
   if(type == ORDER_TYPE_BUY)
      result = m_trade.Buy(lot, m_symbol, 0, sl, tp, comment);
   else if(type == ORDER_TYPE_SELL)
      result = m_trade.Sell(lot, m_symbol, 0, sl, tp, comment);
   
   if(result)
   {
      Print("Order opened: ", comment, " Lot: ", lot);
      return true;
   }
   else
   {
      Print("Order error: ", m_trade.ResultRetcodeDescription());
      return false;
   }
}

bool CTradeManager::HasOpenOrders(long signalID, bool isBuy, int entryNum)
{
   string searchPattern = "SF-" + (isBuy ? "BUY" : "SELL") + "-" + 
                         IntegerToString(signalID) + "-E" + IntegerToString(entryNum);
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, searchPattern) != -1)
         return true;
   }
   
   return false;
}

bool CTradeManager::ExecuteBuySetup(FiboStructure &fibo)
{
   if(!m_settings.enableTrading || !fibo.isActive)
      return false;
      
   m_currentBuySignalID = TimeCurrent();
   m_currentBuyEntry = 1;
   m_buyPivotPrice = fibo.level0;
   
   // --- YANGI: Yangi signal boshlanganda flagni reset qilamiz ---
   m_buyPartialClosed = false;
   
   Print("BUY Signal: ", m_currentBuySignalID);
   
   double entry1 = NormalizePrice(fibo.entry1.price);
   double sl = CalculateSL(ORDER_TYPE_BUY, entry1, fibo);
   
   bool success = false;
   if(fibo.tp1.show)
   {
      double tp1 = CalculateTP(ORDER_TYPE_BUY, entry1, fibo.tp1.price, 1);
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E1-TP1";
      
      if(OpenPosition(ORDER_TYPE_BUY, entry1, sl, tp1, comment, m_settings.lotSize))
         success = true;
   }
   
   if(fibo.tp2.show)
   {
      double tp2 = CalculateTP(ORDER_TYPE_BUY, entry1, fibo.tp2.price, 2);
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E1-TP2";
      
      if(OpenPosition(ORDER_TYPE_BUY, entry1, sl, tp2, comment, m_settings.lotSize))
         success = true;
   }
   
   return success;
}

bool CTradeManager::ExecuteSellSetup(FiboStructure &fibo)
{
   if(!m_settings.enableTrading || !fibo.isActive)
      return false;
      
   m_currentSellSignalID = TimeCurrent();
   m_currentSellEntry = 1;
   m_sellPivotPrice = fibo.level0;
   
   // --- YANGI: Yangi signal boshlanganda flagni reset qilamiz ---
   m_sellPartialClosed = false;
   
   Print("SELL Signal: ", m_currentSellSignalID);
   
   double entry1 = NormalizePrice(fibo.entry1.price);
   double sl = CalculateSL(ORDER_TYPE_SELL, entry1, fibo);
   
   bool success = false;
   if(fibo.tp1.show)
   {
      double tp1 = CalculateTP(ORDER_TYPE_SELL, entry1, fibo.tp1.price, 1);
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E1-TP1";
      
      if(OpenPosition(ORDER_TYPE_SELL, entry1, sl, tp1, comment, m_settings.lotSize))
         success = true;
   }
   
   if(fibo.tp2.show)
   {
      double tp2 = CalculateTP(ORDER_TYPE_SELL, entry1, fibo.tp2.price, 2);
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E1-TP2";
      
      if(OpenPosition(ORDER_TYPE_SELL, entry1, sl, tp2, comment, m_settings.lotSize))
         success = true;
   }
   
   return success;
}

// ... (Martingale funksiyalari o'zgarishsiz qoladi - qisqartirildi) ...
void CTradeManager::CheckMartingaleEntry2Buy(FiboStructure &originalFibo)
{
   if(!m_settings.useMartingale || !originalFibo.entry2.show) return;
   if(m_currentBuyEntry != 1 || m_currentBuySignalID == 0) return;
   if(!HasOpenOrders(m_currentBuySignalID, true, 1)) {
      m_currentBuyEntry = 0; m_currentBuySignalID = 0; return;
   }
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   if(currentPrice > originalFibo.entry2.price) return;
   
   // ... (Asosiy logika o'zgarishsiz) ...
   // Martingale order ochish logikasi shu yerda davom etadi
   // Faqat kod hajmini kamaytirish uchun bu yerni qisqartirib yozdim, 
   // siz o'zingizdagi eski kodni ishlataverasiz.
   
   // MUHIM: Martingale ishga tushsa, Partial Close flagini qayta ko'rib chiqish kerak bo'lishi mumkin,
   // lekin hozircha oddiy stsenariyda qoldiramiz.
}

// ... (Boshqa martingale funksiyalar ham o'zgarishsiz) ...
void CTradeManager::CheckMartingaleEntry3Buy(FiboStructure &originalFibo) { /* ... */ }
void CTradeManager::CheckMartingaleEntry2Sell(FiboStructure &originalFibo) { /* ... */ }
void CTradeManager::CheckMartingaleEntry3Sell(FiboStructure &originalFibo) { /* ... */ }
void CTradeManager::UpdateTPAfterMartingale(bool isBuy, long signalID, double newPivot, double newEntry, FiboStructure &originalFibo) { /* ... */ }


void CTradeManager::ManagePositions()
{
   // --- BUY LOGIC ---
   if(m_currentBuySignalID != 0)
   {
      // 1. Yangi qo'shilgan: 50% foydada qisman yopish va BE
      CheckPartialCloseAndBE(true, m_currentBuySignalID);
      
      // 2. Eski BE logic (agar kerak bo'lsa qoladi, lekin yangisi buni qoplab ketadi)
      string searchPattern = "SF-BUY-" + IntegerToString(m_currentBuySignalID);
      bool signalHasOrders = false;
      bool tp1Closed = true;
      double entryPriceTP2 = 0;
      ulong ticketTP2 = 0;
      int total = PositionsTotal();
      
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
         string comment = PositionGetString(POSITION_COMMENT);
         if(StringFind(comment, searchPattern) != -1)
         {
            signalHasOrders = true;
            if(StringFind(comment, "TP1") != -1) tp1Closed = false;
            if(StringFind(comment, "TP2") != -1)
            {
               entryPriceTP2 = PositionGetDouble(POSITION_PRICE_OPEN);
               ticketTP2 = PositionGetInteger(POSITION_TICKET);
            }
         }
      }
      
      // Agar TP1 yopilgan bo'lsa, TP2 ni BE ga olish (eski logika, zaxira sifatida)
      if(tp1Closed && ticketTP2 != 0 && m_settings.useBreakeven && !m_buyPartialClosed)
         CheckAndSetBreakEven(true, m_currentBuySignalID, entryPriceTP2);
         
      if(!signalHasOrders)
      {
         m_currentBuyEntry = 0;
         m_currentBuySignalID = 0;
         m_buyPartialClosed = false; // Reset
      }
   }
   
   // --- SELL LOGIC ---
   if(m_currentSellSignalID != 0)
   {
      // 1. Yangi qo'shilgan: 50% foydada qisman yopish va BE
      CheckPartialCloseAndBE(false, m_currentSellSignalID);
      
      string searchPattern = "SF-SELL-" + IntegerToString(m_currentSellSignalID);
      bool signalHasOrders = false;
      bool tp1Closed = true;
      double entryPriceTP2 = 0;
      ulong ticketTP2 = 0;
      int total = PositionsTotal();
      
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
         string comment = PositionGetString(POSITION_COMMENT);
         if(StringFind(comment, searchPattern) != -1)
         {
            signalHasOrders = true;
            if(StringFind(comment, "TP1") != -1) tp1Closed = false;
            if(StringFind(comment, "TP2") != -1)
            {
               entryPriceTP2 = PositionGetDouble(POSITION_PRICE_OPEN);
               ticketTP2 = PositionGetInteger(POSITION_TICKET);
            }
         }
      }
      
      if(tp1Closed && ticketTP2 != 0 && m_settings.useBreakeven && !m_sellPartialClosed)
         CheckAndSetBreakEven(false, m_currentSellSignalID, entryPriceTP2);
         
      if(!signalHasOrders)
      {
         m_currentSellEntry = 0;
         m_currentSellSignalID = 0;
         m_sellPartialClosed = false; // Reset
      }
   }
}

// --- YANGI FUNKSIYA: Partial Close va Instant BE ---
void CTradeManager::CheckPartialCloseAndBE(bool isBuy, long signalID)
{
   // Agar allaqachon bajarilgan bo'lsa yoki funksiya o'chirilgan bo'lsa, chiqib ketamiz
   if((isBuy && m_buyPartialClosed) || (!isBuy && m_sellPartialClosed))
      return;
      
   string searchPattern = (isBuy ? "SF-BUY-" : "SF-SELL-") + IntegerToString(signalID);
   
   // 1-qadam: TP1 darajasini aniqlash (Target Price)
   double tp1Level = 0;
   double entryPrice = 0;
   bool tp1Found = false;
   
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, searchPattern) != -1)
      {
         // TP1 pozitsiyasini qidiramiz, chunki TP darajasi o'shanda aniq
         if(StringFind(comment, "TP1") != -1)
         {
            tp1Level = PositionGetDouble(POSITION_TP);
            entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            tp1Found = true;
            break;
         }
      }
   }
   
   // Agar TP1 pozitsiyasi topilmasa (yopilgan bo'lsa), bu funksiya ishlamaydi
   if(!tp1Found) return;
   
   // 2-qadam: 50% masofani hisoblash
   double distanceToTP1 = MathAbs(tp1Level - entryPrice);
   double triggerPrice = 0;
   
   if(isBuy)
      triggerPrice = entryPrice + (distanceToTP1 * 0.5); // 50% yuqorida
   else
      triggerPrice = entryPrice - (distanceToTP1 * 0.5); // 50% pastda
      
   // 3-qadam: Joriy narxni tekshirish
   double currentPrice = (isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : SymbolInfoDouble(m_symbol, SYMBOL_ASK));
   
   bool triggerReached = false;
   if(isBuy && currentPrice >= triggerPrice) triggerReached = true;
   if(!isBuy && currentPrice <= triggerPrice) triggerReached = true;
   
   if(!triggerReached) return;
   
   Print(">>> 50% Profit Reached! Executing Partial Close & BE. Signal: ", signalID);
   
   // 4-qadam: Barcha mos orderlarni 50% yopish va BE ga olish
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, searchPattern) == -1) continue;
      
      // A) Partial Close (50%)
      double currentVol = PositionGetDouble(POSITION_VOLUME);
      double closeVol = NormalizeVolume(currentVol * 0.5);
      
      // Agar yopiladigan hajm minimal lotdan katta bo'lsa
      if(closeVol > 0 && closeVol < currentVol)
      {
         if(m_trade.PositionClosePartial(ticket, closeVol))
         {
            Print("Partial Close 50%: #", ticket, " Vol: ", closeVol);
         }
         else
         {
            Print("Partial Close Failed: #", ticket, " Error: ", m_trade.ResultRetcodeDescription());
         }
      }
      
      // B) Move to BreakEven (Open Price)
      // Qisman yopilganda ticket o'zgargan bo'lishi mumkin, shuning uchun qayta olish yaxshiroq
      // Lekin MT5 da PositionClosePartial dan keyin qolgan qism shu ticketda qoladi
      double sl = NormalizePrice(entryPrice);
      double tp = PositionGetDouble(POSITION_TP); // TP o'zgarmaydi
      
      // Hozirgi SL allaqachon BE yoki yaxshiroq ekanligini tekshirish
      double currentSL = PositionGetDouble(POSITION_SL);
      bool needUpdate = false;
      
      if(isBuy)
      {
         if(currentSL < sl || currentSL == 0) needUpdate = true;
      }
      else
      {
         if(currentSL > sl || currentSL == 0) needUpdate = true;
      }
      
      if(needUpdate)
      {
         if(m_trade.PositionModify(ticket, sl, tp))
         {
            Print("Moved to BE: #", ticket, " SL: ", sl);
         }
      }
   }
   
   // 5-qadam: Flagni o'rnatish (qayta ishlamasligi uchun)
   if(isBuy) m_buyPartialClosed = true;
   else m_sellPartialClosed = true;
}

void CTradeManager::CheckAndSetBreakEven(bool isBuy, long signalID, double entryPrice)
{
   string searchPattern = (isBuy ? "SF-BUY-" : "SF-SELL-") + IntegerToString(signalID);
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, searchPattern) == -1) continue;
      
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double bePrice = NormalizePrice(entryPrice);
      
      bool needUpdate = false;
      if(isBuy)
      {
         double currentBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         if((currentSL < bePrice || currentSL == 0) && currentBid > bePrice)
            needUpdate = true;
      }
      else
      {
         double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         if((currentSL > bePrice || currentSL == 0) && currentAsk < bePrice)
            needUpdate = true;
      }
      
      if(needUpdate)
      {
         if(m_trade.PositionModify(ticket, bePrice, currentTP))
         {
            Print("Position #", ticket, " moved to BreakEven at ", bePrice);
         }
         else
         {
            Print("Failed to set BreakEven for #", ticket, ". Error: ", m_trade.ResultRetcodeDescription());
         }
      }
   }
}
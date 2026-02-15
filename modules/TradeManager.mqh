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
   TelegramSettings telegram;
   NewsSettings news;
   
   // VAQT FILTRI UCHUN YANGI QATORLAR
   string   startTime;      // "HH:MM" formatida
   string   endTime;        // "HH:MM" formatida
   
   double   dailyLossPercent; // Kunlik zarar limiti (%)
};

class CTradeManager
{
private:
   CTrade         m_trade;
   string         m_symbol;
   TradeSettings  m_settings;
   
   // Savdo holati o'zgaruvchilari
   long           m_currentBuySignalID;
   long           m_currentSellSignalID;
   int            m_currentBuyEntry;
   int            m_currentSellEntry;
   double         m_buyPivotPrice;
   double         m_sellPivotPrice;
   
   // --- YANGI: KUNLIK ZARAR UCHUN O'ZGARUVCHILAR ---
   bool           m_isDailyStopActive; // Bugun savdo to'xtatilganmi?
   int            m_lastDayOfYear;     // Kun o'zgarganini aniqlash uchun
   string         m_lastActionDescription; // Dashboard uchun oxirgi harakat
   
   // Yordamchi funksiyalar
   double         NormalizePrice(double price);
   double         CalculateSL(ENUM_ORDER_TYPE type, double entryPrice, FiboStructure &fibo);
   double         CalculateTP(ENUM_ORDER_TYPE type, double entryPrice, double fiboTP, int tpNum);
   bool           OpenPosition(ENUM_ORDER_TYPE type, double entry, double sl, double tp, string comment, double lot);
   bool           HasOpenOrders(long signalID, bool isBuy, int entryNum);
   void           CheckBreakevenForSignal(bool isBuy, long signalID);
   
   // --- YANGI: RISK FUNKSIYALARI ---
   void           CheckDailyLossLimit();   // Kunlik zararni tekshirish
   double         GetDailyTotalProfit();   // Kunlik foyda/zararni hisoblash
   void           CloseAllPositions();     // Hamma pozitsiyalarni yopish

public:
   CTradeManager();
   ~CTradeManager();
   
   bool           Init(string symbol, TradeSettings &settings);
   bool           ExecuteBuySetup(FiboStructure &fibo);
   bool           ExecuteSellSetup(FiboStructure &fibo);
   
   // Martingale funksiyalari (eski kodlar)
   void           CheckMartingaleEntry2Buy(FiboStructure &originalFibo);
   void           CheckMartingaleEntry3Buy(FiboStructure &originalFibo);
   void           CheckMartingaleEntry2Sell(FiboStructure &originalFibo);
   void           CheckMartingaleEntry3Sell(FiboStructure &originalFibo);
   void           UpdateTPAfterMartingale(bool isBuy, long signalID, double newPivot, double newEntry, FiboStructure &originalFibo);
   
   void           ManagePositions(); // Asosiy boshqaruv funksiyasi
   // --- DASHBOARD UCHUN GETTERLAR ---
   bool           IsDailyStopActive() { return m_isDailyStopActive; }
   bool           IsTradingTime();
   string         GetLastAction() { return m_lastActionDescription; }
   int            GetCurrentEntry(bool isBuy) { return isBuy ? m_currentBuyEntry : m_currentSellEntry; }
};

CTradeManager::CTradeManager()
{
   m_currentBuySignalID = 0; m_currentSellSignalID = 0;
   m_currentBuyEntry = 0; m_currentSellEntry = 0;
   m_buyPivotPrice = 0; m_sellPivotPrice = 0;
   m_isDailyStopActive = false; m_lastDayOfYear = -1;
   m_lastActionDescription = "Waiting for signal...";
}
CTradeManager::~CTradeManager(){}

bool CTradeManager::Init(string symbol, TradeSettings &settings)
{
   m_symbol = symbol;
   m_settings = settings;
   m_trade.SetExpertMagicNumber(m_settings.magic);
   m_trade.SetDeviationInPoints(m_settings.slippage);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   m_trade.SetAsyncMode(false);
   
   // Reset
   MqlDateTime dt; TimeCurrent(dt);
   m_lastDayOfYear = dt.day_of_year;
   return true;
}

void CTradeManager::ManagePositions()
{
   CheckDailyLossLimit();
   if(m_isDailyStopActive) return;

   if(m_settings.useBreakeven)
   {
      CheckBreakevenForSignal(true, m_currentBuySignalID);
      CheckBreakevenForSignal(false, m_currentSellSignalID);
   }
}

double CTradeManager::GetDailyTotalProfit()
{
   // Kun boshlanish vaqti (00:00 server vaqti)
   datetime startOfDay = iTime(m_symbol, PERIOD_D1, 0);
   datetime now = TimeCurrent();
   
   double totalProfit = 0.0;

   // 1. Yopilgan orderlar (History)
   if(HistorySelect(startOfDay, now))
   {
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         // Faqat shu ekspertning va shu paraning orderlari
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == m_settings.magic &&
            HistoryDealGetString(ticket, DEAL_SYMBOL) == m_symbol)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
            double comm = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            totalProfit += (profit + swap + comm);
         }
      }
   }

   // 2. Ochiq pozitsiyalar (Floating)
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == m_settings.magic &&
         PositionGetString(POSITION_SYMBOL) == m_symbol)
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         double swap = PositionGetDouble(POSITION_SWAP);
         // Komissiya odatda pozitsiya yopilganda olinadi, lekin hisobga olish yaxshi
         totalProfit += (profit + swap);
      }
   }
   
   return totalProfit;
}

void CTradeManager::CheckDailyLossLimit()
{
   // 1. Kun yangilanganini tekshirish
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.day_of_year != m_lastDayOfYear)
   {
      m_isDailyStopActive = false; // Yangi kun, blokirovkani ochamiz
      m_lastDayOfYear = dt.day_of_year;
      Print("Yangi kun boshlandi. Daily Loss reset qilindi.");
   }

   // Agar allaqachon bloklangan bo'lsa yoki funksiya o'chirilgan bo'lsa, qaytamiz
   if(m_isDailyStopActive || m_settings.dailyLossPercent <= 0) return;

   // 2. Limitni hisoblash
   double currentProfit = GetDailyTotalProfit();
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Kun boshidagi balansni taxminiy topish: Hozirgi Balans - Bugungi Yopilgan Foyda
   // (Eslatma: Bu yerda depozit/yechish hisobga olinmagan deb faraz qilinadi, aniqroq bo'lishi uchun)
   // Lekin oddiy yondashuv: "Kun boshidagi balans" = CurrentBalance - ClosedProfitToday
   // Yoki oddiygina: Hozirgi balansga nisbatan %
   
   // Foydalanuvchi "Balansdan kelib chiqib" degani uchun, eng to'g'risi:
   // StartBalance = CurrentBalance - ClosedProfit (faqat yopilganlar)
   
   double closedProfitToday = 0;
   datetime startOfDay = iTime(m_symbol, PERIOD_D1, 0);
   if(HistorySelect(startOfDay, TimeCurrent())) {
       for(int i=0; i<HistoryDealsTotal(); i++) {
           ulong t = HistoryDealGetTicket(i);
           if(HistoryDealGetInteger(t, DEAL_MAGIC) == m_settings.magic && HistoryDealGetString(t, DEAL_SYMBOL) == m_symbol)
               closedProfitToday += HistoryDealGetDouble(t, DEAL_PROFIT) + HistoryDealGetDouble(t, DEAL_SWAP) + HistoryDealGetDouble(t, DEAL_COMMISSION);
       }
   }
   
   double startDayBalance = currentBalance - closedProfitToday;
   double maxLossAmount = startDayBalance * (m_settings.dailyLossPercent / 100.0);

   // 3. Tekshirish: Agar (CurrentProfit <= -MaxLoss)
   if(currentProfit <= -maxLossAmount)
   {
      Print("⛔ KUNLIK ZARAR LIMITI YETDI! Limit: ", maxLossAmount, " Profit: ", currentProfit);
      Print("Barcha pozitsiyalar yopilmoqda va savdo to'xtatilmoqda.");
      
      CloseAllPositions();
      m_isDailyStopActive = true;
      
      // Telegramga xabar (agar ulangan bo'lsa - bu yerda oddiy Print, TelegramManagerga signal berish kerak bo'ladi tashqaridan)
   }
}

void CTradeManager::CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == m_settings.magic &&
         PositionGetString(POSITION_SYMBOL) == m_symbol)
      {
         m_trade.PositionClose(ticket);
      }
   }
}

double CTradeManager::NormalizePrice(double price)
{
   double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   return NormalizeDouble(MathRound(price / tickSize) * tickSize, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
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
   // Tekshiruvlar SuperFibo.mq5 da qilinadi (Vaqt, News), bu yerda faqat order
   m_currentBuySignalID = TimeCurrent();
   m_currentBuyEntry = 1;
   m_buyPivotPrice = fibo.level0;
   
   double entry1 = NormalizePrice(fibo.entry1.price);
   double sl = CalculateSL(ORDER_TYPE_BUY, entry1, fibo);
   
   bool success = false;
   if(fibo.tp1.show) {
      if(OpenPosition(ORDER_TYPE_BUY, entry1, sl, CalculateTP(ORDER_TYPE_BUY, entry1, fibo.tp1.price, 1), 
         "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E1-TP1", m_settings.lotSize)) success = true;
   }
   if(fibo.tp2.show) {
      if(OpenPosition(ORDER_TYPE_BUY, entry1, sl, CalculateTP(ORDER_TYPE_BUY, entry1, fibo.tp2.price, 2), 
         "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E1-TP2", m_settings.lotSize)) success = true;
   }
   
   if(success) m_lastActionDescription = "BUY Signal: Entry 1 Opened";
   return success;
}

bool CTradeManager::ExecuteSellSetup(FiboStructure &fibo)
{
   m_currentSellSignalID = TimeCurrent();
   m_currentSellEntry = 1;
   m_sellPivotPrice = fibo.level0;
   
   double entry1 = NormalizePrice(fibo.entry1.price);
   double sl = CalculateSL(ORDER_TYPE_SELL, entry1, fibo);
   
   bool success = false;
   if(fibo.tp1.show) {
      if(OpenPosition(ORDER_TYPE_SELL, entry1, sl, CalculateTP(ORDER_TYPE_SELL, entry1, fibo.tp1.price, 1), 
         "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E1-TP1", m_settings.lotSize)) success = true;
   }
   if(fibo.tp2.show) {
      if(OpenPosition(ORDER_TYPE_SELL, entry1, sl, CalculateTP(ORDER_TYPE_SELL, entry1, fibo.tp2.price, 2), 
         "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E1-TP2", m_settings.lotSize)) success = true;
   }
   
   if(success) m_lastActionDescription = "SELL Signal: Entry 1 Opened";
   return success;
}

void CTradeManager::CheckMartingaleEntry2Buy(FiboStructure &originalFibo)
{
  
   if(!m_settings.useMartingale || !originalFibo.entry2.show)
   {
      return;
   }
   
   
   if(m_currentBuyEntry != 1 || m_currentBuySignalID == 0)
   {
      return;
   }
   
   bool hasEntry1 = HasOpenOrders(m_currentBuySignalID, true, 1);
   Print("Has Entry1 orders: ", hasEntry1);
   
   if(!hasEntry1)
   {
      m_currentBuyEntry = 0;
      m_currentBuySignalID = 0;
      return;
   }
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);  // BUY order ASK da bajariladi
   
   
   if(currentPrice > originalFibo.entry2.price)
   {
      return;
   }
   
   
   double newLevel0 = m_buyPivotPrice;
   double newLevel1 = originalFibo.entry2.price;
   double newRange = newLevel1 - newLevel0;
   
   if(newRange <= 0)
      return;
   
   double origRange = originalFibo.level1 - originalFibo.level0;
   double tp1Ratio = (originalFibo.tp1.price - originalFibo.level0) / origRange;
   double tp2Ratio = (originalFibo.tp2.price - originalFibo.level0) / origRange;
   
   double newTP1 = newLevel0 + newRange * tp1Ratio;
   double newTP2 = newLevel0 + newRange * tp2Ratio;
   
   double entry2 = NormalizePrice(newLevel1);
   double sl = CalculateSL(ORDER_TYPE_BUY, entry2, originalFibo);
   double martingaleLot = m_settings.lotSize * 2.0;
   
   bool success = false;
   
   if(originalFibo.tp1.show)
   {
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E2-TP1-M";
      if(OpenPosition(ORDER_TYPE_BUY, entry2, sl, newTP1, comment, martingaleLot))
         success = true;
   }
   
   if(originalFibo.tp2.show)
   {
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E2-TP2-M";
      if(OpenPosition(ORDER_TYPE_BUY, entry2, sl, newTP2, comment, martingaleLot))
         success = true;
   }
   
   if(success)
   {
      m_currentBuyEntry = 2;
      m_buyPivotPrice = newLevel1;
      
      // TP ni yangilash - Entry1 va Entry2 uchun bir xil TP
      UpdateTPAfterMartingale(true, m_currentBuySignalID, newLevel0, newLevel1, originalFibo);
   }
}

void CTradeManager::CheckMartingaleEntry3Buy(FiboStructure &originalFibo)
{
   if(!m_settings.useMartingale || !originalFibo.entry3.show)
      return;
   
   if(m_currentBuyEntry != 2 || m_currentBuySignalID == 0)
      return;
   
   if(!HasOpenOrders(m_currentBuySignalID, true, 2))
      return;
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);  // BUY order ASK da bajariladi
   if(currentPrice > originalFibo.entry3.price)
      return;
   
   
   double newLevel0 = m_buyPivotPrice;
   double newLevel1 = originalFibo.entry3.price;
   double newRange = newLevel1 - newLevel0;
   
   if(newRange <= 0)
      return;
   
   double origRange = originalFibo.level1 - originalFibo.level0;
   double tp1Ratio = (originalFibo.tp1.price - originalFibo.level0) / origRange;
   double tp2Ratio = (originalFibo.tp2.price - originalFibo.level0) / origRange;
   
   double newTP1 = newLevel0 + newRange * tp1Ratio;
   double newTP2 = newLevel0 + newRange * tp2Ratio;
   
   double entry3 = NormalizePrice(newLevel1);
   double sl = CalculateSL(ORDER_TYPE_BUY, entry3, originalFibo);
   double martingaleLot = m_settings.lotSize * 4.0;
   
   bool success = false;
   
   if(originalFibo.tp1.show)
   {
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E3-TP1-M";
      if(OpenPosition(ORDER_TYPE_BUY, entry3, sl, newTP1, comment, martingaleLot))
         success = true;
   }
   
   if(originalFibo.tp2.show)
   {
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E3-TP2-M";
      if(OpenPosition(ORDER_TYPE_BUY, entry3, sl, newTP2, comment, martingaleLot))
         success = true;
   }
   
   if(success)
   {
      m_currentBuyEntry = 3;
      m_buyPivotPrice = newLevel1;
      
      // TP ni yangilash - Entry1, Entry2 va Entry3 uchun bir xil TP
      UpdateTPAfterMartingale(true, m_currentBuySignalID, newLevel0, newLevel1, originalFibo);
   }
}

void CTradeManager::CheckMartingaleEntry2Sell(FiboStructure &originalFibo)
{
   if(!m_settings.useMartingale || !originalFibo.entry2.show)
      return;
   
   if(m_currentSellEntry != 1 || m_currentSellSignalID == 0)
      return;
   
   if(!HasOpenOrders(m_currentSellSignalID, false, 1))
   {
      m_currentSellEntry = 0;
      m_currentSellSignalID = 0;
      return;
   }
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   if(currentPrice < originalFibo.entry2.price)
      return;
      
   double newLevel0 = m_sellPivotPrice;
   double newLevel1 = originalFibo.entry2.price;
   double newRange = newLevel1 - newLevel0;
   
   if(newRange <= 0)
      return;
   
   double origRange = originalFibo.level0 - originalFibo.level1;
   double tp1Ratio = (originalFibo.level0 - originalFibo.tp1.price) / origRange;
   double tp2Ratio = (originalFibo.level0 - originalFibo.tp2.price) / origRange;
   
   double newTP1 = newLevel0 - newRange * tp1Ratio;
   double newTP2 = newLevel0 - newRange * tp2Ratio;
   
   double entry2 = NormalizePrice(newLevel1);
   double sl = CalculateSL(ORDER_TYPE_SELL, entry2, originalFibo);
   double martingaleLot = m_settings.lotSize * 2.0;
   
   bool success = false;
   
   if(originalFibo.tp1.show)
   {
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E2-TP1-M";
      if(OpenPosition(ORDER_TYPE_SELL, entry2, sl, newTP1, comment, martingaleLot))
         success = true;
   }
   
   if(originalFibo.tp2.show)
   {
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E2-TP2-M";
      if(OpenPosition(ORDER_TYPE_SELL, entry2, sl, newTP2, comment, martingaleLot))
         success = true;
   }
   
   if(success)
   {
      m_currentSellEntry = 2;
      m_sellPivotPrice = newLevel1;
      
      // TP ni yangilash - Entry1 va Entry2 uchun bir xil TP
      UpdateTPAfterMartingale(false, m_currentSellSignalID, newLevel0, newLevel1, originalFibo);
   }
}

void CTradeManager::CheckMartingaleEntry3Sell(FiboStructure &originalFibo)
{
   if(!m_settings.useMartingale || !originalFibo.entry3.show)
      return;
   
   if(m_currentSellEntry != 2 || m_currentSellSignalID == 0)
      return;
   
   if(!HasOpenOrders(m_currentSellSignalID, false, 2))
      return;
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);  // SELL trigger uchun ASK (narx oshishini kuzatamiz)
   if(currentPrice < originalFibo.entry3.price)
      return;
      
   double newLevel0 = m_sellPivotPrice;
   double newLevel1 = originalFibo.entry3.price;
   double newRange = newLevel1 - newLevel0;
   
   if(newRange <= 0)
      return;
   
   double origRange = originalFibo.level0 - originalFibo.level1;
   double tp1Ratio = (originalFibo.level0 - originalFibo.tp1.price) / origRange;
   double tp2Ratio = (originalFibo.level0 - originalFibo.tp2.price) / origRange;
   
   double newTP1 = newLevel0 - newRange * tp1Ratio;
   double newTP2 = newLevel0 - newRange * tp2Ratio;
   
   double entry3 = NormalizePrice(newLevel1);
   double sl = CalculateSL(ORDER_TYPE_SELL, entry3, originalFibo);
   double martingaleLot = m_settings.lotSize * 4.0;
   
   bool success = false;
   
   if(originalFibo.tp1.show)
   {
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E3-TP1-M";
      if(OpenPosition(ORDER_TYPE_SELL, entry3, sl, newTP1, comment, martingaleLot))
         success = true;
   }
   
   if(originalFibo.tp2.show)
   {
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E3-TP2-M";
      if(OpenPosition(ORDER_TYPE_SELL, entry3, sl, newTP2, comment, martingaleLot))
         success = true;
   }
   
   if(success)
   {
      m_currentSellEntry = 3;
      m_sellPivotPrice = newLevel1;
      
      // TP ni yangilash - Entry1, Entry2 va Entry3 uchun bir xil TP
      UpdateTPAfterMartingale(false, m_currentSellSignalID, newLevel0, newLevel1, originalFibo);
   }
}

void CTradeManager::CheckBreakevenForSignal(bool isBuy, long signalID)
{
   if(signalID == 0) return;
   string signalStr = (isBuy ? "SF-BUY-" : "SF-SELL-") + IntegerToString(signalID);
   bool tp1Exists = false;
   ulong tp2Ticket = 0;
   double entryPrice = 0;

   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0 || PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, signalStr) == -1) continue;

      if(StringFind(comment, "-TP1") != -1) tp1Exists = true;
      if(StringFind(comment, "-TP2") != -1) { tp2Ticket = ticket; entryPrice = PositionGetDouble(POSITION_PRICE_OPEN); }
   }

   // Agar TP1 yopilgan (yo'q) va TP2 ochiq bo'lsa -> Breakeven
   if(!tp1Exists && tp2Ticket > 0)
   {
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      
      // Stop Loss hali kirish narxiga o'tkazilmagan bo'lsa
      if(NormalizePrice(currentSL) != NormalizePrice(entryPrice))
      {
         if(m_trade.PositionModify(tp2Ticket, entryPrice, currentTP))
         {
            Print("Breakeven applied to TP2: Ticket #", tp2Ticket);
            // Dashboard uchun status
            m_lastActionDescription = (isBuy ? "BUY" : "SELL") + " TP1 Hit -> Moved to BE";
         }
      }
   }
}

void CTradeManager::UpdateTPAfterMartingale(bool isBuy, long signalID, double newPivot, double newEntry, FiboStructure &originalFibo)
{
   
   // Yangi Fibo range
   double newRange = isBuy ? (newEntry - newPivot) : (newPivot - newEntry);
   if(newRange <= 0)
   {
      Print("Invalid newRange: ", newRange);
      return;
   }
   
   // Original Fibo range va TP ratio
   double origRange = isBuy ? (originalFibo.level1 - originalFibo.level0) : (originalFibo.level0 - originalFibo.level1);
   double tp1Ratio = isBuy ? ((originalFibo.tp1.price - originalFibo.level0) / origRange) : 
                             ((originalFibo.level0 - originalFibo.tp1.price) / origRange);
   
   // Yangi TP1 hisoblash
   double newTP1 = isBuy ? (newPivot + newRange * tp1Ratio) : (newPivot - newRange * tp1Ratio);
   newTP1 = NormalizePrice(newTP1);
      
   // Barcha signal ID ga tegishli pozitsiyalarni topish va TP ni yangilash
   string searchPattern = (isBuy ? "SF-BUY-" : "SF-SELL-") + IntegerToString(signalID);
   int updated = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, searchPattern) == -1) continue;
      
      // Bu bizning signalimiz, TP ni yangilaymiz
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      double currentSL = PositionGetDouble(POSITION_SL);
      
      if(m_trade.PositionModify(ticket, currentSL, newTP1))
      {
         Print("Position #", ticket, " TP updated to ", newTP1);
         updated++;
      }
      else
      {
         Print("Failed to update TP for position #", ticket, " Error: ", GetLastError());
      }
   }
   
   Print("Total positions updated: ", updated);
}


bool CTradeManager::IsTradingTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentMinutes = dt.hour * 60 + dt.min;

   string startParts[], endParts[];
   if(StringSplit(m_settings.startTime, ':', startParts) != 2 || 
      StringSplit(m_settings.endTime, ':', endParts) != 2) 
   {
      return true; // Agar format xato bo'lsa, cheklovsiz ishlaydi
   }

   int startMinutes = (int)StringToInteger(startParts[0]) * 60 + (int)StringToInteger(startParts[1]);
   int endMinutes = (int)StringToInteger(endParts[0]) * 60 + (int)StringToInteger(endParts[1]);

   if(startMinutes < endMinutes)
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   else // Sutkadan o'tuvchi vaqt uchun (masalan, 22:00 dan 04:00 gacha)
      return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
}
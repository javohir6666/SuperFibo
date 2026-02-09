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
   
   double         NormalizePrice(double price);
   double         CalculateSL(ENUM_ORDER_TYPE type, double entryPrice, FiboStructure &fibo);
   double         CalculateTP(ENUM_ORDER_TYPE type, double entryPrice, double fiboTP, int tpNum);
   
   bool           OpenPosition(ENUM_ORDER_TYPE type, double entry, double sl, double tp, 
                              string comment, double lot);
   bool           HasOpenOrders(long signalID, bool isBuy, int entryNum);
   
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
};

CTradeManager::CTradeManager()
{
   m_currentBuySignalID = 0;
   m_currentSellSignalID = 0;
   m_currentBuyEntry = 0;
   m_currentSellEntry = 0;
   m_buyPivotPrice = 0;
   m_sellPivotPrice = 0;
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

void CTradeManager::CheckMartingaleEntry2Buy(FiboStructure &originalFibo)
{
   Print("=== CheckMartingaleEntry2Buy START ===");
   Print("Martingale enabled: ", m_settings.useMartingale);
   Print("Entry2 show: ", originalFibo.entry2.show);
   
   if(!m_settings.useMartingale || !originalFibo.entry2.show)
   {
      Print("Martingale disabled or Entry2 not shown - EXIT");
      return;
   }
   
   Print("Current BuyEntry: ", m_currentBuyEntry);
   Print("Current SignalID: ", m_currentBuySignalID);
   
   if(m_currentBuyEntry != 1 || m_currentBuySignalID == 0)
   {
      Print("Entry not 1 or SignalID=0 - EXIT");
      return;
   }
   
   bool hasEntry1 = HasOpenOrders(m_currentBuySignalID, true, 1);
   Print("Has Entry1 orders: ", hasEntry1);
   
   if(!hasEntry1)
   {
      Print("Entry1 closed - resetting state");
      m_currentBuyEntry = 0;
      m_currentBuySignalID = 0;
      return;
   }
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);  // BUY order ASK da bajariladi
   
   // Debug
   Print("Entry2 Check: ASK=", currentPrice, " Entry2=", originalFibo.entry2.price, 
         " BuyEntry=", m_currentBuyEntry, " SignalID=", m_currentBuySignalID);
   
   if(currentPrice > originalFibo.entry2.price)
   {
      Print("ASK still above Entry2, waiting...");
      return;
   }
   
   Print("Martingale Entry2 BUY - ASK reached Entry2!");
   
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
   
   Print("Martingale Entry3 BUY");
   
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
   
   Print("Martingale Entry2 SELL");
   
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
   
   Print("Martingale Entry3 SELL");
   
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

void CTradeManager::ManagePositions()
{
   if(m_currentBuySignalID != 0)
   {
      string searchPattern = "SF-BUY-" + IntegerToString(m_currentBuySignalID);
      bool signalHasOrders = false;
      
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
            break;
         }
      }
      
      if(!signalHasOrders)
      {
         m_currentBuyEntry = 0;
         m_currentBuySignalID = 0;
      }
   }
   
   if(m_currentSellSignalID != 0)
   {
      string searchPattern = "SF-SELL-" + IntegerToString(m_currentSellSignalID);
      bool signalHasOrders = false;
      
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
            break;
         }
      }
      
      if(!signalHasOrders)
      {
         m_currentSellEntry = 0;
         m_currentSellSignalID = 0;
      }
   }
}

void CTradeManager::UpdateTPAfterMartingale(bool isBuy, long signalID, double newPivot, double newEntry, FiboStructure &originalFibo)
{
   Print("UpdateTPAfterMartingale: isBuy=", isBuy, " SignalID=", signalID, " NewPivot=", newPivot, " NewEntry=", newEntry);
   
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
   
   Print("Calculated newTP1=", newTP1, " (ratio=", tp1Ratio, ", newRange=", newRange, ")");
   
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

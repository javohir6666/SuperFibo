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
   
   // Partial Close va BE holatini kuzatish uchun flaglar
   bool           m_buyPartialClosed;
   bool           m_sellPartialClosed;
   
   // --- YANGI: Performance Optimization ---
   ulong          m_lastManageTime; // Oxirgi tekshiruv vaqti

   double         NormalizePrice(double price);
   double         CalculateSL(ENUM_ORDER_TYPE type, double entryPrice, FiboStructure &fibo);
   double         CalculateTP(ENUM_ORDER_TYPE type, double entryPrice, double fiboTP, int tpNum);
   bool           OpenPosition(ENUM_ORDER_TYPE type, double entry, double sl, double tp, 
                              string comment, double lot);
   bool           HasOpenOrders(long signalID, bool isBuy, int entryNum);
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
   
   // Asosiy boshqaruv funksiyasi
   void           ManagePositions();
   
   void           CheckAndSetBreakEven(bool isBuy, long signalID, double entryPrice);
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
   
   m_buyPartialClosed = false;
   m_sellPartialClosed = false;
   
   // --- YANGI: Vaqtni 0 ga tenglash ---
   m_lastManageTime = 0;
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
   m_buyPartialClosed = false; // Reset flag
   
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
   m_sellPartialClosed = false; // Reset flag
   
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
   if(!m_settings.useMartingale || !originalFibo.entry2.show) return;
   if(m_currentBuyEntry != 1 || m_currentBuySignalID == 0) return;
   
   if(!HasOpenOrders(m_currentBuySignalID, true, 1)) {
      m_currentBuyEntry = 0; m_currentBuySignalID = 0; return;
   }
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   if(currentPrice > originalFibo.entry2.price) return;
   
   double sl = CalculateSL(ORDER_TYPE_BUY, originalFibo.entry2.price, originalFibo);
   double lot = m_settings.lotSize * 2;
   
   bool success = false;
   if(originalFibo.tp1.show)
   {
      double tp1 = CalculateTP(ORDER_TYPE_BUY, originalFibo.entry2.price, originalFibo.tp1.price, 1);
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E2-TP1";
      if(OpenPosition(ORDER_TYPE_BUY, originalFibo.entry2.price, sl, tp1, comment, lot)) success = true;
   }
   if(originalFibo.tp2.show)
   {
      double tp2 = CalculateTP(ORDER_TYPE_BUY, originalFibo.entry2.price, originalFibo.tp2.price, 2);
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E2-TP2";
      if(OpenPosition(ORDER_TYPE_BUY, originalFibo.entry2.price, sl, tp2, comment, lot)) success = true;
   }
   
   if(success)
   {
      m_currentBuyEntry = 2;
      UpdateTPAfterMartingale(true, m_currentBuySignalID, m_buyPivotPrice, originalFibo.entry2.price, originalFibo);
   }
}

void CTradeManager::CheckMartingaleEntry3Buy(FiboStructure &originalFibo)
{
   if(!m_settings.useMartingale || !originalFibo.entry3.show) return;
   if(m_currentBuyEntry != 2 || m_currentBuySignalID == 0) return;
   
   if(!HasOpenOrders(m_currentBuySignalID, true, 2)) return;
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   if(currentPrice > originalFibo.entry3.price) return;
   
   double sl = CalculateSL(ORDER_TYPE_BUY, originalFibo.entry3.price, originalFibo);
   double lot = m_settings.lotSize * 4;
   
   bool success = false;
   if(originalFibo.tp1.show)
   {
      double tp1 = CalculateTP(ORDER_TYPE_BUY, originalFibo.entry3.price, originalFibo.tp1.price, 1);
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E3-TP1";
      if(OpenPosition(ORDER_TYPE_BUY, originalFibo.entry3.price, sl, tp1, comment, lot)) success = true;
   }
   if(originalFibo.tp2.show)
   {
      double tp2 = CalculateTP(ORDER_TYPE_BUY, originalFibo.entry3.price, originalFibo.tp2.price, 2);
      string comment = "SF-BUY-" + IntegerToString(m_currentBuySignalID) + "-E3-TP2";
      if(OpenPosition(ORDER_TYPE_BUY, originalFibo.entry3.price, sl, tp2, comment, lot)) success = true;
   }
   
   if(success)
   {
      m_currentBuyEntry = 3;
      UpdateTPAfterMartingale(true, m_currentBuySignalID, m_buyPivotPrice, originalFibo.entry3.price, originalFibo);
   }
}

void CTradeManager::CheckMartingaleEntry2Sell(FiboStructure &originalFibo)
{
   if(!m_settings.useMartingale || !originalFibo.entry2.show) return;
   if(m_currentSellEntry != 1 || m_currentSellSignalID == 0) return;
   
   if(!HasOpenOrders(m_currentSellSignalID, false, 1)) {
      m_currentSellEntry = 0; m_currentSellSignalID = 0; return;
   }
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(currentPrice < originalFibo.entry2.price) return;
   
   double sl = CalculateSL(ORDER_TYPE_SELL, originalFibo.entry2.price, originalFibo);
   double lot = m_settings.lotSize * 2;
   
   bool success = false;
   if(originalFibo.tp1.show)
   {
      double tp1 = CalculateTP(ORDER_TYPE_SELL, originalFibo.entry2.price, originalFibo.tp1.price, 1);
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E2-TP1";
      if(OpenPosition(ORDER_TYPE_SELL, originalFibo.entry2.price, sl, tp1, comment, lot)) success = true;
   }
   if(originalFibo.tp2.show)
   {
      double tp2 = CalculateTP(ORDER_TYPE_SELL, originalFibo.entry2.price, originalFibo.tp2.price, 2);
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E2-TP2";
      if(OpenPosition(ORDER_TYPE_SELL, originalFibo.entry2.price, sl, tp2, comment, lot)) success = true;
   }
   
   if(success)
   {
      m_currentSellEntry = 2;
      UpdateTPAfterMartingale(false, m_currentSellSignalID, m_sellPivotPrice, originalFibo.entry2.price, originalFibo);
   }
}

void CTradeManager::CheckMartingaleEntry3Sell(FiboStructure &originalFibo)
{
   if(!m_settings.useMartingale || !originalFibo.entry3.show) return;
   if(m_currentSellEntry != 2 || m_currentSellSignalID == 0) return;
   
   if(!HasOpenOrders(m_currentSellSignalID, false, 2)) return;
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(currentPrice < originalFibo.entry3.price) return;
   
   double sl = CalculateSL(ORDER_TYPE_SELL, originalFibo.entry3.price, originalFibo);
   double lot = m_settings.lotSize * 4;
   
   bool success = false;
   if(originalFibo.tp1.show)
   {
      double tp1 = CalculateTP(ORDER_TYPE_SELL, originalFibo.entry3.price, originalFibo.tp1.price, 1);
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E3-TP1";
      if(OpenPosition(ORDER_TYPE_SELL, originalFibo.entry3.price, sl, tp1, comment, lot)) success = true;
   }
   if(originalFibo.tp2.show)
   {
      double tp2 = CalculateTP(ORDER_TYPE_SELL, originalFibo.entry3.price, originalFibo.tp2.price, 2);
      string comment = "SF-SELL-" + IntegerToString(m_currentSellSignalID) + "-E3-TP2";
      if(OpenPosition(ORDER_TYPE_SELL, originalFibo.entry3.price, sl, tp2, comment, lot)) success = true;
   }
   
   if(success)
   {
      m_currentSellEntry = 3;
      UpdateTPAfterMartingale(false, m_currentSellSignalID, m_sellPivotPrice, originalFibo.entry3.price, originalFibo);
   }
}

void CTradeManager::UpdateTPAfterMartingale(bool isBuy, long signalID, double newPivot, double newEntry, FiboStructure &originalFibo)
{
   string searchPattern = "SF-" + (isBuy ? "BUY" : "SELL") + "-" + IntegerToString(signalID);
   int total = PositionsTotal();
   
   double avgEntry = 0;
   double totalLot = 0;
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), searchPattern) != -1)
      {
         avgEntry += PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
         totalLot += PositionGetDouble(POSITION_VOLUME);
      }
   }
   
   if(totalLot > 0)
   {
      avgEntry /= totalLot;
      
      double newTP1 = 0;
      if(isBuy) newTP1 = avgEntry + (originalFibo.tp1.price - originalFibo.entry1.price);
      else      newTP1 = avgEntry - (originalFibo.entry1.price - originalFibo.tp1.price);
      
      newTP1 = NormalizePrice(newTP1);
      
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
         if(StringFind(PositionGetString(POSITION_COMMENT), searchPattern) != -1)
         {
            m_trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), newTP1);
         }
      }
   }
}

void CTradeManager::ManagePositions()
{
   // --- YANGI: PERFORMANCE OPTIMIZATION ---
   // Har tickda PositionsTotal() ni tekshirish kompyuterni sekinlashtiradi.
   // Shuning uchun bu funksiyani har 1000 millisekund (1 soniya) da bir marta ishlatamiz.
   ulong now = GetTickCount64();
   if(now - m_lastManageTime < 1000)
      return;
      
   m_lastManageTime = now;
   
   // --- BUY LOGIC ---
   if(m_currentBuySignalID != 0)
   {
      // 1. Partial Close va BE
      CheckPartialCloseAndBE(true, m_currentBuySignalID);
      
      string searchPattern = "SF-BUY-" + IntegerToString(m_currentBuySignalID);
      bool signalHasOrders = false;
      
      // Faqat shu Magic va Symbol ga tegishli orderlar tekshiriladi
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
            break; // Bitta topilsa yetarli, loopni to'xtatish mumkin
         }
      }
      
      if(!signalHasOrders)
      {
         m_currentBuyEntry = 0;
         m_currentBuySignalID = 0;
         m_buyPartialClosed = false;
      }
   }
   
   // --- SELL LOGIC ---
   if(m_currentSellSignalID != 0)
   {
      // 1. Partial Close va BE
      CheckPartialCloseAndBE(false, m_currentSellSignalID);
      
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
         m_sellPartialClosed = false;
      }
   }
}

void CTradeManager::CheckPartialCloseAndBE(bool isBuy, long signalID)
{
   if((isBuy && m_buyPartialClosed) || (!isBuy && m_sellPartialClosed))
      return;
      
   string searchPattern = (isBuy ? "SF-BUY-" : "SF-SELL-") + IntegerToString(signalID);
   
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
      if(StringFind(comment, searchPattern) != -1 && StringFind(comment, "TP1") != -1)
      {
         tp1Level = PositionGetDouble(POSITION_TP);
         entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         tp1Found = true;
         break;
      }
   }
   
   if(!tp1Found) return;
   
   double distanceToTP1 = MathAbs(tp1Level - entryPrice);
   double triggerPrice = (isBuy) ? entryPrice + (distanceToTP1 * 0.5) : entryPrice - (distanceToTP1 * 0.5);
   
   double currentPrice = (isBuy ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : SymbolInfoDouble(m_symbol, SYMBOL_ASK));
   
   bool triggerReached = false;
   if(isBuy && currentPrice >= triggerPrice) triggerReached = true;
   if(!isBuy && currentPrice <= triggerPrice) triggerReached = true;
   
   if(!triggerReached) return;
   
   Print(">>> 50% Profit Reached! Executing Partial Close & BE. Signal: ", signalID);
   
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_settings.magic) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, searchPattern) == -1) continue;
      
      double currentVol = PositionGetDouble(POSITION_VOLUME);
      double closeVol = NormalizeVolume(currentVol * 0.5);
      
      if(closeVol > 0 && closeVol < currentVol)
      {
         m_trade.PositionClosePartial(ticket, closeVol);
      }
      
      double sl = NormalizePrice(entryPrice);
      double tp = PositionGetDouble(POSITION_TP);
      double currentSL = PositionGetDouble(POSITION_SL);
      bool needUpdate = false;
      
      if(isBuy) { if(currentSL < sl || currentSL == 0) needUpdate = true; }
      else      { if(currentSL > sl || currentSL == 0) needUpdate = true; }
      
      if(needUpdate) m_trade.PositionModify(ticket, sl, tp);
   }
   
   if(isBuy) m_buyPartialClosed = true;
   else m_sellPartialClosed = true;
}

void CTradeManager::CheckAndSetBreakEven(bool isBuy, long signalID, double entryPrice)
{
   // Bu funksiya endi CheckPartialCloseAndBE ichida qisman bajarilmoqda, 
   // lekin manual BE uchun saqlab qo'yildi.
   // Hozirgi kodda bu chaqirilmayapti.
}
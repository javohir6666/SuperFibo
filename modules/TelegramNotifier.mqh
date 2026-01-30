//+------------------------------------------------------------------+
//|                                             TelegramNotifier.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Javohir Abdullayev"
#property strict

#include "Settings.mqh"
#include "FibonacciLevels.mqh" // Fibo strukturasini tushunish uchun

class CTelegramNotifier
{
private:
   string         m_token;
   long           m_chatIDs[]; // Parsed ID lar massivi
   bool           m_enabled;
   string         m_symbol;

   // Vergul bilan ajratilgan stringni massivga aylantirish
   void ParseChatIDs(string rawIDs)
   {
      string output[];
      int count = StringSplit(rawIDs, ',', output);
      ArrayResize(m_chatIDs, 0);
      
      for(int i = 0; i < count; i++)
      {
         string cleanID = output[i];
         StringTrimLeft(cleanID);
         StringTrimRight(cleanID);
         
         if(StringLen(cleanID) > 0)
         {
            int size = ArraySize(m_chatIDs);
            ArrayResize(m_chatIDs, size + 1);
            m_chatIDs[size] = StringToInteger(cleanID);
         }
      }
   }

   // HTTP POST so'rov yuborish
   bool SendRequest(long chatID, string text)
   {
      string url = "https://api.telegram.org/bot" + m_token + "/sendMessage";
      
      string headers = "Content-Type: application/json\r\n";
      string jsonBody = StringFormat("{\"chat_id\": %d, \"text\": \"%s\", \"parse_mode\": \"HTML\", \"disable_web_page_preview\": true}", 
                                     chatID, text);
      
      char data[];
      StringToCharArray(jsonBody, data, 0, WHOLE_ARRAY, CP_UTF8);
      
      char result[];
      string resultHeaders;
      
      int timeout = 5000; // 5 soniya
      int res = WebRequest("POST", url, headers, timeout, data, data, resultHeaders);
      
      if(res == 200) return true;
      
      Print("Telegram Error: ", res, " URL: ", url);
      return false;
   }

public:
   CTelegramNotifier() { m_enabled = false; }
   ~CTelegramNotifier() {}

   void Init(string symbol, TelegramSettings &settings)
   {
      m_symbol = symbol;
      m_enabled = settings.enable;
      m_token = settings.token;
      ParseChatIDs(settings.chatIDs);
   }

   // Signal xabarini shakllantirish va yuborish
   void SendSignal(bool isBuy, double entryPrice, FiboStructure &fibo)
   {
      if(!m_enabled || ArraySize(m_chatIDs) == 0) return;
      
      string side = isBuy ? "🟢 <b>BUY</b>" : "🔴 <b>SELL</b>";
      string symbolTag = "#" + m_symbol;
      string time = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
      
      // Chiroyli xabar matni
      string msg = "";
      msg += "🚀 <b>NEW SIGNAL: " + symbolTag + "</b>\n";
      msg += "═══════════════════\n";
      msg += "Type: " + side + "\n";
      msg += "Entry: <code>" + DoubleToString(entryPrice, _Digits) + "</code>\n\n";
      
      if(fibo.sl.show)
         msg += "⛔ SL: " + DoubleToString(fibo.sl.price, _Digits) + "\n";
         
      if(fibo.tp1.show)
         msg += "✅ TP1: " + DoubleToString(fibo.tp1.price, _Digits) + "\n";
         
      if(fibo.tp2.show)
         msg += "🌟 TP2: " + DoubleToString(fibo.tp2.price, _Digits) + "\n";
         
      msg += "═══════════════════\n";
      msg += "⏳ <i>" + time + "</i>";

      // Barcha IDlarga yuborish
      for(int i = 0; i < ArraySize(m_chatIDs); i++)
      {
         SendRequest(m_chatIDs[i], msg);
      }
   }
};
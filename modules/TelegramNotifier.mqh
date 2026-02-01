//+------------------------------------------------------------------+
//|                                             TelegramNotifier.mqh |
//|                               Copyright 2025, Javohir Abdullayev |
//|                                               https://pycoder.uz |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Javohir Abdullayev"
#property strict

#include "Settings.mqh"
#include "FibonacciLevels.mqh"

class CTelegramNotifier
{
private:
   string         m_token;
   long           m_chatIDs[];
   bool           m_enabled;
   string         m_symbol;

   // 1. Chat IDlarni to'g'ri ajratib olish (long formatda)
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
            long id = StringToInteger(cleanID);
            if(id != 0)
            {
               int size = ArraySize(m_chatIDs);
               ArrayResize(m_chatIDs, size + 1);
               m_chatIDs[size] = id;
            }
         }
      }
   }

   // 2. JSON uchun matnni tozalash (Escape Characters)
   // Qo'shtirnoq va slash belgilarini to'g'rilaydi
   string JsonEscape(string text)
   {
      string res = text;
      StringReplace(res, "\\", "\\\\"); // Slashni escape qilish
      StringReplace(res, "\"", "\\\""); // Qo'shtirnoqni escape qilish
      StringReplace(res, "\n", "\\n");  // Yangi qatorni escape qilish
      StringReplace(res, "\r", "");     // Returnni olib tashlash
      return res;
   }

   // 3. So'rov yuborish (Xatoliklarni aniqlash bilan)
   bool SendRequest(long chatID, string text)
   {
      // URL
      string url = "https://api.telegram.org/bot" + m_token + "/sendMessage";
      
      // JSON Body yaratish (Qo'lda yig'amiz, xatosiz bo'lishi uchun)
      // MUHIM: chat_id ni string sifatida berish xavfsizroq (katta raqamlar uchun)
      string jsonBody = "{";
      jsonBody += "\"chat_id\": " + IntegerToString(chatID) + ",";
      jsonBody += "\"text\": \"" + JsonEscape(text) + "\",";
      jsonBody += "\"parse_mode\": \"HTML\",";
      jsonBody += "\"disable_web_page_preview\": true";
      jsonBody += "}";
      
      // Headers
      string headers = "Content-Type: application/json\r\n";
      
      // Data tayyorlash
      char data[];
      int dataSize = StringToCharArray(jsonBody, data, 0, WHOLE_ARRAY, CP_UTF8);
      // StringToCharArray oxirida 0 belgisini qo'shadi, uni olib tashlash kerak (POST uchun)
      if(dataSize > 0) ArrayResize(data, dataSize - 1);
      
      char result[];
      string resultHeaders;
      
      // So'rov yuborish
      int timeout = 5000;
      ResetLastError();
      int res = WebRequest("POST", url, headers, timeout, data, result, resultHeaders);
      
      if(res == 200)
      {
         return true;
      }
      else
      {
         // Xatolikni batafsil chiqarish
         Print("❌ Telegram Error: ", res);
         Print("   URL: ", url);
         Print("   ChatID: ", chatID);
         // Agar server javob qaytargan bo'lsa, uni ko'rsatish (masalan nima xato ekanligi)
         if(ArraySize(result) > 0)
         {
            string serverMsg = CharArrayToString(result);
            Print("   Server Response: ", serverMsg);
         }
         else
         {
            Print("   LastError: ", GetLastError());
         }
         return false;
      }
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
      
      if(m_enabled && ArraySize(m_chatIDs) == 0)
         Print("⚠ Telegram yoqilgan, lekin Chat ID kiritilmagan!");
   }

   // Signal yuborish
   void SendSignal(bool isBuy, double entryPrice, FiboStructure &fibo)
   {
      if(!m_enabled || ArraySize(m_chatIDs) == 0) return;
      
      // Emojilar
      string sideEmoji = isBuy ? "🟢" : "🔴";
      string sideText  = isBuy ? "BUY" : "SELL";
      
      // Xabar matni (HTML formatda)
      string msg = "";
      msg += sideEmoji + " <b>NEW SIGNAL: #" + m_symbol + "</b>\n";
      msg += "═══════════════════\n";
      msg += "Type: <b>" + sideText + "</b>\n";
      msg += "Entry: <code>" + DoubleToString(entryPrice, _Digits) + "</code>\n\n";
      
      if(fibo.sl.show)
         msg += "⛔ SL: " + DoubleToString(fibo.sl.price, _Digits) + "\n";
         
      if(fibo.tp1.show)
         msg += "✅ TP1: " + DoubleToString(fibo.tp1.price, _Digits) + "\n";
         
      if(fibo.tp2.show)
         msg += "🌟 TP2: " + DoubleToString(fibo.tp2.price, _Digits) + "\n";
         
      msg += "═══════════════════\n";
      msg += "⏳ " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);

      // Har bir Chat ID ga yuborish
      for(int i = 0; i < ArraySize(m_chatIDs); i++)
      {
         SendRequest(m_chatIDs[i], msg);
      }
   }
   
   // Test xabar yuborish (Init da tekshirish uchun)
   void SendTestMessage()
   {
      if(!m_enabled || ArraySize(m_chatIDs) == 0) return;
      string msg = "🤖 <b>SuperFibo Bot Connected!</b>\nSymbol: " + m_symbol;
      for(int i = 0; i < ArraySize(m_chatIDs); i++) SendRequest(m_chatIDs[i], msg);
   }
};
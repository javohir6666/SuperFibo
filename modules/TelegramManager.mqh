//+------------------------------------------------------------------+
//|                                             TelegramManager.mqh |
//+------------------------------------------------------------------+
class CTelegramManager
{
private:
   string   m_token;
   string   m_chatID;
   bool     m_enabled;

   // URL dagi belgilarni UTF-8 formatida kodlash (Emoji muammosi uchun yechim)
   string UrlEncode(string text)
   {
      string out = "";
      uchar src[];
      // Matnni UTF-8 formatidagi byte massivga o'tkazamiz
      StringToCharArray(text, src, 0, WHOLE_ARRAY, CP_UTF8);
      
      for(int i = 0; i < ArraySize(src) - 1; i++) // -1 chunki oxirgi 0-byte kerak emas
      {
         // Faqat xavfsiz belgilarni o'z holicha qoldiramiz (0-9, A-Z, a-z)
         if((src[i] >= 48 && src[i] <= 57) || 
            (src[i] >= 65 && src[i] <= 90) || 
            (src[i] >= 97 && src[i] <= 122))
         {
            out += CharToString(src[i]);
         }
         else
         {
            // Barcha boshqa belgilarni (emoji, bo'sh joy va h.k.) %hex formatiga o'tkazamiz
            out += StringFormat("%%%02X", src[i]);
         }
      }
      return out;
   }

public:
   CTelegramManager() : m_token(""), m_chatID(""), m_enabled(false) {}

   void Init(string token, string chatID, bool enabled)
   {
      m_token = token;
      m_chatID = chatID;
      m_enabled = enabled;
   }

   void SendMessage(string message)
   {
      if(!m_enabled || m_token == "" || m_chatID == "") return;

      // Matnni yuborishdan oldin UTF-8 URL formatiga o'tkazamiz
      string encodedMsg = UrlEncode(message);
      
      string url = "https://api.telegram.org/bot" + m_token + "/sendMessage?chat_id=" + m_chatID + "&text=" + encodedMsg;
      
      char post[], result[];
      string headers;
      int timeout = 5000;

      // WebRequest orqali xabarni yuboramiz
      int res = WebRequest("GET", url, NULL, timeout, post, result, headers);
      
      if(res == -1) 
         Print("Telegram Error (Kodi: ", GetLastError(), "). URL Terminal sozlamalarida ruxsat etilganini tekshiring.");
      else
         Print("Telegram xabari muvaffaqiyatli yuborildi.");
   }
};
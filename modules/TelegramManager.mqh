//+------------------------------------------------------------------+
//|                                             TelegramManager.mqh |
//+------------------------------------------------------------------+
class CTelegramManager
{
private:
   string   m_token;
   string   m_chatID;
   bool     m_enabled;

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

      string url = "https://api.telegram.org/bot" + m_token + "/sendMessage?chat_id=" + m_chatID + "&text=" + message;
      char post[], result[];
      string headers;
      int timeout = 5000;

      // WebRequest ishlatish uchun Terminal sozlamalarida URL ruxsat etilgan bo'lishi kerak
      int res = WebRequest("GET", url, NULL, timeout, post, result, headers);
      if(res == -1) Print("Telegram Error: ", GetLastError());
   }
};
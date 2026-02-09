# SuperFibo EA - Pine Script to MQL5 Port

## 📋 Umumiy Ma'lumot

Bu EA Pine Script "RSI Super Fibo" indikatorining to'liq funksional MQL5 portasi.

## 🏗️ Arxitektura

### Modullar Tuzilishi:
```
SuperFibo/
├── SuperFibo.mq5           # Asosiy EA fayli
├── modules/
│   ├── Settings.mqh        # Strukturalar va sozlamalar
│   ├── RSICalculator.mqh   # RSI hisoblash va signallar
│   ├── PivotDetector.mqh   # Pivot High/Low aniqlash
│   ├── FibonacciLevels.mqh # Fibonacci darajalarini hisoblash
│   ├── ChartDrawing.mqh    # Grafikda chizish
│   └── TradeManager.mqh    # Savdo operatsiyalari
```

## 🔧 Ishlash Prinsipi

### 1. RSI Signal Aniqlash
- **BUY Signal**: RSI Oversold (24.62) zonasiga **yuqoridan pastga** kesib o'tganda
- **SELL Signal**: RSI Overbought (77.62) zonasiga **pastdan yuqoriga** kesib o'tganda

### 2. Pivot Nuqtalar
- **Pivot High**: 5 chap + 5 o'ng bardan eng yuqori nuqta
- **Pivot Low**: 5 chap + 5 o'ng bardan eng past nuqta
- **Tasdiq**: rightBars (5) ta bar keyin tasdiqlanadi

### 3. Fibonacci Darajalar

#### BUY uchun:
- 0-daraja = Oxirgi Pivot High
- 1-daraja = OS Low (RSI zonaga kirgan sham Low)
- Formula: `price = pivotHigh - range * fibLevel`

#### SELL uchun:
- 0-daraja = Oxirgi Pivot Low  
- 1-daraja = OB High (RSI zonaga kirgan sham High)
- Formula: `price = pivotLow + range * fibLevel`

### 4. Entry va TP Darajalari
- **Entry 1**: 1.0 (har doim)
- **Entry 2**: 1.6 (ixtiyoriy)
- **Entry 3**: 2.6 (ixtiyoriy)
- **TP1**: 0.562 (ixtiyoriy)
- **TP2**: 0.0 (ixtiyoriy)

## 🐛 Muammolar va Yechimlar

### Muammo 1: Pivot topilmayapti
**Sabab**: Dastlabki barlarda yetarlicha tarix yo'q
**Yechim**: 
- Kamida `leftBars + rightBars + 10` ta bar kerak
- Har yangi barda barcha eski barlarni tekshirish (state management)

### Muammo 2: Signal juda ko'p
**Sabab**: Har RSI crossover da signal
**Yechim**:
- Faqat **barstate.isconfirmed** (tasdiqlangan bar) da signal
- State bilan takrorlanishni oldini olish

## ⚙️ Sozlamalar

### RSI
- Period: 14
- Overbought: 77.62
- Oversold: 24.62

### Pivot
- Left Bars: 5
- Right Bars: 5
- Show Pivots: Ko'rsatish/yashirish
- Show S/R: Support/Resistance chiziqlar

### Fibonacci
- Line Length: 15 bar
- Entry/TP darajalari: sozlanadi

### Trading
- Enable Trading: false (default - faqat chizadi)
- Lot Size: 0.01
- Stop Loss / Take Profit: ixtiyoriy

## 📊 State Management

EA har bir komponent uchun state saqlaydi:

1. **RSI State**: Oldingi 2 ta qiymat (crossover aniqlash)
2. **Pivot State**: Oxirgi Pivot High va Low
3. **Fibo State**: Faol BUY/SELL Fibonacci
4. **Trade State**: Ochiq pozitsiyalar

## 🔄 Ishlash Jarayoni (OnTick)

```
OnTick()
  └─> Yangi bar tekshiruvi
      ├─> RSI.Update()
      ├─> Pivot.Update() 
      │   └─> Yangi pivot aniqlash
      │       └─> State yangilash
      ├─> RSI Signal tekshirish
      │   ├─> IsOversoldEntry() → BUY
      │   └─> IsOverboughtEntry() → SELL
      ├─> Pivot mavjudligini tekshirish
      ├─> Fibonacci hisoblash
      ├─> Grafikda chizish
      └─> Savdo (agar yoqilgan bo'lsa)
```

## ✅ To'g'ri Ishlashi Uchun

1. ✓ Yetarlicha tarix (100+ bar)
2. ✓ RSI ma'lumotlari tayyor
3. ✓ Pivot aniqlangan
4. ✓ Signal tasdiqlangan barda
5. ✓ State to'g'ri saqlanadi

## 📝 Qo'shimcha

- Savdo default yoqilmagan (testing uchun)
- Barcha signallar Journal da ko'rinadi
- Grafikda real-time chiziladi

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fill the 257 missing translation keys (present in en.json, absent in others).

Strategy: map each unique English VALUE -> per-language translation.
Placeholders like {x}, #{id}, {count}%, emojis, and arrows are preserved
inside the translated strings. Values that are placeholder-only (e.g. "{count}",
"#{id}", "{symbol}, ") pass through unchanged for every language.
"""
import json, os, re

ROOT = os.path.join(os.path.dirname(__file__), '..')
TRANS_DIR = os.path.join(ROOT, 'assets', 'translations')

en = json.load(open(os.path.join(TRANS_DIR, 'en.json'), encoding='utf-8'))

# value -> {lang: translation}. Langs: es, ar, hi, tr, fr, id, zh
# es_MX derives from es (handled at apply time).
T = {
    "Settings": {"es":"Configuración","ar":"الإعدادات","hi":"सेटिंग्स","tr":"Ayarlar","fr":"Paramètres","id":"Pengaturan","zh":"设置"},
    "Verify Your Account": {"es":"Verifica tu cuenta","ar":"تحقق من حسابك","hi":"अपना खाता सत्यापित करें","tr":"Hesabınızı Doğrulayın","fr":"Vérifiez votre compte","id":"Verifikasi Akun Anda","zh":"验证您的账户"},
    "Complete verification to unlock all features": {"es":"Completa la verificación para desbloquear todas las funciones","ar":"أكمل التحقق لفتح جميع الميزات","hi":"सभी सुविधाओं को अनलॉक करने के लिए सत्यापन पूरा करें","tr":"Tüm özelliklerin kilidini açmak için doğrulamayı tamamlayın","fr":"Terminez la vérification pour débloquer toutes les fonctionnalités","id":"Selesaikan verifikasi untuk membuka semua fitur","zh":"完成验证以解锁所有功能"},
    "Version {version}": {"es":"Versión {version}","ar":"الإصدار {version}","hi":"संस्करण {version}","tr":"Sürüm {version}","fr":"Version {version}","id":"Versi {version}","zh":"版本 {version}"},
    "Are you sure you want to logout?": {"es":"¿Seguro que quieres cerrar sesión?","ar":"هل أنت متأكد أنك تريد تسجيل الخروج؟","hi":"क्या आप लॉगआउट करना चाहते हैं?","tr":"Çıkış yapmak istediğinize emin misiniz?","fr":"Voulez-vous vraiment vous déconnecter ?","id":"Yakin ingin keluar?","zh":"确定要退出登录吗？"},
    "Are you sure you want to delete your account?": {"es":"¿Seguro que quieres eliminar tu cuenta?","ar":"هل أنت متأكد أنك تريد حذف حسابك؟","hi":"क्या आप अपना खाता हटाना चाहते हैं?","tr":"Hesabınızı silmek istediğinize emin misiniz?","fr":"Voulez-vous vraiment supprimer votre compte ?","id":"Yakin ingin menghapus akun Anda?","zh":"确定要删除您的账户吗？"},
    "Enter your password": {"es":"Ingresa tu contraseña","ar":"أدخل كلمة المرور","hi":"अपना पासवर्ड दर्ज करें","tr":"Şifrenizi girin","fr":"Saisissez votre mot de passe","id":"Masukkan kata sandi Anda","zh":"输入您的密码"},
    "Deposit": {"es":"Depósito","ar":"إيداع","hi":"जमा","tr":"Para Yatır","fr":"Dépôt","id":"Deposit","zh":"存款"},
    "Withdraw": {"es":"Retirar","ar":"سحب","hi":"निकासी","tr":"Para Çek","fr":"Retrait","id":"Tarik","zh":"提款"},
    "Transfer": {"es":"Transferir","ar":"تحويل","hi":"स्थानांतरण","tr":"Transfer","fr":"Transfert","id":"Transfer","zh":"转账"},
    "History": {"es":"Historial","ar":"السجل","hi":"इतिहास","tr":"Geçmiş","fr":"Historique","id":"Riwayat","zh":"历史记录"},
    "Trading Account": {"es":"Cuenta de trading","ar":"حساب التداول","hi":"ट्रेडिंग खाता","tr":"İşlem Hesabı","fr":"Compte de trading","id":"Akun Trading","zh":"交易账户"},
    "Finance": {"es":"Finanzas","ar":"المالية","hi":"वित्त","tr":"Finans","fr":"Finance","id":"Keuangan","zh":"财务"},
    "Promotional": {"es":"Promociones","ar":"العروض الترويجية","hi":"प्रचार","tr":"Promosyon","fr":"Promotions","id":"Promosi","zh":"推广"},
    "IB Dashboard": {"es":"Panel de IB","ar":"لوحة الوكيل","hi":"IB डैशबोर्ड","tr":"IB Paneli","fr":"Tableau de bord IB","id":"Dasbor IB","zh":"IB 仪表板"},
    "Copy Trading": {"es":"Copy Trading","ar":"نسخ التداول","hi":"कॉपी ट्रेडिंग","tr":"Kopya Ticaret","fr":"Copy Trading","id":"Copy Trading","zh":"跟单交易"},
    "Theme": {"es":"Tema","ar":"السمة","hi":"थीम","tr":"Tema","fr":"Thème","id":"Tema","zh":"主题"},
    "Change Password": {"es":"Cambiar contraseña","ar":"تغيير كلمة المرور","hi":"पासवर्ड बदलें","tr":"Şifre Değiştir","fr":"Changer le mot de passe","id":"Ubah Kata Sandi","zh":"修改密码"},
    "Two-Factor Authentication": {"es":"Autenticación de dos factores","ar":"المصادقة الثنائية","hi":"दो-कारक प्रमाणीकरण","tr":"İki Faktörlü Kimlik Doğrulama","fr":"Authentification à deux facteurs","id":"Autentikasi Dua Faktor","zh":"双重验证"},
    "One Click Trading": {"es":"Trading con un clic","ar":"التداول بنقرة واحدة","hi":"वन क्लिक ट्रेडिंग","tr":"Tek Tıkla İşlem","fr":"Trading en un clic","id":"Trading Satu Klik","zh":"一键交易"},
    "Biometric Login": {"es":"Inicio de sesión biométrico","ar":"تسجيل الدخول البيومتري","hi":"बायोमेट्रिक लॉगिन","tr":"Biyometrik Giriş","fr":"Connexion biométrique","id":"Login Biometrik","zh":"生物识别登录"},
    "Support Tickets": {"es":"Tickets de soporte","ar":"تذاكر الدعm","hi":"सहायता टिकट","tr":"Destek Talepleri","fr":"Tickets de support","id":"Tiket Dukungan","zh":"支持工单"},
    "Delete Account": {"es":"Eliminar cuenta","ar":"حذف الحساب","hi":"खाता हटाएं","tr":"Hesabı Sil","fr":"Supprimer le compte","id":"Hapus Akun","zh":"删除账户"},
    "Logout": {"es":"Cerrar sesión","ar":"تسجيل الخروج","hi":"लॉगआउट","tr":"Çıkış Yap","fr":"Déconnexion","id":"Keluar","zh":"退出登录"},
    "Yes": {"es":"Sí","ar":"نعم","hi":"हाँ","tr":"Evet","fr":"Oui","id":"Ya","zh":"是"},
    "No": {"es":"No","ar":"لا","hi":"नहीं","tr":"Hayır","fr":"Non","id":"Tidak","zh":"否"},
    "Quotes": {"es":"Cotizaciones","ar":"الأسعار","hi":"कोट्स","tr":"Kotasyonlar","fr":"Cotations","id":"Kuotasi","zh":"报价"},
    "Charts": {"es":"Gráficos","ar":"الرسوم البيانية","hi":"चार्ट","tr":"Grafikler","fr":"Graphiques","id":"Grafik","zh":"图表"},
    "Trade": {"es":"Operar","ar":"تداول","hi":"ट्रेड","tr":"İşlem","fr":"Trader","id":"Trading","zh":"交易"},
    "Enter Lot Size": {"es":"Ingresa el tamaño del lote","ar":"أدخل حجم اللوت","hi":"लॉट साइज़ दर्ज करें","tr":"Lot Büyüklüğü Girin","fr":"Saisissez la taille du lot","id":"Masukkan Ukuran Lot","zh":"输入手数"},
    "Cancel": {"es":"Cancelar","ar":"إلغاء","hi":"रद्द करें","tr":"İptal","fr":"Annuler","id":"Batal","zh":"取消"},
    "Select Symbol": {"es":"Seleccionar símbolo","ar":"اختر الرمز","hi":"सिंबल चुनें","tr":"Sembol Seç","fr":"Sélectionner le symbole","id":"Pilih Simbol","zh":"选择品种"},
    "Search...": {"es":"Buscar...","ar":"بحث...","hi":"खोजें...","tr":"Ara...","fr":"Rechercher...","id":"Cari...","zh":"搜索..."},
    "Sell": {"es":"Vender","ar":"بيع","hi":"बेचें","tr":"Sat","fr":"Vendre","id":"Jual","zh":"卖出"},
    "Buy": {"es":"Comprar","ar":"شراء","hi":"खरीदें","tr":"Al","fr":"Acheter","id":"Beli","zh":"买入"},
    "H: {high}": {"es":"H: {high}","ar":"أعلى: {high}","hi":"H: {high}","tr":"Y: {high}","fr":"H: {high}","id":"T: {high}","zh":"高: {high}"},
    "L: {low}": {"es":"L: {low}","ar":"أدنى: {low}","hi":"L: {low}","tr":"D: {low}","fr":"B: {low}","id":"R: {low}","zh":"低: {low}"},
    "Close failed: {e}": {"es":"Cierre fallido: {e}","ar":"فشل الإغلاق: {e}","hi":"क्लोज़ विफल: {e}","tr":"Kapatma başarısız: {e}","fr":"Échec de la clôture : {e}","id":"Gagal menutup: {e}","zh":"平仓失败：{e}"},
    "Close position #{id}": {"es":"Cerrar posición #{id}","ar":"إغلاق المركز #{id}","hi":"पोज़िशन बंद करें #{id}","tr":"Pozisyonu kapat #{id}","fr":"Clôturer la position #{id}","id":"Tutup posisi #{id}","zh":"平仓 #{id}"},
    "Close mode": {"es":"Modo de cierre","ar":"وضع الإغلاق","hi":"क्लोज़ मोड","tr":"Kapatma modu","fr":"Mode de clôture","id":"Mode tutup","zh":"平仓模式"},
    "Tap a − pill to close part of the position": {"es":"Toca un − para cerrar parte de la posición","ar":"اضغط على − لإغلاق جزء من المركز","hi":"पोज़िशन का हिस्सा बंद करने के लिए − पर टैप करें","tr":"Pozisyonun bir kısmını kapatmak için − öğesine dokunun","fr":"Appuyez sur un − pour clôturer une partie de la position","id":"Ketuk − untuk menutup sebagian posisi","zh":"点击 − 以平掉部分仓位"},
    "Fill policy": {"es":"Política de ejecución","ar":"سياسة التنفيذ","hi":"फिल पॉलिसी","tr":"Gerçekleşme politikası","fr":"Politique d'exécution","id":"Kebijakan eksekusi","zh":"成交策略"},
    "Fill or Kill": {"es":"Ejecutar o cancelar (FOK)","ar":"تنفيذ كامل أو إلغاء","hi":"फिल ऑर किल","tr":"Tümü ya da Hiç","fr":"Tout ou rien (FOK)","id":"Isi atau Batal","zh":"全部成交或取消"},
    "Immediate or Cancel": {"es":"Inmediato o cancelar (IOC)","ar":"فوري أو إلغاء","hi":"इमीडिएट ऑर कैंसिल","tr":"Anında ya da İptal","fr":"Immédiat ou annulé (IOC)","id":"Segera atau Batal","zh":"立即成交或取消"},
    "Book or Cancel": {"es":"Registrar o cancelar (BOC)","ar":"إدراج أو إلغاء","hi":"बुक ऑर कैंसिल","tr":"Kaydet ya da İptal","fr":"Enregistrer ou annuler (BOC)","id":"Buku atau Batal","zh":"挂单或取消"},
    "Price: ": {"es":"Precio: ","ar":"السعر: ","hi":"मूल्य: ","tr":"Fiyat: ","fr":"Prix : ","id":"Harga: ","zh":"价格："},
    "Stop Limit price: ": {"es":"Precio Stop Limit: ","ar":"سعر ستوب ليميت: ","hi":"स्टॉप लिमिट मूल्य: ","tr":"Stop Limit fiyatı: ","fr":"Prix Stop Limit : ","id":"Harga Stop Limit: ","zh":"止损限价："},
    "Expiration:": {"es":"Vencimiento:","ar":"انتهاء الصلاحية:","hi":"समाप्ति:","tr":"Son geçerlilik:","fr":"Expiration :","id":"Kedaluwarsa:","zh":"到期："},
    "BY MARKET": {"es":"A MERCADO","ar":"حسب السوق","hi":"मार्केट पर","tr":"PİYASADAN","fr":"AU MARCHÉ","id":"SESUAI PASAR","zh":"按市价"},
    "No active account": {"es":"No hay cuenta activa","ar":"لا يوجد حساب نشط","hi":"कोई सक्रिय खाता नहीं","tr":"Aktif hesap yok","fr":"Aucun compte actif","id":"Tidak ada akun aktif","zh":"没有活跃账户"},
    "Order failed": {"es":"Orden fallida","ar":"فشل الأمر","hi":"ऑर्डर विफल","tr":"Emir başarısız","fr":"Échec de l'ordre","id":"Order gagal","zh":"下单失败"},
    "Error": {"es":"Error","ar":"خطأ","hi":"त्रुटि","tr":"Hata","fr":"Erreur","id":"Kesalahan","zh":"错误"},
    "Refreshed": {"es":"Actualizado","ar":"تم التحديث","hi":"रीफ़्रेश हुआ","tr":"Yenilendi","fr":"Actualisé","id":"Diperbarui","zh":"已刷新"},
    "Trades": {"es":"Operaciones","ar":"الصفقات","hi":"ट्रेड्स","tr":"İşlemler","fr":"Transactions","id":"Transaksi","zh":"交易"},
    "Net P/L": {"es":"P/G neto","ar":"صافي الربح/الخسارة","hi":"नेट P/L","tr":"Net K/Z","fr":"P/L net","id":"P/L bersih","zh":"净盈亏"},
    "{lots} lot": {"es":"{lots} lote","ar":"{lots} لوت","hi":"{lots} लॉट","tr":"{lots} lot","fr":"{lots} lot","id":"{lots} lot","zh":"{lots} 手"},
    "Price: {price}": {"es":"Precio: {price}","ar":"السعر: {price}","hi":"मूल्य: {price}","tr":"Fiyat: {price}","fr":"Prix : {price}","id":"Harga: {price}","zh":"价格：{price}"},
    "Cancel Order": {"es":"Cancelar orden","ar":"إلغاء الأمر","hi":"ऑर्डर रद्द करें","tr":"Emri İptal Et","fr":"Annuler l'ordre","id":"Batalkan Order","zh":"取消订单"},
    "Dismiss": {"es":"Descartar","ar":"إغلاق","hi":"खारिज करें","tr":"Kapat","fr":"Ignorer","id":"Tutup","zh":"关闭"},
    "Spread {spread}": {"es":"Spread {spread}","ar":"السبريد {spread}","hi":"स्प्रेड {spread}","tr":"Spread {spread}","fr":"Spread {spread}","id":"Spread {spread}","zh":"点差 {spread}"},
    "Success": {"es":"Éxito","ar":"نجاح","hi":"सफल","tr":"Başarılı","fr":"Succès","id":"Berhasil","zh":"成功"},
    "Positions": {"es":"Posiciones","ar":"المراكز","hi":"पोज़िशन्स","tr":"Pozisyonlar","fr":"Positions","id":"Posisi","zh":"持仓"},
    "Orders": {"es":"Órdenes","ar":"الأوامر","hi":"ऑर्डर्स","tr":"Emirler","fr":"Ordres","id":"Order","zh":"订单"},
    "Close position": {"es":"Cerrar posición","ar":"إغلاق المركز","hi":"पोज़िशन बंद करें","tr":"Pozisyonu kapat","fr":"Clôturer la position","id":"Tutup posisi","zh":"平仓"},
    "Modify position": {"es":"Modificar posición","ar":"تعديل المركز","hi":"पोज़िशन संशोधित करें","tr":"Pozisyonu düzenle","fr":"Modifier la position","id":"Ubah posisi","zh":"修改持仓"},
    "New order": {"es":"Nueva orden","ar":"أمر جديد","hi":"नया ऑर्डर","tr":"Yeni emir","fr":"Nouvel ordre","id":"Order baru","zh":"新订单"},
    "Chart": {"es":"Gráfico","ar":"الرسم البياني","hi":"चार्ट","tr":"Grafik","fr":"Graphique","id":"Grafik","zh":"图表"},
    "Bulk Operations…": {"es":"Operaciones masivas…","ar":"عمليات جماعية…","hi":"बल्क ऑपरेशन…","tr":"Toplu İşlemler…","fr":"Opérations groupées…","id":"Operasi Massal…","zh":"批量操作…"},
    "Add ticket": {"es":"Agregar ticket","ar":"إضافة تذكرة","hi":"टिकट जोड़ें","tr":"Talep ekle","fr":"Ajouter un ticket","id":"Tambah tiket","zh":"添加工单"},
    "Volume": {"es":"Volumen","ar":"الحجم","hi":"वॉल्यूम","tr":"Hacim","fr":"Volume","id":"Volume","zh":"手数"},
    "Risk Management": {"es":"Gestión de riesgo","ar":"إدارة المخاطر","hi":"जोखिम प्रबंधन","tr":"Risk Yönetimi","fr":"Gestion des risques","id":"Manajemen Risiko","zh":"风险管理"},
    "Modify": {"es":"Modificar","ar":"تعديل","hi":"संशोधित करें","tr":"Düzenle","fr":"Modifier","id":"Ubah","zh":"修改"},
    "Symbol": {"es":"Símbolo","ar":"الرمز","hi":"सिंबल","tr":"Sembol","fr":"Symbole","id":"Simbol","zh":"品种"},
    "Bid": {"es":"Venta","ar":"العرض","hi":"बिड","tr":"Alış","fr":"Vente","id":"Bid","zh":"买价"},
    "Ask": {"es":"Compra","ar":"الطلب","hi":"आस्क","tr":"Satış","fr":"Achat","id":"Ask","zh":"卖价"},
    "No favorites yet": {"es":"Aún no hay favoritos","ar":"لا توجد مفضلة بعد","hi":"अभी कोई पसंदीदा नहीं","tr":"Henüz favori yok","fr":"Aucun favori pour l'instant","id":"Belum ada favorit","zh":"暂无收藏"},
    "Tap  🔍  to search and add symbols": {"es":"Toca  🔍  para buscar y agregar símbolos","ar":"اضغط  🔍  للبحث وإضافة الرموز","hi":"सिंबल खोजने और जोड़ने के लिए  🔍  पर टैप करें","tr":"Sembol aramak ve eklemek için  🔍  öğesine dokunun","fr":"Appuyez sur  🔍  pour rechercher et ajouter des symboles","id":"Ketuk  🔍  untuk mencari dan menambah simbol","zh":"点击  🔍  搜索并添加品种"},
    "Add symbol": {"es":"Agregar símbolo","ar":"إضافة رمز","hi":"सिंबल जोड़ें","tr":"Sembol ekle","fr":"Ajouter un symbole","id":"Tambah simbol","zh":"添加品种"},
    "No results": {"es":"Sin resultados","ar":"لا توجد نتائج","hi":"कोई परिणाम नहीं","tr":"Sonuç yok","fr":"Aucun résultat","id":"Tidak ada hasil","zh":"无结果"},
    "No symbols in this folder": {"es":"No hay símbolos en esta carpeta","ar":"لا توجد رموز في هذا المجلد","hi":"इस फ़ोल्डर में कोई सिंबल नहीं","tr":"Bu klasörde sembol yok","fr":"Aucun symbole dans ce dossier","id":"Tidak ada simbol di folder ini","zh":"此文件夹中没有品种"},
    "Remove symbols": {"es":"Eliminar símbolos","ar":"إزالة الرموز","hi":"सिंबल हटाएं","tr":"Sembolleri kaldır","fr":"Supprimer des symboles","id":"Hapus simbol","zh":"移除品种"},
    "Remove {n} symbol(s) from your watchlist?": {"es":"¿Eliminar {n} símbolo(s) de tu lista?","ar":"إزالة {n} رمز من قائمتك؟","hi":"अपनी वॉचलिस्ट से {n} सिंबल हटाएं?","tr":"İzleme listenizden {n} sembol kaldırılsın mı?","fr":"Supprimer {n} symbole(s) de votre liste ?","id":"Hapus {n} simbol dari watchlist Anda?","zh":"从自选中移除 {n} 个品种？"},
    "Delete": {"es":"Eliminar","ar":"حذف","hi":"हटाएं","tr":"Sil","fr":"Supprimer","id":"Hapus","zh":"删除"},
    "Selected symbols": {"es":"Símbolos seleccionados","ar":"الرموز المحددة","hi":"चयनित सिंबल","tr":"Seçili semboller","fr":"Symboles sélectionnés","id":"Simbol terpilih","zh":"已选品种"},
    "No symbols selected": {"es":"Ningún símbolo seleccionado","ar":"لم يتم تحديد أي رمز","hi":"कोई सिंबल चयनित नहीं","tr":"Sembol seçilmedi","fr":"Aucun symbole sélectionné","id":"Tidak ada simbol dipilih","zh":"未选择品种"},
    "Find symbols": {"es":"Buscar símbolos","ar":"البحث عن الرموز","hi":"सिंबल खोजें","tr":"Sembol bul","fr":"Trouver des symboles","id":"Cari simbol","zh":"查找品种"},
    "Done": {"es":"Listo","ar":"تم","hi":"पूर्ण","tr":"Bitti","fr":"Terminé","id":"Selesai","zh":"完成"},
    "Select all": {"es":"Seleccionar todo","ar":"تحديد الكل","hi":"सभी चुनें","tr":"Tümünü seç","fr":"Tout sélectionner","id":"Pilih semua","zh":"全选"},
    "Search": {"es":"Buscar","ar":"بحث","hi":"खोजें","tr":"Ara","fr":"Rechercher","id":"Cari","zh":"搜索"},
    "Start typing to search": {"es":"Empieza a escribir para buscar","ar":"ابدأ الكتابة للبحث","hi":"खोजने के लिए टाइप करना शुरू करें","tr":"Aramak için yazmaya başlayın","fr":"Commencez à taper pour rechercher","id":"Mulai mengetik untuk mencari","zh":"输入以搜索"},
    "Empty history": {"es":"Historial vacío","ar":"السجل فارغ","hi":"इतिहास खाली है","tr":"Geçmiş boş","fr":"Historique vide","id":"Riwayat kosong","zh":"暂无历史记录"},
    "Retry": {"es":"Reintentar","ar":"إعادة المحاولة","hi":"पुनः प्रयास करें","tr":"Tekrar dene","fr":"Réessayer","id":"Coba lagi","zh":"重试"},
    "Balance": {"es":"Saldo","ar":"الرصيد","hi":"बैलेंस","tr":"Bakiye","fr":"Solde","id":"Saldo","zh":"余额"},
    "S / L:": {"es":"S / L:","ar":"وقف الخسارة:","hi":"S / L:","tr":"S / L:","fr":"S / L :","id":"S / L:","zh":"止损："},
    "T / P:": {"es":"T / P:","ar":"جني الأرباح:","hi":"T / P:","tr":"T / P:","fr":"T / P :","id":"T / P:","zh":"止盈："},
    "Open:": {"es":"Apertura:","ar":"الفتح:","hi":"ओपन:","tr":"Açılış:","fr":"Ouverture :","id":"Buka:","zh":"开仓："},
    "Swap:": {"es":"Swap:","ar":"السواب:","hi":"स्वैप:","tr":"Swap:","fr":"Swap :","id":"Swap:","zh":"隔夜利息："},
    "Commission:": {"es":"Comisión:","ar":"العمولة:","hi":"कमीशन:","tr":"Komisyon:","fr":"Commission :","id":"Komisi:","zh":"佣金："},
    "Loading more…": {"es":"Cargando más…","ar":"جارٍ تحميل المزيد…","hi":"और लोड हो रहा है…","tr":"Daha fazla yükleniyor…","fr":"Chargement…","id":"Memuat lebih banyak…","zh":"加载更多…"},
    "SELECT PERIOD": {"es":"SELECCIONAR PERÍODO","ar":"اختر الفترة","hi":"अवधि चुनें","tr":"DÖNEM SEÇ","fr":"SÉLECTIONNER LA PÉRIODE","id":"PILIH PERIODE","zh":"选择周期"},
    "SORT COLUMNS": {"es":"ORDENAR COLUMNAS","ar":"ترتيب الأعمدة","hi":"कॉलम सॉर्ट करें","tr":"SÜTUNLARI SIRALA","fr":"TRIER LES COLONNES","id":"URUTKAN KOLOM","zh":"排序列"},
    "SELECT SYMBOL": {"es":"SELECCIONAR SÍMBOLO","ar":"اختر الرمز","hi":"सिंबल चुनें","tr":"SEMBOL SEÇ","fr":"SÉLECTIONNER LE SYMBOLE","id":"PILIH SIMBOL","zh":"选择品种"},
    "Select symbol": {"es":"Seleccionar símbolo","ar":"اختر الرمز","hi":"सिंबल चुनें","tr":"Sembol seç","fr":"Sélectionner le symbole","id":"Pilih simbol","zh":"选择品种"},
    "Sort columns": {"es":"Ordenar columnas","ar":"ترتيب الأعمدة","hi":"कॉलम सॉर्ट करें","tr":"Sütunları sırala","fr":"Trier les colonnes","id":"Urutkan kolom","zh":"排序列"},
    "Modify failed: {e}": {"es":"Modificación fallida: {e}","ar":"فشل التعديل: {e}","hi":"संशोधन विफल: {e}","tr":"Düzenleme başarısız: {e}","fr":"Échec de la modification : {e}","id":"Gagal mengubah: {e}","zh":"修改失败：{e}"},
    "Auto SL/TP Calculator": {"es":"Calculadora automática de SL/TP","ar":"حاسبة SL/TP التلقائية","hi":"ऑटो SL/TP कैलकुलेटर","tr":"Otomatik SL/TP Hesaplayıcı","fr":"Calculateur auto SL/TP","id":"Kalkulator Otomatis SL/TP","zh":"自动止损/止盈计算器"},
    "Apply": {"es":"Aplicar","ar":"تطبيق","hi":"लागू करें","tr":"Uygula","fr":"Appliquer","id":"Terapkan","zh":"应用"},
    "Stop Loss": {"es":"Stop Loss","ar":"وقف الخسارة","hi":"स्टॉप लॉस","tr":"Zarar Durdur","fr":"Stop Loss","id":"Stop Loss","zh":"止损"},
    "Take Profit": {"es":"Take Profit","ar":"جني الأرباح","hi":"टेक प्रॉफिट","tr":"Kâr Al","fr":"Take Profit","id":"Take Profit","zh":"止盈"},
    "Waiting for ticks…": {"es":"Esperando cotizaciones…","ar":"في انتظار الأسعار…","hi":"टिक्स की प्रतीक्षा…","tr":"Fiyatlar bekleniyor…","fr":"En attente des cours…","id":"Menunggu tick…","zh":"等待报价…"},
    "No history for {period}": {"es":"Sin historial para {period}","ar":"لا يوجد سجل لـ {period}","hi":"{period} के लिए कोई इतिहास नहीं","tr":"{period} için geçmiş yok","fr":"Aucun historique pour {period}","id":"Tidak ada riwayat untuk {period}","zh":"{period} 无历史记录"},
    "Privacy Policy": {"es":"Política de privacidad","ar":"سياسة الخصوصية","hi":"गोपनीयता नीति","tr":"Gizlilik Politikası","fr":"Politique de confidentialité","id":"Kebijakan Privasi","zh":"隐私政策"},
    "Create Trading Account": {"es":"Crear cuenta de trading","ar":"إنشاء حساب تداول","hi":"ट्रेडिंग खाता बनाएं","tr":"İşlem Hesabı Oluştur","fr":"Créer un compte de trading","id":"Buat Akun Trading","zh":"创建交易账户"},
    "Referrer Code": {"es":"Código de referido","ar":"رمز الإحالة","hi":"रेफ़रर कोड","tr":"Referans Kodu","fr":"Code de parrainage","id":"Kode Referal","zh":"推荐码"},
    "Create New Password": {"es":"Crear nueva contraseña","ar":"إنشاء كلمة مرور جديدة","hi":"नया पासवर्ड बनाएं","tr":"Yeni Şifre Oluştur","fr":"Créer un nouveau mot de passe","id":"Buat Kata Sandi Baru","zh":"创建新密码"},
    "Your new password must be different from previously used passwords.": {"es":"Tu nueva contraseña debe ser diferente de las anteriores.","ar":"يجب أن تكون كلمة المرور الجديدة مختلفة عن السابقة.","hi":"आपका नया पासवर्ड पहले इस्तेमाल किए गए पासवर्ड से अलग होना चाहिए।","tr":"Yeni şifreniz önceki şifrelerden farklı olmalıdır.","fr":"Votre nouveau mot de passe doit être différent des précédents.","id":"Kata sandi baru harus berbeda dari yang sebelumnya.","zh":"新密码必须与以前使用的密码不同。"},
    "Enter new password": {"es":"Ingresa la nueva contraseña","ar":"أدخل كلمة المرور الجديدة","hi":"नया पासवर्ड दर्ज करें","tr":"Yeni şifreyi girin","fr":"Saisissez le nouveau mot de passe","id":"Masukkan kata sandi baru","zh":"输入新密码"},
    "Confirm new password": {"es":"Confirma la nueva contraseña","ar":"أكد كلمة المرور الجديدة","hi":"नया पासवर्ड पुष्टि करें","tr":"Yeni şifreyi onaylayın","fr":"Confirmez le nouveau mot de passe","id":"Konfirmasi kata sandi baru","zh":"确认新密码"},
    "New Password": {"es":"Nueva contraseña","ar":"كلمة مرور جديدة","hi":"नया पासवर्ड","tr":"Yeni Şifre","fr":"Nouveau mot de passe","id":"Kata Sandi Baru","zh":"新密码"},
    "Confirm Password": {"es":"Confirmar contraseña","ar":"تأكيد كلمة المرور","hi":"पासवर्ड पुष्टि करें","tr":"Şifreyi Onayla","fr":"Confirmer le mot de passe","id":"Konfirmasi Kata Sandi","zh":"确认密码"},
    "WatchList": {"es":"Lista de seguimiento","ar":"قائمة المتابعة","hi":"वॉचलिस्ट","tr":"İzleme Listesi","fr":"Liste de suivi","id":"Watchlist","zh":"自选"},
    "Tap  🔍  to add symbols": {"es":"Toca  🔍  para agregar símbolos","ar":"اضغط  🔍  لإضافة الرموز","hi":"सिंबल जोड़ने के लिए  🔍  पर टैप करें","tr":"Sembol eklemek için  🔍  öğesine dokunun","fr":"Appuyez sur  🔍  pour ajouter des symboles","id":"Ketuk  🔍  untuk menambah simbol","zh":"点击  🔍  添加品种"},
    "SELL": {"es":"VENDER","ar":"بيع","hi":"बेचें","tr":"SAT","fr":"VENDRE","id":"JUAL","zh":"卖出"},
    "BUY": {"es":"COMPRAR","ar":"شراء","hi":"खरीदें","tr":"AL","fr":"ACHETER","id":"BELI","zh":"买入"},
    "PLACE": {"es":"COLOCAR","ar":"تنفيذ","hi":"लगाएं","tr":"GÖNDER","fr":"PLACER","id":"PASANG","zh":"下单"},
    "Stop Loss or Take Profit you set must differ from market price by at least 20 points. Stops processing is performed on the broker side.": {"es":"El Stop Loss o Take Profit debe diferir del precio de mercado en al menos 20 puntos. El procesamiento se realiza del lado del bróker.","ar":"يجب أن يختلف وقف الخسارة أو جني الأرباح عن سعر السوق بما لا يقل عن 20 نقطة. تتم معالجة الأوامر من جانب الوسيط.","hi":"आपके द्वारा सेट किया गया स्टॉप लॉस या टेक प्रॉफिट मार्केट प्राइस से कम से कम 20 पॉइंट अलग होना चाहिए। स्टॉप प्रोसेसिंग ब्रोकर की ओर से होती है।","tr":"Belirlediğiniz Zarar Durdur veya Kâr Al, piyasa fiyatından en az 20 puan farklı olmalıdır. İşlem, aracı kurum tarafında gerçekleştirilir.","fr":"Le Stop Loss ou Take Profit doit différer du prix du marché d'au moins 20 points. Le traitement est effectué du côté du courtier.","id":"Stop Loss atau Take Profit yang Anda tetapkan harus berbeda dari harga pasar minimal 20 poin. Pemrosesan dilakukan di sisi broker.","zh":"您设置的止损或止盈必须与市场价格相差至少 20 个点。止损处理由经纪商方执行。"},
    "MODIFY": {"es":"MODIFICAR","ar":"تعديل","hi":"संशोधित करें","tr":"DÜZENLE","fr":"MODIFIER","id":"UBAH","zh":"修改"},
    "Modify position #{id}": {"es":"Modificar posición #{id}","ar":"تعديل المركز #{id}","hi":"पोज़िशन संशोधित करें #{id}","tr":"Pozisyonu düzenle #{id}","fr":"Modifier la position #{id}","id":"Ubah posisi #{id}","zh":"修改持仓 #{id}"},
    "CURRENT": {"es":"ACTUAL","ar":"الحالي","hi":"वर्तमान","tr":"MEVCUT","fr":"ACTUEL","id":"SAAT INI","zh":"当前"},
    "PRICE": {"es":"PRECIO","ar":"السعر","hi":"मूल्य","tr":"FİYAT","fr":"PRIX","id":"HARGA","zh":"价格"},
    "VOLUME": {"es":"VOLUMEN","ar":"الحجم","hi":"वॉल्यूम","tr":"HACİM","fr":"VOLUME","id":"VOLUME","zh":"手数"},
}

# typo guard fix
T["Support Tickets"]["ar"] = "تذاكر الدعم"

LANGS = ['es', 'ar', 'hi', 'tr']  # existing files to complete in this batch

# placeholder-only detector: value has no ascii letters -> keep as-is everywhere
def is_passthrough(v):
    return not re.search(r'[A-Za-z]', v)

missing = {k: en[k] for k in en}  # we'll compute per-file

report_untranslated = set()
for lang in LANGS:
    path = os.path.join(TRANS_DIR, f'{lang}.json')
    data = json.load(open(path, encoding='utf-8'))
    added = 0
    for k, ev in en.items():
        if k in data:
            continue
        if is_passthrough(ev):
            data[k] = ev
        elif ev in T:
            data[k] = T[ev][lang]
        else:
            report_untranslated.add(ev)
            data[k] = ev  # fallback to English, flagged below
        added += 1
    json.dump(data, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    # keep trailing newline
    open(path, 'a', encoding='utf-8').write('\n')
    print(f'{lang}: +{added} keys, total {len(data)}')

if report_untranslated:
    print('\n!! NO TRANSLATION MAPPED (left as English) — add to T dict:')
    for v in sorted(report_untranslated):
        print('   ', repr(v))
else:
    print('\nAll missing keys translated.')

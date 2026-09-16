Config = {}

-- Yetkili Grupları (QBCore veya ACE)
Config.AdminGroups = {
    ['god'] = true,
    ['admin'] = true,
}

-- ACE İzni
Config.CommandPrincipal = 'group.admin'

-- Komut İsimleri
Config.Commands = {
    addStash = 'addstash',      -- Doğrudan prop hedefleme (raycast) modunu başlatır
    stashMenu = 'stashmenu',    -- Kasa yönetim ve oluşturma menüsünü açar
    stashAdmin = 'stashadmin',  -- Alternatif menü komutu
}

-- Varsayılan Değerler
Config.Defaults = {
    slots = 50,             -- Varsayılan slot sayısı
    weight = 100,           -- Varsayılan ağırlık (KG cinsinden)
    distance = 2.0,         -- Varsayılan etkileşim mesafesi (metre)
    maxRaycastDist = 15.0,  -- Prop seçimi için maksimum raycast mesafesi
}

-- Prop Seçimi Sırasında Çizim Renkleri
Config.OutlineColor = { r = 0, g = 255, b = 180, a = 255 } -- Hedeflenen prop outline rengi (Cyan/Yeşil)
Config.MarkerColor = { r = 0, g = 200, b = 255, a = 180 }  -- Raycast nokta rengi

-- Türkçe Bildirim ve Metinler
Config.Locales = {
    ['raycast_textui'] = '**[SOL TIK] / [E]** : Propu Seç  \n**[SAĞ TIK] / [ESC]** : İptal Et',
    ['raycast_canceled'] = 'Kasa oluşturma / prop seçimi iptal edildi.',
    ['no_entity_selected'] = 'Lütfen bir prop veya objeye nişan alın.',
    ['prop_selected'] = 'Prop seçildi (Model: %s). Kasa ayarlarını doldurunuz.',
    ['dialog_title'] = '📦 Yeni Kasa Oluştur',
    ['stash_id_label'] = 'Kasa ID (Benzersiz İsim)',
    ['stash_id_desc'] = 'Örnek: police_armory_1, market_kasa_2',
    ['stash_label'] = 'Kasa Başlığı / Görünen İsim',
    ['stash_label_desc'] = 'Örnek: Polis Kasası, Depo',
    ['slots_label'] = 'Slot Sayısı',
    ['slots_desc'] = 'Kasada bulunacak toplam yuva sayısı (1-500)',
    ['weight_label'] = 'Maksimum Ağırlık (KG)',
    ['weight_desc'] = 'Kasanın taşıyabileceği azami ağırlık (KG)',
    ['job_label'] = 'Meslek İzni (İsteğe Bağlı)',
    ['job_desc'] = 'Örnek: police, ambulance, mechanic (Herkese açık için boş bırakın)',
    ['grade_label'] = 'Minimum Meslek Rütbesi',
    ['grade_desc'] = 'Kasanın açılabileceği asgari rütbe (0 = her rütbe)',
    ['personal_label'] = 'Kişiye Özel Kasa',
    ['personal_desc'] = 'Açan her oyuncunun kendine ait özel kasası olur.',
    ['pincode_label'] = 'PIN Kodu / Şifre (İsteğe Bağlı)',
    ['pincode_desc'] = 'Kasayı açmak için girilmesi gereken şifre (Boş = Şifresiz)',
    ['distance_label'] = 'Hedefleme / Etkileşim Mesafesi (Metre)',
    ['distance_desc'] = 'Kasaya yaklaşma mesafesi (Ör: 2.0)',
    ['create_success'] = 'Kasa başarıyla oluşturuldu ve propa bağlandı! ID: %s',
    ['create_failed'] = 'Kasa oluşturulamadı: %s',
    ['already_exists'] = 'Bu Kasa ID zaten kullanımda! Lütfen farklı bir ID girin.',
    ['missing_fields'] = 'Lütfen zorunlu alanları (ID, Başlık, Slot, Ağırlık) eksiksiz doldurun.',
    ['no_permission'] = 'Bu komutu kullanmak için yetkiniz bulunmuyor!',
    ['open_stash_target'] = '%s Aç',
    ['pin_prompt_title'] = '🔒 Kasa Şifresi',
    ['pin_prompt_desc'] = 'Kasaya erişmek için PIN kodunu giriniz:',
    ['wrong_pin'] = 'Hatalı şifre girdiniz!',
    ['no_job_access'] = 'Bu kasaya erişmek için gerekli meslek yetkisine sahip değilsiniz!',
    ['menu_title'] = '📦 Kasa Yönetim Sistemi',
    ['menu_add_stash'] = '➕ Yeni Kasa Ekle (Prop Seç)',
    ['menu_add_stash_desc'] = 'Kameranızı bir propa tutarak yeni kasa oluşturun',
    ['menu_list_stashes'] = '📋 Mevcut Kasaları Listele (%s Adet)',
    ['menu_list_stashes_desc'] = 'Oluşturulmuş tüm kasaları görüntüleyin, düzenleyin veya silin',
    ['stash_info'] = '**Kasa ID:** %s  \n**Slot:** %d | **Ağırlık:** %s KG  \n**Meslek:** %s  \n**Kişisel:** %s | **Şifre:** %s',
    ['teleport_to_stash'] = '📍 Kasaya Işınlan',
    ['open_stash_admin'] = '🔓 Kasayı Aç (İçeriği İncele)',
    ['edit_stash'] = '✏️ Kasa Bilgilerini Düzenle',
    ['delete_stash'] = '🗑️ Kasayı Sil',
    ['delete_confirm_title'] = 'Kasayı Silmek İstediğinize Emin misiniz?',
    ['delete_confirm_desc'] = '"%s" kasası ve içindeki tüm veriler kalıcı olarak silinecektir.',
    ['delete_success'] = 'Kasa başarıyla silindi!',
    ['update_success'] = 'Kasa bilgileri başarıyla güncellendi!',
}

#!/usr/bin/env python3
"""Generates Mosaikk's pages for tang-spark.no in English, Simplified and Traditional Chinese.

    website/generate.py            # writes website/dist/*.html

The pages use the site's own styles.css (the Plakat layout shared with Spolo, Rydd, Kvikkshot and Glimt).
The version comes from project.yml. Set APP_STORE_URL once the app is live to show the
Mac App Store button; the download button appears when publish-website.sh copies a notarized disk image.
"""
import html
import os
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIST = ROOT / "website" / "dist"
VERSION = re.search(r'MARKETING_VERSION: "([^"]+)"', (ROOT / "project.yml").read_text()).group(1)
APP_STORE_URL = ""
# scripts/publish-website.sh sets this when it copies a notarized disk image to the site.
DOWNLOAD_URL = os.environ.get("MOSAIKK_DOWNLOAD_URL", "")
GITHUB = "https://github.com/tangfy97/Mosaikk"

LANGS = {
    "en": {"suffix": "", "html": "en", "other": [("zh-cn", "中文")]},
    "zh-cn": {"suffix": "-zh-cn", "html": "zh-Hans", "other": [("en", "EN"), ("zh-tw", "繁體")]},
    "zh-tw": {"suffix": "-zh-tw", "html": "zh-Hant", "other": [("en", "EN"), ("zh-cn", "简体")]},
}

COPY = {
    "en": {
        "title": "Mosaikk — Photo collages, shaped by hand.",
        "description": "Mosaikk makes photo collages on your Mac. Pick a layout, drop in your photos and drag the borders until it looks right; add text, stickers and a background, and export at any size. Free, private and offline.",
        "label": "macOS 14+ · Free",
        "headline": "Photo collages, shaped by hand.",
        "lead": "Pick one of over 200 layouts, drop in your photos and drag the borders between them until it looks right. Add words, stickers and a background, and export a picture at any size, right on your Mac. Mosaikk is Norwegian for mosaic.",
        "facts": [("Platform", "macOS 14 or later"), ("Price", "Free"), ("Network", "None at all"), ("Languages", "EN, 简体, 繁體")],
        "shot_alt": "Mosaikk with a six-photo layout and a text style being edited",
        "what": "What it does",
        "features": [
            ("Layouts", "Grids, feature layouts and mosaics for 1 to 25 photos, shaped frames, and freeform collages where photos lie loose like prints."),
            ("Drag the borders", "Resize cells by dragging the lines between them. Split, delete or add cells, or make them all even again."),
            ("Each photo", "Drag to choose the crop, zoom, turn and flip; drag onto another cell to swap. 16 filters and 12 adjustments."),
            ("Words and stickers", "Any font on your Mac with outline, shadow, glow and highlight, typed on the collage. Shapes, badges and emoji."),
            ("Any size", "Colours, gradients, patterns or a blurred photo behind. Social, print and custom sizes; PNG, JPEG or HEIC."),
        ],
        "get": "Get Mosaikk",
        "get_text_store": "Free on the Mac App Store, and as a signed, notarized download.",
        "get_text_download": "Free, as a signed and notarized download. Coming soon to the Mac App Store.",
        "get_text_soon": "Free. Coming soon to the Mac App Store.",
        "btn_store": "Mac App Store", "btn_download": "Download for Mac", "btn_source": "Source on GitHub", "btn_support": "Support & privacy",
        "nav_apps": "Apps", "nav_support": "Support",
        "s_title": "Mosaikk support, privacy and terms",
        "s_hero": "Support",
        "s_headline": "Support, privacy and terms.",
        "s_lead": "Answers to common questions, the privacy policy and the terms. If something isn't covered here, write to us and we'll reply.",
        "s_facts": [("Version", VERSION), ("Data collected", "None"), ("Network", "None at all"), ("Contact", '<a href="mailto:support@tang-spark.no">support@tang-spark.no</a>')],
        "toc": [("start", "Getting started"), ("faq", "Questions"), ("privacy", "Privacy"), ("terms", "Terms"), ("release-notes", "Release notes"), ("contact", "Contact")],
        "start": [
            "Open Mosaikk: a new collage with three empty cells is ready. Pick another layout on the left if you like; the list shows layouts for as many photos as you have added.",
            "Click a + in a cell, choose File › Add Photos…, or drag pictures from the Finder or Photos onto the window. They fill the empty cells in order.",
            "Drag the lines between photos to resize them, and drag inside a photo to choose what shows. Add text, stickers and a background from the sidebar, then choose File › Export….",
        ],
        "faq": [
            ("How do I swap two photos?", "Drag a photo out of its cell and drop it on another. Dragging inside the cell moves the photo within it instead."),
            ("Why do several borders move together?", "Borders that line up across the whole grid, such as a column line, move together so it stays straight. Hold ⌥ (Option) while dragging to move just one."),
            ("Which picture formats can I add?", "Anything macOS can open: JPEG, PNG, HEIC, TIFF, WebP, AVIF, GIF, BMP and RAW photos."),
            ("Where are my collages kept?", "A collage is a document: choose File › Save to keep it as a .mosaikk file wherever you like. The file holds copies of your photos, so it still opens if the originals move, and on another Mac. Until you save, Mosaikk keeps untitled collages for you, and they come back after you quit."),
            ("Does Mosaikk take up space over time?", "No. Previews are kept in memory only. Temporary files are removed after use, and copies of untitled collages that no window will open again are cleaned up when Mosaikk starts."),
            ("How large can I export?", "Up to 12,000 pixels on the longer side, as PNG, JPEG or HEIC. PNG and HEIC keep a transparent background."),
            ("Is there a watermark or a limit?", "No watermark. A collage can hold up to 500 pictures."),
            ("How do I update?", "The Mac App Store version updates through the App Store. In the downloaded version, choose Help › Check for a New Version…; it opens this website in your browser, because Mosaikk itself never goes online."),
            ("How do I uninstall it?", "Quit Mosaikk and drag it from Applications to the Bin. Its settings and any untitled collages are in ~/Library/Containers/com.feiyangtang.Mosaikk, which you can delete too. Collages you saved stay where you saved them."),
        ],
        "privacy_title": "Privacy policy",
        "privacy": [
            "Last updated 12 November 2026. This policy covers the Mac App Store version and the version downloaded from this website.",
            "<b>Mosaikk collects no data.</b> It has no network access: the App Sandbox does not let it connect to the internet. There are no accounts, analytics, telemetry, crash reporting, advertising or update checks, and no third-party code.",
            "Mosaikk reads the pictures you add, to show them and put them in your collage. A saved collage is a .mosaikk file in the place you choose, holding unchanged copies of the pictures you added so it can be edited later. Their metadata, such as the date or place a photo was taken, stays in those copies; exported images don't include it.",
            "Photos you add from your Photos library are chosen in the system's photo picker, so Mosaikk never has access to the library itself.",
            "Mosaikk writes files only where you ask, and keeps untitled collages in its own folder until you save or delete them. Links in the Help menu open in your browser, outside Mosaikk. Check for a New Version tells this website which version you have, so it can say whether a newer one exists.",
            "Mosaikk is suitable for all ages and collects nothing from anyone, including children. Questions about privacy: support@tang-spark.no.",
        ],
        "terms_title": "Terms",
        "terms": [
            "Mosaikk is free. You may use it for personal and commercial work.",
            "It is provided as is, without warranty. Mosaikk never changes the pictures you add, but TangSpark is not liable for loss of data or other damages from using it, as far as the law allows.",
            "You are responsible for having the rights to the pictures you use. Mac App Store downloads are also covered by Apple's standard licence agreement.",
        ],
        "notes_title": "Release notes",
        "notes": [
            ("Version 1.0.0", "November 2026", "First release: over 200 layouts with draggable borders, shaped frames and freeform collages; crop, filters and adjustments for each photo; text, stickers and backgrounds; social, print and custom sizes; PNG, JPEG and HEIC export; four languages."),
        ],
        "contact_title": "Contact",
        "contact": "Write to <a href=\"mailto:support@tang-spark.no\">support@tang-spark.no</a>. It helps to include your macOS version and the Mosaikk version (Mosaikk menu › About Mosaikk).",
        "footer_support": "Support & privacy",
    },
    "zh-cn": {
        "title": "Mosaikk — 亲手拼出的照片拼贴。",
        "description": "Mosaikk 在你的 Mac 上制作照片拼贴。选一个布局，放入照片，拖动边框直到满意；再加上文字、贴纸和背景，以任意尺寸导出。免费、私密、离线。",
        "label": "macOS 14+ · 免费",
        "headline": "亲手拼出的照片拼贴。",
        "lead": "从 200 多个布局中选一个，放入照片，拖动照片之间的边框，直到看起来刚刚好。加上文字、贴纸和背景，在你的 Mac 上导出任意尺寸的图片。Mosaikk 是挪威语里“马赛克”的意思。",
        "facts": [("平台", "macOS 14 或更新版本"), ("价格", "免费"), ("网络", "完全不联网"), ("语言", "EN, 简体, 繁體")],
        "shot_alt": "Mosaikk 中的六张照片布局，正在编辑文字样式",
        "what": "它能做什么",
        "features": [
            ("布局", "1 到 25 张照片的网格、主图布局和马赛克，带形状的相框，还有像散放照片一样的自由排列。"),
            ("拖动边框", "拖动格子之间的线来调整大小。可以分割、删除或增加格子，也能一键让它们等大。"),
            ("每张照片", "拖动选择裁剪范围，缩放、旋转、翻转；拖到另一个格子上就能交换。16 种滤镜和 12 项调整。"),
            ("文字和贴纸", "Mac 上的任何字体，带描边、阴影、发光和底色，直接在拼贴上输入。还有形状、徽章和表情符号。"),
            ("任意尺寸", "纯色、渐变、图案或模糊照片做背景。社交媒体、打印和自定尺寸；导出 PNG、JPEG 或 HEIC。"),
        ],
        "get": "获取 Mosaikk",
        "get_text_store": "可在 Mac App Store 免费获取，也可以下载经过签名和公证的版本。",
        "get_text_download": "免费下载，经过签名和公证。即将登陆 Mac App Store。",
        "get_text_soon": "免费。即将登陆 Mac App Store。",
        "btn_store": "Mac App Store", "btn_download": "下载 Mac 版", "btn_source": "GitHub 源代码", "btn_support": "支持与隐私",
        "nav_apps": "Apps", "nav_support": "支持",
        "s_title": "Mosaikk 支持、隐私与条款",
        "s_hero": "支持",
        "s_headline": "支持、隐私与条款。",
        "s_lead": "常见问题、隐私政策和使用条款。如果这里没有你要的答案，请写信给我们。",
        "s_facts": [("版本", VERSION), ("收集的数据", "无"), ("网络", "完全不联网"), ("联系", '<a href="mailto:support@tang-spark.no">support@tang-spark.no</a>')],
        "toc": [("start", "开始使用"), ("faq", "常见问题"), ("privacy", "隐私"), ("terms", "条款"), ("release-notes", "更新说明"), ("contact", "联系")],
        "start": [
            "打开 Mosaikk，一个带三个空格子的新拼贴已经准备好。也可以在左边选择其他布局；列表会显示适合你已添加照片数量的布局。",
            "点按格子里的 +，选择“文件 › 添加照片…”，或者从“访达”或“照片”把图片拖到窗口里。它们会按顺序填入空格子。",
            "拖动照片之间的线来调整大小，在照片里拖动来选择显示的部分。从边栏添加文字、贴纸和背景，然后选择“文件 › 导出…”。",
        ],
        "faq": [
            ("怎么交换两张照片？", "把照片拖出它的格子，放到另一个格子上。在格子里拖动则是移动照片的显示位置。"),
            ("为什么几条边框会一起移动？", "贯穿整个网格、对齐在一条线上的边框（比如一整列的竖线）会一起移动，保持笔直。拖动时按住 ⌥（Option）可以只移动其中一段。"),
            ("可以添加哪些图片格式？", "macOS 能打开的都可以：JPEG、PNG、HEIC、TIFF、WebP、AVIF、GIF、BMP 和 RAW 照片。"),
            ("拼贴保存在哪里？", "拼贴是一个文稿：选择“文件 › 存储”，把它存成 .mosaikk 文件，放在你想要的位置。文件里包含照片的副本，所以即使原图移动了、或者换一台 Mac，也能打开。保存之前，Mosaikk 会替你保留未命名的拼贴，退出后再打开还在。"),
            ("Mosaikk 会越用越占空间吗？", "不会。预览只保存在内存里。临时文件用完就删除；没有任何窗口会再打开的未命名拼贴副本，会在 Mosaikk 启动时清理掉。"),
            ("最大能导出多大？", "长边最多 12,000 像素，格式为 PNG、JPEG 或 HEIC。PNG 和 HEIC 可以保留透明背景。"),
            ("有水印或限制吗？", "没有水印。一个拼贴最多可以放 500 张图片。"),
            ("怎么更新？", "Mac App Store 版本通过 App Store 更新。下载版请选择“帮助 › 检查新版本…”，它会在浏览器中打开这个网站，因为 Mosaikk 自己从不联网。"),
            ("怎么卸载？", "退出 Mosaikk，把它从“应用程序”拖到废纸篓。它的设置和未命名的拼贴在 ~/Library/Containers/com.feiyangtang.Mosaikk，也可以一起删除。你保存过的拼贴仍然在你保存的位置。"),
        ],
        "privacy_title": "隐私政策",
        "privacy": [
            "最后更新：2026 年 11 月 12 日。本政策适用于 Mac App Store 版本和从本网站下载的版本。",
            "<b>Mosaikk 不收集任何数据。</b>它完全没有网络权限：App 沙盒不允许它连接互联网。没有账号、统计、遥测、崩溃报告、广告或更新检查，也没有任何第三方代码。",
            "Mosaikk 读取你添加的图片，用来显示并放进你的拼贴。保存的拼贴是一个 .mosaikk 文件，放在你选择的位置，里面是你添加的图片的原样副本，以便以后继续编辑。照片的元数据（如拍摄时间和地点）会留在这些副本里；导出的图片不包含这些信息。",
            "从“照片”图库添加的照片是在系统的照片选择器里挑选的，Mosaikk 从来无法访问图库本身。",
            "Mosaikk 只在你指定的地方写入文件，并在你保存或删除之前，把未命名的拼贴保存在它自己的文件夹里。“帮助”菜单中的链接会在浏览器中打开，与 Mosaikk 无关。“检查新版本”会把你的版本号告诉本网站，以便显示是否有新版本。",
            "Mosaikk 适合所有年龄，不收集任何人的数据，包括儿童。隐私相关问题：support@tang-spark.no。",
        ],
        "terms_title": "使用条款",
        "terms": [
            "Mosaikk 免费，可用于个人和商业用途。",
            "Mosaikk 按“现状”提供，不附带任何保证。Mosaikk 从不修改你添加的图片；但在法律允许的范围内，TangSpark 不对因使用本软件造成的数据丢失或其他损失负责。",
            "你需要拥有所用图片的相应权利。从 Mac App Store 下载的版本同时适用 Apple 的标准许可协议。",
        ],
        "notes_title": "更新说明",
        "notes": [
            ("版本 1.0.0", "2026 年 11 月", "首次发布：200 多个可拖动边框的布局、形状相框和自由排列；每张照片的裁剪、滤镜和调整；文字、贴纸和背景；社交媒体、打印和自定尺寸；导出 PNG、JPEG 和 HEIC；四种语言。"),
        ],
        "contact_title": "联系",
        "contact": "请写信至 <a href=\"mailto:support@tang-spark.no\">support@tang-spark.no</a>。附上 macOS 版本和 Mosaikk 版本（Mosaikk 菜单 › 关于 Mosaikk）会很有帮助。",
        "footer_support": "支持与隐私",
    },
    "zh-tw": {
        "title": "Mosaikk — 親手拼出的照片拼貼。",
        "description": "Mosaikk 在你的 Mac 上製作照片拼貼。選一個佈局，放入照片，拖移邊框直到滿意；再加上文字、貼紙和背景，以任意尺寸輸出。免費、私密、離線。",
        "label": "macOS 14+ · 免費",
        "headline": "親手拼出的照片拼貼。",
        "lead": "從 200 多個佈局中選一個，放入照片，拖移照片之間的邊框，直到看起來剛剛好。加上文字、貼紙和背景，在你的 Mac 上輸出任意尺寸的圖片。Mosaikk 是挪威語「馬賽克」的意思。",
        "facts": [("平台", "macOS 14 或以上版本"), ("價格", "免費"), ("網路", "完全不連網"), ("語言", "EN, 简体, 繁體")],
        "shot_alt": "Mosaikk 中的六張照片佈局，正在編輯文字樣式",
        "what": "它能做什麼",
        "features": [
            ("佈局", "1 到 25 張照片的格線、主圖佈局和馬賽克，帶形狀的相框，還有像散放照片一樣的自由排列。"),
            ("拖移邊框", "拖移格子之間的線來調整大小。可以分割、刪除或加入格子，也能一鍵讓它們等大。"),
            ("每張照片", "拖移選擇裁切範圍，縮放、旋轉、翻轉；拖到另一個格子上就能交換。16 種濾鏡和 12 項調整。"),
            ("文字和貼紙", "Mac 上的任何字體，帶描邊、陰影、發光和底色，直接在拼貼上輸入。還有形狀、徽章和表情符號。"),
            ("任意尺寸", "純色、漸層、圖樣或模糊照片做背景。社群媒體、列印和自訂尺寸；輸出 PNG、JPEG 或 HEIC。"),
        ],
        "get": "取得 Mosaikk",
        "get_text_store": "可在 Mac App Store 免費取得，也可以下載經過簽署和公證的版本。",
        "get_text_download": "免費下載，經過簽署和公證。即將登上 Mac App Store。",
        "get_text_soon": "免費。即將登上 Mac App Store。",
        "btn_store": "Mac App Store", "btn_download": "下載 Mac 版", "btn_source": "GitHub 原始碼", "btn_support": "支援與隱私",
        "nav_apps": "Apps", "nav_support": "支援",
        "s_title": "Mosaikk 支援、隱私與條款",
        "s_hero": "支援",
        "s_headline": "支援、隱私與條款。",
        "s_lead": "常見問題、隱私權政策和使用條款。如果這裡沒有你要的答案，請寫信給我們。",
        "s_facts": [("版本", VERSION), ("收集的資料", "無"), ("網路", "完全不連網"), ("聯絡", '<a href="mailto:support@tang-spark.no">support@tang-spark.no</a>')],
        "toc": [("start", "開始使用"), ("faq", "常見問題"), ("privacy", "隱私"), ("terms", "條款"), ("release-notes", "版本說明"), ("contact", "聯絡")],
        "start": [
            "打開 Mosaikk，一個帶三個空格子的新拼貼已經準備好。也可以在左邊選擇其他佈局；列表會顯示適合你已加入照片數量的佈局。",
            "按一下格子裡的 +，選擇「檔案 › 加入照片⋯」，或從「Finder」或「照片」把圖片拖到視窗裡。它們會按順序填入空格子。",
            "拖移照片之間的線來調整大小，在照片裡拖移來選擇顯示的部分。從側邊欄加入文字、貼紙和背景，然後選擇「檔案 › 輸出⋯」。",
        ],
        "faq": [
            ("怎麼交換兩張照片？", "把照片拖出它的格子，放到另一個格子上。在格子裡拖移則是移動照片的顯示位置。"),
            ("為什麼幾條邊框會一起移動？", "貫穿整個格線、對齊在一條線上的邊框（例如一整欄的直線）會一起移動，保持筆直。拖移時按住 ⌥（Option）可以只移動其中一段。"),
            ("可以加入哪些圖片格式？", "macOS 能打開的都可以：JPEG、PNG、HEIC、TIFF、WebP、AVIF、GIF、BMP 和 RAW 照片。"),
            ("拼貼儲存在哪裡？", "拼貼是一份文件：選擇「檔案 › 儲存」，把它存成 .mosaikk 檔案，放在你想要的位置。檔案裡包含照片的副本，所以即使原圖移動了、或換一台 Mac，也能打開。儲存之前，Mosaikk 會替你保留未命名的拼貼，結束後再打開還在。"),
            ("Mosaikk 會越用越佔空間嗎？", "不會。預覽只保存在記憶體裡。暫存檔用完就刪除；沒有任何視窗會再打開的未命名拼貼副本，會在 Mosaikk 啟動時清理掉。"),
            ("最大能輸出多大？", "長邊最多 12,000 像素，格式為 PNG、JPEG 或 HEIC。PNG 和 HEIC 可以保留透明背景。"),
            ("有浮水印或限制嗎？", "沒有浮水印。一個拼貼最多可以放 500 張圖片。"),
            ("怎麼更新？", "Mac App Store 版本透過 App Store 更新。下載版請選擇「輔助說明 › 檢查新版本⋯」，它會在瀏覽器中打開這個網站，因為 Mosaikk 本身從不連網。"),
            ("怎麼解除安裝？", "結束 Mosaikk，把它從「應用程式」拖到垃圾桶。它的設定和未命名的拼貼在 ~/Library/Containers/com.feiyangtang.Mosaikk，也可以一併刪除。你儲存過的拼貼仍然在你儲存的位置。"),
        ],
        "privacy_title": "隱私權政策",
        "privacy": [
            "最後更新：2026 年 11 月 12 日。本政策適用於 Mac App Store 版本和從本網站下載的版本。",
            "<b>Mosaikk 不收集任何資料。</b>它完全沒有網路權限：App 沙盒不允許它連上網際網路。沒有帳號、統計、遙測、當機報告、廣告或更新檢查，也沒有任何第三方程式碼。",
            "Mosaikk 讀取你加入的圖片，用來顯示並放進你的拼貼。儲存的拼貼是一個 .mosaikk 檔案，放在你選擇的位置，裡面是你加入的圖片的原樣副本，以便日後繼續編輯。照片的後設資料（例如拍攝時間和地點）會留在這些副本裡；輸出的圖片不包含這些資訊。",
            "從「照片」圖庫加入的照片是在系統的照片選擇器中挑選的，Mosaikk 從來無法取用圖庫本身。",
            "Mosaikk 只在你指定的地方寫入檔案，並在你儲存或刪除之前，把未命名的拼貼保存在它自己的檔案夾裡。「輔助說明」選單中的連結會在瀏覽器中打開，與 Mosaikk 無關。「檢查新版本」會把你的版本號碼告訴本網站，以便顯示是否有新版本。",
            "Mosaikk 適合所有年齡，不收集任何人的資料，包括兒童。隱私相關問題：support@tang-spark.no。",
        ],
        "terms_title": "使用條款",
        "terms": [
            "Mosaikk 免費，可用於個人和商業用途。",
            "Mosaikk 依「現狀」提供，不附帶任何保證。Mosaikk 從不修改你加入的圖片；但在法律允許的範圍內，TangSpark 不對因使用本軟體造成的資料遺失或其他損失負責。",
            "你需要擁有所用圖片的相應權利。從 Mac App Store 下載的版本同時適用 Apple 的標準授權協議。",
        ],
        "notes_title": "版本說明",
        "notes": [
            ("版本 1.0.0", "2026 年 11 月", "首次發佈：200 多個可拖移邊框的佈局、形狀相框和自由排列；每張照片的裁切、濾鏡和調整；文字、貼紙和背景；社群媒體、列印和自訂尺寸；輸出 PNG、JPEG 和 HEIC；四種語言。"),
        ],
        "contact_title": "聯絡",
        "contact": "請寫信至 <a href=\"mailto:support@tang-spark.no\">support@tang-spark.no</a>。附上 macOS 版本和 Mosaikk 版本（Mosaikk 選單 › 關於 Mosaikk）會很有幫助。",
        "footer_support": "支援與隱私",
    },
}

e = html.escape


def head(lang, title, description, page):
    alternates = "".join(
        f'<link rel="alternate" hreflang="{LANGS[k]["html"]}" href="https://tang-spark.no/{page}{LANGS[k]["suffix"]}.html">'
        for k in LANGS)
    return (f'<!doctype html>\n<html lang="{LANGS[lang]["html"]}"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f'<title>{e(title)} | TangSpark</title><meta name="description" content="{e(description)}">\n'
            f'{alternates}\n<link rel="icon" type="image/svg+xml" href="./favicon.svg"><link rel="stylesheet" href="./styles.css"></head>\n'
            f'<body><div class="wrap">\n')


def nav(lang, page, items):
    langs = "".join(f'<a href="./{page}{LANGS[k]["suffix"]}.html" hreflang="{LANGS[k]["html"]}">{label}</a>'
                    for k, label in LANGS[lang]["other"])
    return f'<header><a class="mark" href="./index.html">TangSpark</a><nav>{items}{langs}</nav></header>\n'


def facts(rows):
    return '<div class="facts">' + "".join(f"<div><span>{e(k)}</span><span>{v}</span></div>" for k, v in rows) + "</div>"


def product(lang):
    c, s = COPY[lang], LANGS[lang]["suffix"]
    support = f"./mosaikk-support{s}.html"
    if APP_STORE_URL or DOWNLOAD_URL:
        text = c["get_text_store"] if APP_STORE_URL else c["get_text_download"]
        buttons = (f'<a class="btn red" href="{APP_STORE_URL}">{e(c["btn_store"])}</a>' if APP_STORE_URL else "") + \
                  (f'<a class="btn{"" if APP_STORE_URL else " red"}" href="{DOWNLOAD_URL}">{e(c["btn_download"])}</a>' if DOWNLOAD_URL else "")
    else:
        text, buttons = c["get_text_soon"], f'<a class="btn red" href="{GITHUB}">{e(c["btn_source"])}</a>'
    buttons += f'<a class="btn" href="{support}">{e(c["btn_support"])}</a>'
    shot = "img/mosaikk-shot.jpg" if lang == "en" else f"img/mosaikk-shot{s}.jpg"
    features = "".join(f"<li><b>{e(a)}</b><span>{e(b)}</span></li>" for a, b in c["features"])
    return (head(lang, c["title"], c["description"], "mosaikk")
            + nav(lang, "mosaikk", f'<a href="./index.html#apps">{c["nav_apps"]}</a><a href="{support}">{c["nav_support"]}</a>')
            + f'<div class="title"><img src="img/mosaikk-icon.png" alt=""><span class="label">{e(c["label"])}</span></div>\n'
            + '<div class="hero-name">Mosaikk</div>\n'
            + f'<section class="grid poster"><div class="block"><h1 class="cond">{e(c["headline"])}</h1><p>{e(c["lead"])}</p></div>\n{facts([(k, e(v)) for k, v in c["facts"]])}</section>\n'
            + f'<section class="grid"><div class="big"><img src="{shot}" alt="{e(c["shot_alt"])}"></div></section>\n'
            + f'<section class="part rule grid cols"><h2 class="cond">{e(c["what"])}</h2><ul class="list">{features}</ul></section>\n'
            + f'<section id="download" class="part rule grid cols"><h2 class="cond">{e(c["get"])}</h2><div style="grid-column: 5 / span 8"><p>{e(text)}</p><div class="cta">{buttons}</div></div></section>\n'
            + f'<footer><span>© 2026 TangSpark</span><a href="{support}">{e(c["footer_support"])}</a></footer>\n</div></body></html>\n')


def support(lang):
    c, s = COPY[lang], LANGS[lang]["suffix"]
    section = lambda id, title, body: f'<section id="{id}" class="part rule grid cols"><h2 class="cond">{e(title)}</h2><div class="doc">{body}</div></section>\n'
    toc = "".join(f'<a href="#{id}">{e(t)}</a>' for id, t in c["toc"])
    start = "<ol class=\"steps\">" + "".join(f"<li>{e(x)}</li>" for x in c["start"]) + "</ol>"
    faq = "".join(f"<h3>{e(q)}</h3><p>{e(a)}</p>" for q, a in c["faq"])
    privacy = "".join(f"<p>{p}</p>" for p in c["privacy"])
    terms = "".join(f"<p>{e(p)}</p>" for p in c["terms"])
    notes = "".join(f"<h3>{e(v)}</h3><p class=\"meta\">{e(d)}</p><p>{e(t)}</p>" for v, d, t in c["notes"])
    return (head(lang, c["s_title"], c["s_lead"], "mosaikk-support")
            + nav(lang, "mosaikk-support", f'<a href="./mosaikk{s}.html">Mosaikk</a><a href="#privacy">{e(c["toc"][2][1])}</a><a href="#terms">{e(c["toc"][3][1])}</a>')
            + f'<div class="title"><img src="img/mosaikk-icon.png" alt=""><span class="label">Mosaikk {VERSION}</span></div>\n'
            + f'<div class="hero-name">{e(c["s_hero"])}</div>\n'
            + f'<section class="grid poster"><div class="block"><h1 class="cond">{e(c["s_headline"])}</h1><p>{e(c["s_lead"])}</p></div>{facts(c["s_facts"])}</section>\n'
            + f'<nav class="toc">{toc}</nav>\n'
            + section("start", c["toc"][0][1], start)
            + section("faq", c["toc"][1][1], faq)
            + section("privacy", c["privacy_title"], privacy)
            + section("terms", c["terms_title"], terms)
            + section("release-notes", c["notes_title"], notes)
            + section("contact", c["contact_title"], f"<p>{c['contact']}</p>")
            + f'<footer><span>© 2026 TangSpark</span><a href="./mosaikk{s}.html">Mosaikk</a></footer>\n</div></body></html>\n')


if __name__ == "__main__":
    DIST.mkdir(parents=True, exist_ok=True)
    for lang in LANGS:
        s = LANGS[lang]["suffix"]
        (DIST / f"mosaikk{s}.html").write_text(product(lang))
        (DIST / f"mosaikk-support{s}.html").write_text(support(lang))
    print(f"wrote {len(LANGS) * 2} pages for Mosaikk {VERSION} to {DIST.relative_to(ROOT)}")

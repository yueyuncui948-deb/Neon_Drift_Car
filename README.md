# 霓虹甩尾 · Neon Drift

一款 Godot 4 **Compatibility / WebGL 2.0** 街機甩尾計時遊戲。駕駛原創 ION-01，在霓虹夜間賽道完成三圈，挑戰最快時間與甩尾積分。

## 已完成玩法

- 加速、煞車／倒車、轉向、手煞車甩尾與可恢復的氮氣加速。
- 四個獨立車輪的滾動與前輪轉向動畫，護欄碰撞、追車鏡頭與輪胎痕跡。
- 起跑倒數、8 個依序檢查點、三圈計時、逐圈成績與完賽後重新挑戰。
- 逆向與跳過檢查點不計圈；回正加罰 5 秒並保留檢查點進度。
- 中文開始／暫停／結算介面、小地圖、氮氣量與甩尾積分顯示。
- 鍵盤與螢幕觸控按鈕、音效開關；失去視窗焦點自動暫停。
- 省電／標準畫質、逆向與卡住提示、觸控回正按鈕；音效與畫質偏好保存。
- 本機最佳總時間、單圈與甩尾成績保存（瀏覽器版儲存在該網站的本機資料，清除網站資料會一併刪除）。

## 網頁版與截圖

已匯出檔案位於 [`docs/play/`](docs/play/)。[部署與本機遊玩說明](docs/網頁部署說明.md)包含 GitHub Pages 的啟用步驟。儲存庫有 HTML 並不代表網站已發布。

- [瀏覽器主選單](docs/neon-web-menu.png)
- [實際行駛畫面](docs/neon-web-driving-detail.png)
- [三圈結算畫面](docs/neon-web-finish.png)
- [模型／骨骼來源說明](docs/模型製作說明.md)
- [驗證紀錄與限制](docs/驗證紀錄.md)
- [十項改善與效能測試](docs/十項遊戲優化.md)

## 操作

| 操作 | 按鍵 |
| --- | --- |
| 加速 | W / ↑ |
| 煞車、停止後倒車 | S / ↓ |
| 左右轉向 | A、D / ←、→ |
| 手煞車甩尾 | 空白鍵（搭配轉向） |
| 氮氣加速 | Shift（搭配加速） |
| 回正車輛 | R（+5 秒） |
| 暫停／繼續 | P / Esc |
| 開始／重試 | Enter 或畫面按鈕 |

手機建議橫向使用，點右上角「觸控」可顯示或隱藏按鈕。此版本是單人計時挑戰，沒有多人連線或 AI 對手。

## 開發與執行

已驗證工具：Godot **4.6.3 stable**、Blender **4.3.2**。開啟 `project.godot` 後按 F5，或從儲存庫根目錄執行：

```bash
godot --headless --editor --path . --import
godot --path .
```

原始模型展示場景仍保留在 `scenes/showroom.tscn`；可單獨開啟該場景按 F6。

## 模型與骨骼來源

詳見 [模型製作說明](docs/模型製作說明.md)。模型由 [`tools/build_car.py`](tools/build_car.py) 使用 Blender `bpy` 原創生成，包含 1,936 個三角形、84 個網格和 8 種材質。

**沒有使用外部模型或骨骼。** 四個輪軸是生成腳本建立的 Empty 旋轉樞紐，Godot 使用剛體零件旋轉來表現輪胎滾動及轉向；沒有 Armature、蒙皮或外部動作庫。

- Blender 原檔：`art/neon_drift_car.blend`
- Godot 素材：`assets/cars/neon_drift_car.gltf` 及 `.bin`（必須一起保留）
- 重新生成：`blender --background --python tools/build_car.py`，**會覆寫模型生成檔**。
- 音效：`tools/build_audio.py` 使用 Python 標準函式庫原創合成引擎與摩擦聲，沒有外部音效素材。
- 字型：Noto Sans CJK TC 的子集，重新命名為 Neon UI；附 [字型授權](assets/ui/FONT-LICENSE.txt)。字型是唯一外部美術相關資源，與車模／骨骼無關。
- 字型重建：在有 Noto CJK 及 `fonttools` 的環境執行 `python3 tools/build_font.py`。增加中文字時須重新產生子集。

## 驗證

先匯入專案，再執行：

```bash
godot --headless --path . --audio-driver Dummy --script tests/test_car.gd
godot --headless --path . --audio-driver Dummy --script tests/test_race.gd
godot --headless --path . --audio-driver Dummy --script tests/test_flow.gd
godot --headless --path . --audio-driver Dummy --script tests/test_handling.gd
godot --headless --path . --audio-driver Dummy --script tests/test_render_guidance.gd
godot --headless --path . --audio-driver Dummy --script tests/test_restart_settings.gd
```

共 71 項：車輛操控 10、賽道規則與碰撞 8、介面流程／暫停／存檔／觸控 14、操控優化 12、繪製／引導 11、重賽／設定 16。另外可執行實際三圈行駛測試：

```bash
godot --headless --fixed-fps 60 --path . --audio-driver Dummy --script tests/test_drive.gd
```

瀏覽器回歸測試使用 `tests/test_optimization_web.py`（設定／混合輸入／載入失敗重試）與 `tests/test_web.py`（Python Playwright + Chromium），透過正常操作輸入檢查網頁版；不直接修改車輛位置或圈數。

## 雲端環境

若家目錄不可寫入，先設定：

```bash
export XDG_DATA_HOME=/workspace/.godot-runtime/data
export XDG_CONFIG_HOME=/workspace/.godot-runtime/config
export XDG_CACHE_HOME=/workspace/.godot-runtime/cache
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
```

無聲音裝置時加 `--audio-driver Dummy`。實際截圖須有圖形顯示（例如本環境的 Xorg `:99`）而非 `--headless`：

```bash
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --audio-driver Dummy -- --capture=/tmp/neon-game.png
```

網頁匯出使用官方 Godot 4.6.3 單執行緒模板；模板及產出檔都有校驗記錄。請見 [網頁部署說明](docs/網頁部署說明.md)。本專案不是完整車輛力學模擬，尚無多人模式；瀏覽器與硬體效能可能不同。

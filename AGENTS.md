# 專案協作規則

- 使用繁體中文回報進度。每完成一個可獨立驗證的環節，先執行相關檢查，再提交並推送 GitHub；提交標題與內容使用中文，描述實際完成內容及驗證結果。
- 目前交付分支是遠端 `main`；雲端本機可能使用 `work` 分支。先確認遠端狀態及使用者變更，正常推送 `HEAD:main`，推送後核對遠端 SHA。不要把「已提交」當作「已推送」。
- 模型來源與骨骼來源必須明確說明。本車由 `tools/build_car.py` 的 Blender bpy 程序原創生成；四個 Empty 輪軸不是骨骼，未使用第三方車模或外部骨架。改變此情況時須同步更新中文來源文件。
- 修改模型生成邏輯後，同步更新 Blender 原檔及 glTF／bin。重新生成會覆寫生成檔，不要覆蓋使用者手動修改而未保存的模型。
- 保持 Godot Compatibility 渲染器。網頁版使用 Godot 4.6.3 單執行緒 Web 模板。
- 主要檢查：`tests/test_car.gd`、`tests/test_race.gd`、`tests/test_flow.gd`。完整物理行駛可使用 `godot --headless --fixed-fps 60 --path . --audio-driver Dummy --script tests/test_drive.gd`；網頁匯出與瀏覽器檢查見 README 和 `docs/網頁部署說明.md`。
- 修改遊戲後如要交付網頁版，執行 `bash tools/export_web.sh`，驗證並一併提交 `docs/play/`。`.godot/` 是匯入快取，不提交。
- 每個雲端任務已有隔離環境；使用現有 checkout，除非使用者明確要求，否則不要建立額外 Git worktree。

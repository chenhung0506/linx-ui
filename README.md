# linx-ui

`linx` 服務（短網址 / 圖片 / 單字卡...）的前端頁面集合。純靜態 HTML/CSS/JS，nginx 直接serve，跟 `resume`、`wedding` 是一樣的架構，但內容專屬於 linx 的功能，不掛在個人履歷/婚禮站點下面。

## 本地開發

```bash
docker-compose up -d
```

## 部署

跟 `resume`/`wedding` 同一套流程，見 `reverse-proxy` 專案的 README。

- 外部網域：https://linx-ui.linch.uk/
- 內部 port：3016

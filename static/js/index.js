const { createApp } = Vue;

const app = createApp({
  data() {
    return {
      categories: ["蔬菜", "水果", "肉类", "海鲜", "乳制品", "饮料", "调料", "主食", "速食", "其他"],
      inventory: [],
      stats: { itemCount: 0, expiringSoon: 0, expired: 0, lowStock: 0, categories: {}, shoppingList: [] },
      filters: { search: "", category: "", status: "", sortBy: "recent" },
      advice: { date: "", text: "正在加载…" },
      adviceRefreshing: false,
      recipe: { query: "", loading: false, markdown: "", rendered: "", canceled: false },
      bulk: { text: "", loading: false, result: "" },
      form: { id: "", name: "", quantity: 1, unit: "个", category: "其他", expiry: "", minQuantity: 0, quickNote: "", note: "" },
      activeTab: "overview",
      detailItem: null,
      dialog: { title: "", message: "", mode: "alert", okText: "确定", cancelText: "取消" },
      itemModal: null,
      detailModal: null,
      appDialogModal: null,
      dialogResolver: null,
      recipeAbortController: null,
    };
  },
  computed: {
    sortedCategories() {
      return Object.fromEntries(Object.entries(this.stats.categories || {}).sort((a, b) => b[1] - a[1]));
    },
    filteredItems() {
      const q = (this.filters.search || "").trim().toLowerCase();
      return this.inventory.filter((i) => {
        const note = (i.note || "").toLowerCase();
        const mq = !q || i.name.toLowerCase().includes(q) || i.category.toLowerCase().includes(q) || note.includes(q);
        const mc = !this.filters.category || i.category === this.filters.category;
        let ms = true;
        if (this.filters.status === "expired") ms = i.isExpired;
        else if (this.filters.status === "warning") ms = i.isExpiringSoon && !i.isExpired;
        else if (this.filters.status === "low") ms = i.isLowStock;
        else if (this.filters.status === "normal") ms = !i.isExpired && !i.isExpiringSoon && !i.isLowStock;
        return mq && mc && ms;
      });
    },
  },
  methods: {
    amt(v) {
      const n = Number(v || 0);
      return Number.isInteger(n) ? String(n) : n.toFixed(1).replace(/\.0$/, "");
    },
    qty(v, u) {
      return `${this.amt(v)} ${u || "个"}`;
    },
    remind(v, u) {
      return Number(v || 0) <= 0 ? "不提醒" : this.qty(v, u);
    },
    step(u) {
      const n = String(u || "").trim().toLowerCase();
      if (["克", "g", "毫升", "ml"].includes(n)) return 50;
      if (["千克", "kg", "升", "l"].includes(n)) return 0.5;
      return 1;
    },
    expiryText(i) {
      if (!i.expiry) return "未设置";
      const d = new Date(i.expiry).toLocaleDateString("zh-CN");
      if (i.isExpired) return `${d}（已过期）`;
      if (i.isExpiringSoon) return `${d}（${i.daysUntilExpiry} 天内）`;
      return d;
    },
    statusText(i) {
      if (i.isExpired) return "已过期";
      if (i.isExpiringSoon) return `${i.daysUntilExpiry} 天内到期`;
      if (Number(i.minQuantity || 0) > 0 && i.isLowStock) return "库存偏低";
      return "正常";
    },
    openDetailModal(item) {
      this.detailItem = item ? { ...item } : null;
      this.detailModal.show();
    },
    closeDetailModal() {
      this.detailModal.hide();
    },
    async showAlert(message, title = "提示", okText = "确定") {
      this.dialog = { ...this.dialog, title, message, mode: "alert", okText, cancelText: "取消" };
      this.appDialogModal.show();
      return new Promise((resolve) => {
        this.dialogResolver = resolve;
      });
    },
    async showConfirm(message, title = "请确认", okText = "确定", cancelText = "取消") {
      this.dialog = { ...this.dialog, title, message, mode: "confirm", okText, cancelText };
      this.appDialogModal.show();
      return new Promise((resolve) => {
        this.dialogResolver = resolve;
      });
    },
    resolveDialog(result) {
      this.appDialogModal.hide();
      if (this.dialogResolver) {
        this.dialogResolver(result);
        this.dialogResolver = null;
      }
    },
    esc(v) {
      return String(v)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#39;");
    },
    renderMarkdown(md) {
      const text = String(md || "");
      const escaped = this.esc(text).replace(/\r\n?/g, "\n");
      const codeBlocks = [];
      let html = escaped.replace(/```([\s\S]*?)```/g, (_, code) => {
        const token = `@@CODEBLOCK_${codeBlocks.length}@@`;
        codeBlocks.push(`<pre><code>${code.trim()}</code></pre>`);
        return token;
      });
      html = html.replace(/^---+$/gm, "<hr>");
      html = html.replace(/^###\s+(.+)$/gm, "<h3>$1</h3>");
      html = html.replace(/^##\s+(.+)$/gm, "<h2>$1</h2>");
      html = html.replace(/^#\s+(.+)$/gm, "<h1>$1</h1>");
      html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
      html = html.replace(/`([^`]+?)`/g, "<code>$1</code>");
      html = html.replace(/^\s*[-*]\s+(.+)$/gm, "<li>$1</li>");
      html = html.replace(/(<li>[\s\S]*?<\/li>)/g, "<ul>$1</ul>").replace(/<\/ul>\s*<ul>/g, "");
      html = html
        .split(/\n{2,}/)
        .map((block) => {
          const trimmed = block.trim();
          if (!trimmed) return "";
          if (/^<(h1|h2|h3|ul|pre|hr)/.test(trimmed)) return trimmed;
          return `<p>${trimmed.replace(/\n/g, "<br>")}</p>`;
        })
        .join("");
      codeBlocks.forEach((block, idx) => {
        html = html.replace(`@@CODEBLOCK_${idx}@@`, block);
      });
      return html || "<p>没有收到模型输出，请稍后再试。</p>";
    },
    async loadStats() {
      const r = await fetch("/api/stats");
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      this.stats = await r.json();
    },
    async loadInventory() {
      try {
        const r = await fetch(`/api/inventory?sort=${encodeURIComponent(this.filters.sortBy)}`);
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        this.inventory = await r.json();
        await this.loadStats();
      } catch (e) {
        console.error(e);
      }
    },
    async loadDailyAdvice(force = false) {
      const today = new Date().toISOString().slice(0, 10);
      const key = `dailyAdvice:${today}`;
      if (!force) {
        const cached = localStorage.getItem(key);
        if (cached) {
          const p = JSON.parse(cached);
          this.advice = { date: p.date || "", text: p.advice || "暂无建议" };
          return;
        }
      }
      this.adviceRefreshing = true;
      this.advice = { date: today, text: force ? "正在刷新今日建议…" : "正在根据库存生成今日建议…" };
      try {
        const r = await fetch(`/api/daily-advice${force ? "?force=1" : ""}`);
        const p = await r.json();
        if (!r.ok) throw new Error(p.error || "加载失败");
        localStorage.setItem(key, JSON.stringify(p));
        this.advice = { date: p.date || "", text: p.advice || "暂无建议" };
      } catch (e) {
        console.error(e);
        this.advice = { date: today, text: `加载失败：${e.message}` };
      } finally {
        this.adviceRefreshing = false;
      }
    },
    openModal() {
      this.form = { id: "", name: "", quantity: 1, unit: "个", category: "其他", expiry: "", minQuantity: 0, quickNote: "", note: "" };
      this.itemModal.show();
    },
    openEditModal(id) {
      const i = this.inventory.find((x) => x.id === id);
      if (!i) return;
      this.form = { id: i.id, name: i.name || "", quantity: i.quantity ?? 1, unit: i.unit || "个", category: i.category || "其他", expiry: i.expiry || "", minQuantity: i.minQuantity ?? 0, quickNote: "", note: i.note || "" };
      if (this.detailModal && document.getElementById("detailModal")?.classList.contains("show")) {
        const detailEl = document.getElementById("detailModal");
        const handleHidden = () => {
          this.itemModal.show();
          detailEl.removeEventListener("hidden.bs.offcanvas", handleHidden);
        };
        detailEl.addEventListener("hidden.bs.offcanvas", handleHidden);
        this.closeDetailModal();
        return;
      }
      this.itemModal.show();
    },
    closeModal() {
      this.itemModal.hide();
    },
    async handleSubmit() {
      const payload = {
        name: this.form.name.trim(),
        quantity: Number(this.form.quantity),
        unit: (this.form.unit || "个").trim(),
        category: this.form.category,
        expiry: this.form.expiry,
        minQuantity: Number(this.form.minQuantity),
        note: [this.form.quickNote.trim(), this.form.note.trim()].filter(Boolean).join("；"),
      };
      try {
        const id = this.form.id;
        const r = await fetch(id ? `/api/inventory/${id}` : "/api/inventory", {
          method: id ? "PUT" : "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        const j = await r.json();
        if (!r.ok) {
          await this.showAlert(j.error || "保存失败");
          return;
        }
        this.closeModal();
        await this.loadInventory();
      } catch (e) {
        console.error(e);
        await this.showAlert("保存失败，请稍后重试。");
      }
    },
    async adjustQuantity(id, delta) {
      try {
        const r = await fetch(`/api/inventory/${id}/adjust`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ delta }),
        });
        const j = await r.json();
        if (!r.ok) {
          await this.showAlert(j.error || "更新数量失败");
          return;
        }
        if (this.detailItem && this.detailItem.id === id) {
          this.detailItem = { ...this.detailItem, ...j };
        }
        await this.loadInventory();
      } catch (e) {
        console.error(e);
      }
    },
    async deleteItem(id) {
      if (!(await this.showConfirm("确定删除这条记录吗？", "删除确认", "删除"))) return;
      try {
        const r = await fetch(`/api/inventory/${id}`, { method: "DELETE" });
        const j = await r.json();
        if (!r.ok) {
          await this.showAlert(j.error || "删除失败");
          return;
        }
        await this.loadInventory();
      } catch (e) {
        console.error(e);
      }
    },
    async clearExpired() {
      if (!(await this.showConfirm("确定清理所有过期食材吗？", "批量清理确认", "清理"))) return;
      try {
        const r = await fetch("/api/inventory/clear-expired", { method: "POST" });
        const j = await r.json();
        if (!r.ok) {
          await this.showAlert(j.error || "清理失败");
          return;
        }
        await this.showAlert(`已清理 ${j.deleted || 0} 条过期记录。`, "清理完成");
        await this.loadInventory();
      } catch (e) {
        console.error(e);
      }
    },
    async exportData() {
      try {
        const r = await fetch("/api/export");
        const data = await r.json();
        const b = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
        const u = URL.createObjectURL(b);
        const a = document.createElement("a");
        a.href = u;
        a.download = `fridge_inventory_${new Date().toISOString().slice(0, 10)}.json`;
        a.click();
        URL.revokeObjectURL(u);
      } catch (e) {
        console.error(e);
      }
    },
    renderBulkImportResults(items) {
      if (!items.length) return '<div class="small">本次没有导入任何食材。</div>';
      return items
        .map((i) => `<div class="border rounded-3 p-2 mb-2"><div class="fw-semibold">${this.esc(i.name)}</div><div class="small text-secondary">${this.qty(i.quantity, i.unit)} | ${this.esc(i.category || "其他")} | ${this.esc(i.expiry || "未设置过期时间")}</div><div class="small text-secondary">${this.esc(i.note || "无备注")}</div></div>`)
        .join("");
    },
    async bulkImportInventory() {
      if (!this.bulk.text.trim()) {
        await this.showAlert("请先输入要解析的文本。");
        return;
      }
      this.bulk.loading = true;
      this.bulk.result = "正在调用 AI 解析并写入库存…";
      try {
        const r = await fetch("/api/inventory/bulk-import", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text: this.bulk.text.trim() }),
        });
        const p = await r.json();
        if (!r.ok) throw new Error(p.error || "批量录入失败");
        const items = Array.isArray(p.items) ? p.items : [];
        this.bulk.result = this.renderBulkImportResults(items);
        this.bulk.text = "";
        await this.loadInventory();
      } catch (e) {
        console.error(e);
        this.bulk.result = `批量录入失败：${this.esc(e.message)}`;
      } finally {
        this.bulk.loading = false;
      }
    },
    async generateRecipeSuggestions() {
      if (this.recipeAbortController) this.recipeAbortController.abort();
      this.recipeAbortController = new AbortController();
      this.recipe.loading = true;
      this.recipe.canceled = false;
      this.recipe.markdown = "";
      this.recipe.rendered = "";
      try {
        const r = await fetch("/api/recipe-suggestions/stream", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ query: (this.recipe.query || "").trim() }),
          signal: this.recipeAbortController.signal,
        });
        if (!r.ok || !r.body) throw new Error(`请求失败: ${r.status}`);
        const reader = r.body.getReader();
        const decoder = new TextDecoder("utf-8");
        let buffer = "";
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const blocks = buffer.split("\n\n");
          buffer = blocks.pop() || "";
          for (const block of blocks) {
            const dataLine = block.split("\n").find((line) => line.startsWith("data: "));
            if (!dataLine) continue;
            const payload = JSON.parse(dataLine.slice(6));
            if (payload.type === "chunk") {
              this.recipe.markdown += payload.content;
              this.recipe.rendered = this.renderMarkdown(this.recipe.markdown);
            } else if (payload.type === "error") {
              throw new Error(payload.message);
            }
          }
        }
        if (!this.recipe.markdown.trim()) this.recipe.rendered = "<p>没有收到模型输出，请稍后再试。</p>";
      } catch (e) {
        if (e.name === "AbortError") {
          if (this.recipe.canceled) {
            this.recipe.rendered = "<p>已停止生成。</p>";
          }
        } else {
          console.error(e);
          this.recipe.rendered = `<p>生成失败：${this.esc(e.message)}</p>`;
        }
      } finally {
        this.recipe.loading = false;
        this.recipeAbortController = null;
      }
    },
    cancelRecipeGeneration() {
      if (!this.recipe.loading || !this.recipeAbortController) return;
      this.recipe.canceled = true;
      this.recipeAbortController.abort();
    },
  },
  async mounted() {
    this.itemModal = new bootstrap.Offcanvas(document.getElementById("itemModal"));
    this.detailModal = new bootstrap.Offcanvas(document.getElementById("detailModal"));
    this.appDialogModal = new bootstrap.Modal(document.getElementById("appDialogModal"));
    await Promise.all([this.loadInventory(), this.loadDailyAdvice(false)]);
  },
});

app.config.compilerOptions.delimiters = ["[[", "]]" ];
app.mount("#app");



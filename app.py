from datetime import datetime
import json
import os

from flask import Flask, jsonify, render_template, request

app = Flask(__name__)
DATA_FILE = "fridge_inventory.json"
DEFAULT_CATEGORY = "其他"


def load_inventory():
    """从 JSON 文件加载库存数据。"""
    if not os.path.exists(DATA_FILE):
        return []

    try:
        with open(DATA_FILE, "r", encoding="utf-8") as file:
            data = json.load(file)
            return [normalize_item(item) for item in data if isinstance(item, dict)]
    except (json.JSONDecodeError, FileNotFoundError):
        return []


def save_inventory(inventory):
    """保存库存数据。"""
    with open(DATA_FILE, "w", encoding="utf-8") as file:
        json.dump(inventory, file, ensure_ascii=False, indent=2)


def normalize_item(item):
    """兼容旧数据结构，补齐缺省字段。"""
    return {
        "id": item.get("id", int(datetime.now().timestamp() * 1000000)),
        "name": str(item.get("name", "")).strip(),
        "quantity": max(int(item.get("quantity", 0) or 0), 0),
        "category": str(item.get("category") or DEFAULT_CATEGORY).strip() or DEFAULT_CATEGORY,
        "expiry": item.get("expiry", "") or "",
        "addedDate": item.get("addedDate") or datetime.now().isoformat(),
        "minQuantity": max(int(item.get("minQuantity", 1) or 1), 1),
        "note": str(item.get("note", "")).strip(),
    }


def parse_item_payload(data, partial=False):
    """校验并清洗新增/更新请求。"""
    if not isinstance(data, dict):
        raise ValueError("请求数据格式错误")

    payload = {}

    if not partial or "name" in data:
        name = str(data.get("name", "")).strip()
        if not name:
            raise ValueError("物品名称不能为空")
        payload["name"] = name

    if not partial or "quantity" in data:
        try:
            quantity = int(data.get("quantity", 0))
        except (TypeError, ValueError) as exc:
            raise ValueError("数量必须是整数") from exc
        if quantity < 0:
            raise ValueError("数量不能小于 0")
        if not partial and quantity == 0:
            raise ValueError("新增物品时数量必须大于 0")
        payload["quantity"] = quantity

    if not partial or "category" in data:
        payload["category"] = str(data.get("category") or DEFAULT_CATEGORY).strip() or DEFAULT_CATEGORY

    if "expiry" in data or not partial:
        expiry = data.get("expiry", "") or ""
        if expiry:
            try:
                datetime.fromisoformat(expiry)
            except ValueError as exc:
                raise ValueError("过期日期格式无效") from exc
        payload["expiry"] = expiry

    if "minQuantity" in data or not partial:
        try:
            min_quantity = int(data.get("minQuantity", 1))
        except (TypeError, ValueError) as exc:
            raise ValueError("库存提醒阈值必须是整数") from exc
        if min_quantity < 1:
            raise ValueError("库存提醒阈值必须大于 0")
        payload["minQuantity"] = min_quantity

    if "note" in data or not partial:
        payload["note"] = str(data.get("note", "")).strip()

    return payload


def calculate_item_flags(item, today):
    is_low_stock = item["quantity"] <= item["minQuantity"]
    is_expired = False
    is_expiring_soon = False
    days_until_expiry = None

    if item.get("expiry"):
        expiry_date = datetime.fromisoformat(item["expiry"]).date()
        days_until_expiry = (expiry_date - today).days
        is_expired = days_until_expiry < 0
        is_expiring_soon = 0 <= days_until_expiry <= 3

    return {
        "isLowStock": is_low_stock,
        "isExpired": is_expired,
        "isExpiringSoon": is_expiring_soon,
        "daysUntilExpiry": days_until_expiry,
    }


def serialize_item(item, today=None):
    today = today or datetime.now().date()
    result = dict(item)
    result.update(calculate_item_flags(item, today))
    return result


def sort_inventory(items, sort_by):
    today = datetime.now().date()

    def expiry_key(item):
        if item.get("expiry"):
            return (0, item["expiry"])
        return (1, "9999-12-31")

    sorters = {
        "name": lambda item: item["name"].lower(),
        "quantity_desc": lambda item: (-item["quantity"], item["name"].lower()),
        "quantity_asc": lambda item: (item["quantity"], item["name"].lower()),
        "category": lambda item: (item["category"], item["name"].lower()),
        "recent": lambda item: item.get("addedDate", ""),
        "expiry": expiry_key,
        "status": lambda item: (
            0 if calculate_item_flags(item, today)["isExpired"] else
            1 if calculate_item_flags(item, today)["isExpiringSoon"] else
            2 if calculate_item_flags(item, today)["isLowStock"] else
            3,
            expiry_key(item),
        ),
    }

    key_func = sorters.get(sort_by, sorters["recent"])
    reverse = sort_by == "recent"
    return sorted(items, key=key_func, reverse=reverse)


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/inventory", methods=["GET"])
def get_inventory():
    inventory = load_inventory()
    sort_by = request.args.get("sort", "recent")
    today = datetime.now().date()
    sorted_inventory = sort_inventory(inventory, sort_by)
    return jsonify([serialize_item(item, today) for item in sorted_inventory])


@app.route("/api/inventory", methods=["POST"])
def add_item():
    try:
        payload = parse_item_payload(request.get_json(silent=True), partial=False)
        inventory = load_inventory()

        new_item = {
            "id": int(datetime.now().timestamp() * 1000000),
            "addedDate": datetime.now().isoformat(),
            **payload,
        }

        inventory.insert(0, normalize_item(new_item))
        save_inventory(inventory)
        return jsonify(serialize_item(inventory[0])), 201
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/api/inventory/<int:item_id>", methods=["PUT"])
def update_item(item_id):
    try:
        payload = parse_item_payload(request.get_json(silent=True), partial=True)
        inventory = load_inventory()

        for index, item in enumerate(inventory):
            if item["id"] == item_id:
                inventory[index] = normalize_item({**item, **payload})
                save_inventory(inventory)
                return jsonify(serialize_item(inventory[index]))

        return jsonify({"error": "物品不存在"}), 404
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/api/inventory/<int:item_id>", methods=["DELETE"])
def delete_item(item_id):
    try:
        inventory = load_inventory()
        remaining = [item for item in inventory if item["id"] != item_id]
        if len(remaining) == len(inventory):
            return jsonify({"error": "物品不存在"}), 404

        save_inventory(remaining)
        return jsonify({"success": True})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/api/inventory/<int:item_id>/adjust", methods=["POST"])
def adjust_item_quantity(item_id):
    try:
        data = request.get_json(silent=True) or {}
        delta = int(data.get("delta", 0))
        if delta == 0:
            return jsonify({"error": "调整数量不能为 0"}), 400

        inventory = load_inventory()
        for index, item in enumerate(inventory):
            if item["id"] == item_id:
                new_quantity = item["quantity"] + delta
                if new_quantity < 0:
                    return jsonify({"error": "库存不能小于 0"}), 400
                inventory[index]["quantity"] = new_quantity
                save_inventory(inventory)
                return jsonify(serialize_item(inventory[index]))

        return jsonify({"error": "物品不存在"}), 404
    except (TypeError, ValueError):
        return jsonify({"error": "调整数量必须是整数"}), 400
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/api/inventory/batch-delete", methods=["POST"])
def batch_delete():
    try:
        data = request.get_json(silent=True) or {}
        item_ids = data.get("ids", [])
        if not item_ids:
            return jsonify({"error": "请先选择要删除的物品"}), 400

        inventory = load_inventory()
        remaining = [item for item in inventory if item["id"] not in item_ids]
        deleted_count = len(inventory) - len(remaining)
        save_inventory(remaining)
        return jsonify({"success": True, "deleted": deleted_count})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/api/inventory/clear-expired", methods=["POST"])
def clear_expired():
    try:
        inventory = load_inventory()
        today = datetime.now().date()
        remaining = []
        deleted_count = 0

        for item in inventory:
            if item.get("expiry"):
                expiry_date = datetime.fromisoformat(item["expiry"]).date()
                if expiry_date < today:
                    deleted_count += 1
                    continue
            remaining.append(item)

        save_inventory(remaining)
        return jsonify({"success": True, "deleted": deleted_count})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/api/stats", methods=["GET"])
def get_stats():
    try:
        inventory = load_inventory()
        today = datetime.now().date()

        total_quantity = sum(item["quantity"] for item in inventory)
        total_items = len(inventory)
        expired = 0
        expiring_soon = 0
        low_stock = 0
        category_stats = {}
        shopping_list = []

        for item in inventory:
            category = item.get("category", DEFAULT_CATEGORY)
            category_stats[category] = category_stats.get(category, 0) + item["quantity"]

            flags = calculate_item_flags(item, today)
            if flags["isExpired"]:
                expired += 1
            elif flags["isExpiringSoon"]:
                expiring_soon += 1

            if flags["isLowStock"]:
                low_stock += 1
                shopping_list.append({
                    "id": item["id"],
                    "name": item["name"],
                    "quantity": item["quantity"],
                    "minQuantity": item["minQuantity"],
                    "gap": item["minQuantity"] - item["quantity"],
                    "category": item["category"],
                })

        shopping_list.sort(key=lambda item: (-item["gap"], item["name"]))

        return jsonify({
            "total": total_quantity,
            "itemCount": total_items,
            "expiringSoon": expiring_soon,
            "expired": expired,
            "lowStock": low_stock,
            "categories": category_stats,
            "shoppingList": shopping_list,
        })
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/api/export", methods=["GET"])
def export_data():
    try:
        return jsonify(load_inventory())
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


if __name__ == "__main__":
    if not os.path.exists(DATA_FILE):
        save_inventory([])

    debug_enabled = os.getenv("FLASK_DEBUG", "").lower() in {"1", "true", "yes", "on"}
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "5000"))

    print("=" * 50)
    print("家庭冰箱库存管理系统")
    print("=" * 50)
    print(f"数据文件: {os.path.abspath(DATA_FILE)}")
    print(f"服务启动地址: http://127.0.0.1:{port}")
    print("=" * 50)

    app.run(debug=debug_enabled, host=host, port=port)

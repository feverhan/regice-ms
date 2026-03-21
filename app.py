from datetime import datetime
import json
import os
import re

import requests
from flask import Flask, Response, jsonify, render_template, request, stream_with_context
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
QWEN_API_KEY = os.getenv("QWEN_API_KEY") or os.getenv("DASHSCOPE_API_KEY")
QWEN_MODEL = os.getenv("QWEN_MODEL", "qwen-plus")
QWEN_BASE_URLS = [
    url.strip()
    for url in os.getenv(
        "QWEN_BASE_URLS",
        ",".join([
            "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions",
            "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
        ]),
    ).split(",")
    if url.strip()
]
DATA_FILE = "fridge_inventory.json"
DAILY_ADVICE_CACHE_FILE = "daily_advice_cache.json"
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


def load_daily_advice_cache():
    if not os.path.exists(DAILY_ADVICE_CACHE_FILE):
        return {}

    try:
        with open(DAILY_ADVICE_CACHE_FILE, "r", encoding="utf-8") as file:
            return json.load(file)
    except (json.JSONDecodeError, FileNotFoundError):
        return {}


def save_daily_advice_cache(cache):
    with open(DAILY_ADVICE_CACHE_FILE, "w", encoding="utf-8") as file:
        json.dump(cache, file, ensure_ascii=False, indent=2)


def guess_unit(item):
    explicit_unit = str(item.get("unit", "") or "").strip()
    if explicit_unit:
        return explicit_unit

    name = str(item.get("name", "") or "")
    category = str(item.get("category", "") or "")

    if any(keyword in name for keyword in ["青菜", "菠菜", "生菜", "白菜", "油麦菜"]) or "蔬菜" in category:
        return "把"
    if any(keyword in name for keyword in ["牛奶", "可乐", "果汁", "饮料"]) or "饮料" in category:
        return "瓶"
    if any(keyword in name for keyword in ["辣椒粉", "孜然粉", "胡椒粉", "盐", "糖"]) or "调料" in category:
        return "袋"
    if any(keyword in name for keyword in ["鸡蛋"]):
        return "个"
    return "个"


def normalize_item(item):
    """兼容旧数据结构，补齐缺省字段。"""
    return {
        "id": item.get("id", int(datetime.now().timestamp() * 1000000)),
        "name": str(item.get("name", "")).strip(),
        "quantity": max(float(item.get("quantity", 0) or 0), 0),
        "unit": guess_unit(item),
        "category": str(item.get("category") or DEFAULT_CATEGORY).strip() or DEFAULT_CATEGORY,
        "expiry": item.get("expiry", "") or "",
        "addedDate": item.get("addedDate") or datetime.now().isoformat(),
        "minQuantity": max(float(item.get("minQuantity", 1) or 1), 0),
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
            quantity = float(data.get("quantity", 0))
        except (TypeError, ValueError) as exc:
            raise ValueError("数量必须是整数") from exc
        if quantity < 0:
            raise ValueError("数量不能小于 0")
        if not partial and quantity == 0:
            raise ValueError("新增物品时数量必须大于 0")
        payload["quantity"] = quantity

    if not partial or "unit" in data:
        unit = str(data.get("unit", "个") or "个").strip()
        if not unit:
            raise ValueError("单位不能为空")
        payload["unit"] = unit

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
            min_quantity = float(data.get("minQuantity", 1))
        except (TypeError, ValueError) as exc:
            raise ValueError("库存提醒阈值必须是整数") from exc
        if min_quantity < 0:
            raise ValueError("库存提醒阈值必须大于 0")
        payload["minQuantity"] = min_quantity

    if "note" in data or not partial:
        payload["note"] = str(data.get("note", "")).strip()

    return payload


def calculate_item_flags(item, today):
    is_low_stock = item["minQuantity"] > 0 and item["quantity"] <= item["minQuantity"]
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


def build_inventory_snapshot():
    today = datetime.now().date()
    snapshot = []

    for item in load_inventory():
        flags = calculate_item_flags(item, today)
        status = []

        if flags["isExpired"]:
            status.append("已过期")
        elif flags["isExpiringSoon"]:
            status.append(f"{flags['daysUntilExpiry']}天内到期")

        if flags["isLowStock"]:
            status.append("库存偏低")

        snapshot.append({
            "name": item["name"],
            "quantity": item["quantity"],
            "unit": item.get("unit", "个"),
            "category": item["category"],
            "expiry": item.get("expiry", "") or "未设置",
            "minQuantity": item["minQuantity"],
            "note": item.get("note", ""),
            "status": "、".join(status) if status else "正常",
        })

    return snapshot


def build_recipe_prompt(user_query):
    inventory_text = json.dumps(build_inventory_snapshot(), ensure_ascii=False, indent=2)

    return [
        {
            "role": "system",
            "content": (
                "你是一名家庭做饭助手。你必须基于用户当前库存给出实用、节省食材、可执行、健康低脂的做菜建议。"
                "请严格按库存中的数量和单位理解食材，不能忽略单位。"
                "优先使用快过期食材，绝对不要建议食用已过期食材。如果食材不足以做成一道菜，可以考虑额外买入食材，但是尽量以已有食材为主。"
                "请尽量给出家常菜，不要编造库存里已经有的食材。"
                "调料类默认家里常备，但在制作方法里需要说明。"
                "输出必须使用简体中文，并严格包含这些部分：菜名、可直接使用的现有食材、还缺少的食材、简要做法、备注。内容尽量格式排版清晰。"
                "请给出2到3个建议，每个建议的简要做法控制在3到6步。"
                "这是单轮功能，不要反问用户，不要要求补充信息，不要再问是否需要购物清单。信息不足时，直接基于库存做出合理假设并给出完整答案。"
            ),
        },
        {
            "role": "user",
            "content": (
                f"用户提问：{user_query.strip() or '请根据现有库存推荐适合做的菜。'}\n\n"
                f"当前库存如下：\n{inventory_text}"
            ),
        },
    ]


def build_daily_advice_prompt():
    inventory_text = json.dumps(build_inventory_snapshot(), ensure_ascii=False, indent=2)

    return [
        {
            "role": "system",
            "content": (
                "你是一名家庭饮食顾问。请根据用户当前库存，给出今天最值得关注的一条饮食建议。"
                "优先考虑快到期食材、营养搭配和当天最适合的吃法。"
                "输出必须是简体中文，控制在70字以内，直接给建议，不要写标题，不要分点。"
            ),
        },
        {
            "role": "user",
            "content": f"当前库存如下：\n{inventory_text}",
        },
    ]


def build_bulk_import_prompt(raw_text):
    today = datetime.now().date().isoformat()

    return [
        {
            "role": "system",
            "content": (
                "你是一名家庭冰箱库存录入助手。"
                "你的唯一任务是把用户输入的自然语言、购物清单或票据信息解析成可直接入库的 JSON 数组。"
                "只输出 JSON，不要输出 Markdown，不要解释，不要补充说明。"
                "每个数组元素都必须是对象，并且严格包含这些字段："
                "name, quantity, unit, category, expiry, minQuantity, note。"
                "quantity 和 minQuantity 必须是数字。"
                "unit 必须是简短中文单位，例如 个、把、袋、盒、瓶、包、克、千克、毫升、升。"
                "category 只能是 蔬菜、水果、肉类、海鲜、乳制品、饮料、调料、主食、速食、其他 之一。"
                "expiry 必须是 YYYY-MM-DD 格式；如果用户没有提供有效日期，就填空字符串。"
                "minQuantity 默认为 0，除非用户明确提到提醒值。"
                "note 用于保留原文中的备注、品牌、位置、用途等信息，没有就填空字符串。"
                "如果一句话里提到多个食材，必须拆成多条记录。"
                "如果信息不足，做最保守的合理推断，但不要编造不存在的品牌、日期或规格。"
                f"今天日期是 {today}，如果用户说今天、明天、后天，请换算成具体日期。"
            ),
        },
        {
            "role": "user",
            "content": f"请解析下面这段库存录入文本，并直接返回 JSON 数组：\n{raw_text.strip()}",
        },
    ]


def extract_json_block(text):
    cleaned = (text or "").strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)

    for start_char, end_char in (("[", "]"), ("{", "}")):
        start = cleaned.find(start_char)
        end = cleaned.rfind(end_char)
        if start == -1 or end == -1 or end <= start:
            continue
        candidate = cleaned[start:end + 1]
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            continue

    return json.loads(cleaned)


def parse_bulk_import_items(raw_text):
    payload = extract_json_block(request_qwen_text(build_bulk_import_prompt(raw_text), temperature=0.2))
    items = payload.get("items") if isinstance(payload, dict) else payload

    if not isinstance(items, list):
        raise ValueError("AI 返回格式无效，未解析出库存列表")

    normalized_items = []
    for item in items:
        if not isinstance(item, dict):
            continue
        normalized_items.append(parse_item_payload(item, partial=False))

    if not normalized_items:
        raise ValueError("未从文本中解析出可导入的库存项目")

    return normalized_items


def request_qwen_text(messages, temperature=0.6):
    if not QWEN_API_KEY:
        raise RuntimeError("后端未配置 QWEN_API_KEY 或 DASHSCOPE_API_KEY。")

    payload = {
        "model": QWEN_MODEL,
        "messages": messages,
        "temperature": temperature,
    }
    headers = {
        "Authorization": f"Bearer {QWEN_API_KEY}",
        "Content-Type": "application/json",
    }

    last_error = None
    for base_url in QWEN_BASE_URLS:
        try:
            response = requests.post(base_url, headers=headers, json=payload, timeout=(15, 120))
            if response.status_code >= 400:
                last_error = f"{base_url} -> {response.status_code} {response.text}"
                continue

            data = response.json()
            return ((data.get("choices") or [{}])[0].get("message") or {}).get("content", "").strip()
        except (requests.RequestException, ValueError) as exc:
            last_error = f"{base_url} -> {exc}"

    raise RuntimeError(last_error or "Qwen 调用失败")


def get_daily_advice():
    today = datetime.now().date().isoformat()
    cache = load_daily_advice_cache()

    if cache.get("date") == today and cache.get("advice"):
        return {
            "date": today,
            "advice": cache["advice"],
            "cached": True,
        }

    advice = request_qwen_text(build_daily_advice_prompt(), temperature=0.5)
    cache = {
        "date": today,
        "advice": advice,
    }
    save_daily_advice_cache(cache)
    return {
        "date": today,
        "advice": advice,
        "cached": False,
    }


def stream_qwen_recipe_response(user_query):
    if not QWEN_API_KEY:
        yield f"data: {json.dumps({'type': 'error', 'message': '后端未配置 QWEN_API_KEY 或 DASHSCOPE_API_KEY。'}, ensure_ascii=False)}\n\n"
        return

    payload = {
        "model": QWEN_MODEL,
        "messages": build_recipe_prompt(user_query),
        "stream": True,
        "temperature": 0.7,
        "stream_options": {"include_usage": True},
    }
    headers = {
        "Authorization": f"Bearer {QWEN_API_KEY}",
        "Content-Type": "application/json",
    }

    last_error = None

    for base_url in QWEN_BASE_URLS:
        try:
            with requests.post(base_url, headers=headers, json=payload, stream=True, timeout=(15, 300)) as response:
                if response.status_code >= 400:
                    last_error = f"{base_url} -> {response.status_code} {response.text}"
                    continue

                for line in response.iter_lines(decode_unicode=True):
                    if not line or not line.startswith("data: "):
                        continue

                    data = line[6:]
                    if data == "[DONE]":
                        yield f"data: {json.dumps({'type': 'done'}, ensure_ascii=False)}\n\n"
                        return

                    try:
                        chunk = json.loads(data)
                    except json.JSONDecodeError:
                        continue

                    choice = (chunk.get("choices") or [{}])[0]
                    delta = choice.get("delta") or {}
                    content = delta.get("content")
                    if content:
                        yield f"data: {json.dumps({'type': 'chunk', 'content': content}, ensure_ascii=False)}\n\n"

                yield f"data: {json.dumps({'type': 'done'}, ensure_ascii=False)}\n\n"
                return
        except requests.RequestException as exc:
            last_error = f"{base_url} -> {exc}"

    error_message = f"调用 Qwen 失败: {last_error or '未知错误'}"
    yield f"data: {json.dumps({'type': 'error', 'message': error_message}, ensure_ascii=False)}\n\n"


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


@app.route("/api/inventory/bulk-import", methods=["POST"])
def bulk_import_items():
    try:
        data = request.get_json(silent=True) or {}
        raw_text = str(data.get("text", "")).strip()
        if not raw_text:
            return jsonify({"error": "请先输入要解析的文本"}), 400
        if not QWEN_API_KEY:
            return jsonify({"error": "后端未配置 QWEN_API_KEY 或 DASHSCOPE_API_KEY。"}), 500

        payloads = parse_bulk_import_items(raw_text)
        inventory = load_inventory()
        created_items = []

        for index, payload in enumerate(payloads):
            created_items.append(normalize_item({
                "id": int(datetime.now().timestamp() * 1000000) + index,
                "addedDate": datetime.now().isoformat(),
                **payload,
            }))

        save_inventory(created_items + inventory)
        return jsonify({
            "success": True,
            "added": len(created_items),
            "items": [serialize_item(item) for item in created_items],
        }), 201
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
        delta = float(data.get("delta", 0))
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
                    "unit": item.get("unit", "个"),
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


@app.route("/api/daily-advice", methods=["GET"])
def daily_advice():
    try:
        return jsonify(get_daily_advice())
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/api/recipe-suggestions/stream", methods=["POST"])
def recipe_suggestions_stream():
    data = request.get_json(silent=True) or {}
    user_query = str(data.get("query", "")).strip()

    response = Response(
        stream_with_context(stream_qwen_recipe_response(user_query)),
        mimetype="text/event-stream",
    )
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"
    return response


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

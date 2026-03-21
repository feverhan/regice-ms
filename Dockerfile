FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=5000
ENV HOST=0.0.0.0
ENV QWEN_MODEL=qwen-plus
ENV QWEN_BASE_URLS=https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions,https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions
ENV FLASK_DEBUG=false

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./
COPY templates ./templates
COPY static ./static

RUN mkdir -p /app/data

EXPOSE 5000

CMD ["sh", "-c", "gunicorn -b ${HOST:-0.0.0.0}:${PORT:-5000} --workers 2 --threads 4 --timeout 60 app:app"]

FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=5000

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./
COPY templates ./templates

RUN mkdir -p /app/data

EXPOSE 5000

CMD ["gunicorn", "-b", "0.0.0.0:5000", "--workers", "2", "--threads", "4", "--timeout", "60", "app:app"]

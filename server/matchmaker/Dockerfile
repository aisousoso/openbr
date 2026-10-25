FROM python:3.11-slim

WORKDIR /app
COPY . /app

RUN pip install --no-cache-dir flask

EXPOSE 8080
CMD ["python", "matchmaker.py"]
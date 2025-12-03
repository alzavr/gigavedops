from flask import Flask
import os
import psycopg2

app = Flask(__name__)

@app.route('/')
def hello():
    app_name = os.environ.get('APP_NAME', 'UnknownApp')

    db_user = os.environ.get("DB_USER")
    db_pass = os.environ.get("DB_PASSWORD")
    db_host = os.environ.get("DB_HOST", "postgres")
    db_name = os.environ.get("DB_NAME", "postgres")

    # Проверяем подключение
    try:
        conn = psycopg2.connect(
            dbname=db_name,
            user=db_user,
            password=db_pass,
            host=db_host
        )
        conn.close()
        db_status = "DB connection OK"
    except Exception as e:
        db_status = f"DB connection FAILED: {e}"

    return f"Hello from {app_name} — {db_status}"

if __name__ == '__main__':
    port = int(os.environ.get('APP_PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)

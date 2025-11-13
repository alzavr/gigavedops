from flask import Flask
import psycopg2

app = Flask(__name__)

@app.route("/")
def home():
    try:
        conn = psycopg2.connect(
            dbname="flaskdb",
            user="flaskuser",
            password="password123",
            host="db"
        )
        conn.close()
        return "Connected to the database successfully!"
    except Exception as e:
        return f"Error: {e}"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
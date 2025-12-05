from flask import Flask
import os

app = Flask(__name__)

def read_file(path, default="Unknown"):
    try:
        with open(path, "r") as f:
            return f.read().strip()
    except:
        return default

@app.route('/')
def hello():
    app_name = read_file("/config/APP_NAME", "UnknownApp")
    app_port = read_file("/config/APP_PORT", "5000")
    secret_word = read_file("/secret/SECRET_WORD", "UnknownSecret")

    return f"Hello from {app_name}. Secret word is {secret_word}. App port: {app_port}"

if __name__ == '__main__':
    port = int(os.environ.get('APP_PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
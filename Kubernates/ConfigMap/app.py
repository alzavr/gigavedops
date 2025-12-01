from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    app_name = os.environ.get('APP_NAME', 'UnknownApp')
    return f"Hello from {app_name}"

if __name__ == '__main__':
    port = int(os.environ.get('APP_PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
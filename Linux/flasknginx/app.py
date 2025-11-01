from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return "Hello from {SERVER_NAME}"

if __name__ == '__main__':
    port = int(os.environ.get('PORT'))
    app.run(host='0.0.0.0', port=port, debug=False)
from flask import Flask, request, render_template_string
import requests
import os

app = Flask(__name__)

BACKEND_URL = os.getenv("BACKEND_URL", "http://backend-api")

HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>Users</title>
</head>
<body>
    <h2>Get user from backend</h2>

    <form method="get">
        <label>User ID:</label>
        <input type="number" name="id" required>
        <button type="submit">Get user</button>
    </form>

    {% if result %}
        <h3>Result:</h3>
        <pre>{{ result }}</pre>
    {% endif %}

    {% if error %}
        <h3 style="color:red;">Error:</h3>
        <pre>{{ error }}</pre>
    {% endif %}
</body>
</html>
"""

@app.route("/", methods=["GET"])
def home():
    user_id = request.args.get("id")

    if not user_id:
        return render_template_string(HTML)

    try:
        resp = requests.get(
            f"{BACKEND_URL}/user",
            params={"id": user_id},
            timeout=3
        )

        if resp.status_code != 200:
            return render_template_string(
                HTML,
                error=resp.text
            )

        return render_template_string(
            HTML,
            result=resp.json()
        )

    except Exception as e:
        return render_template_string(
            HTML,
            error=str(e)
        )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

from flask import Flask, request, render_template, render_template_string, redirect, url_for, session, flash
import os
import secrets
import tempfile
from datetime import timedelta
from flask_session import Session

app = Flask(__name__)

app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY') or secrets.token_urlsafe(64)
os.environ["FLAG"] = 'flag{a8b489561ef8142d6eceaf37727683cc60c5d8a1fbdcabf19c22840fe74654a3}'

app.config['DEBUG'] = True

app.config.update({
    'SESSION_COOKIE_SECURE': bool(os.environ.get('SESSION_COOKIE_SECURE', 'False') == 'True'),
    'SESSION_COOKIE_HTTPONLY': True,
    'SESSION_COOKIE_SAMESITE': 'Lax',  # 'Strict' is stricter but may break some flows
    'PERMANENT_SESSION_LIFETIME': timedelta(hours=2),
})

app.config.update({
    'SESSION_TYPE': os.environ.get('SESSION_TYPE', 'filesystem'),
    'SESSION_FILE_DIR': os.environ.get('SESSION_FILE_DIR') or tempfile.mkdtemp(prefix="flask_session_"),
    'SESSION_PERMANENT': True,
    'SESSION_USE_SIGNER': True,  # signs the session id cookie
})

Session(app)

# ---------------------------
# In-memory "database"
# ---------------------------
# Preserved the same hashed strings you had previously (login compares raw input to these strings).
USERS = [
    {"id": 1, "username": "admin", "password": "f865b53623b121fd34ee5426c792e5c33af8c227"},
    {"id": 2, "username": "guest", "password": "7cf7eddb174125539dd241cd745391694250e526"},
]

def find_user_by_username_and_password(username, password):
    """
    Intentionally simple lookup that mirrors original behavior:
    stored 'password' values are the same strings you used before, so this compares raw input.
    """
    for u in USERS:
        if u["username"] == username and u["password"] == password:
            return u
    return None

# ---------------------------
# Routes
# ---------------------------
@app.route('/')
def index():
    return redirect(url_for('login'))

@app.route('/login', methods=['GET','POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form.get('username', '')
        password = request.form.get('password', '')

        try:
            row = find_user_by_username_and_password(username, password)
        except Exception as e:
            error = f"Lookup error: {e}"
            row = None

        if row:
            session.clear()
            session.permanent = True
            session['user'] = row['username']
            flash(f"Welcome, {row['username']}!")
            return redirect(url_for('dashboard'))
        else:
            error = error or "Invalid credentials"
    return render_template('login.html', error=error)

# --- SSTI LAB ENDPOINTS ---
@app.route('/dashboard', methods=['GET', 'POST'])
def dashboard():
    """
    INTENTIONAL SSTI:
    Renders user input directly as a Jinja2 template using render_template_string.
    Try payloads like:  {{ 7*7 }}  or  {{ config.items() }}
    """
    if 'user' not in session:
        return redirect(url_for('login'))

    payload = ''
    out = ''
    if request.method == 'POST':
        payload = request.form.get('payload', '')
        try:
            out = render_template_string(payload)
        except Exception as e:
            out = f"Template error: {e}"
    return render_template('dashboard.html', payload=payload, out=out)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

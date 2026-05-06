"""
IVRPMS Flask application.

Reads DB credentials from environment variables (see .env.example).
Falls back to localhost defaults for local development.
"""
import os
import datetime
from decimal import Decimal

from flask import Flask, jsonify, request, send_from_directory
import mysql.connector

app = Flask(__name__, static_folder='.')

DB_CONFIG = {
    "host":     os.environ.get("MYSQL_HOST", "localhost"),
    "port":     int(os.environ.get("MYSQL_PORT", "3306")),
    "user":     os.environ.get("MYSQL_USER", "root"),
    "password": os.environ.get("MYSQL_PASSWORD", ""),
    "database": os.environ.get("MYSQL_DATABASE", "ivrpms"),
}


def get_conn():
    return mysql.connector.connect(**DB_CONFIG)


def query(sql, params=None):
    conn = get_conn()
    cur = conn.cursor(dictionary=True)
    cur.execute(sql, params or ())
    rows = cur.fetchall()
    cur.close()
    conn.close()
    clean = []
    for row in rows:
        clean_row = {}
        for k, v in row.items():
            if isinstance(v, Decimal):
                clean_row[k] = float(v)
            elif isinstance(v, (datetime.date, datetime.datetime)):
                clean_row[k] = v.isoformat()
            else:
                clean_row[k] = v
        clean.append(clean_row)
    return clean


def execute(sql, params=None):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(sql, params or ())
    conn.commit()
    result = {"lastrowid": cur.lastrowid, "rowcount": cur.rowcount}
    cur.close()
    conn.close()
    return result


def insert_veteran(d):
    """Shared insert logic used by both POST routes."""
    required = ['veteran_id', 'service_number', 'full_name', 'date_of_birth',
                'gender', 'rank_name', 'regiment_id', 'date_of_enlistment']
    missing = [f for f in required if not str(d.get(f, '')).strip()]
    if missing:
        return None, 'Missing: ' + ', '.join(missing)

    try:
        vid = int(d['veteran_id'])
    except (ValueError, TypeError):
        return None, 'Veteran ID must be a number'

    existing = query("SELECT veteran_id FROM VETERAN WHERE veteran_id = %s", (vid,))
    if existing:
        return None, f'Veteran ID {vid} already exists. Please choose a different ID.'

    execute("""
        INSERT INTO VETERAN
          (veteran_id, service_number, full_name, date_of_birth, gender, rank_name,
           regiment_id, date_of_enlistment, date_of_retirement,
           status, state_of_domicile, contact_number, aadhar_ref)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
    """, (
        vid,
        d['service_number'], d['full_name'], d['date_of_birth'],
        d['gender'], d['rank_name'], int(d['regiment_id']),
        d['date_of_enlistment'], d.get('date_of_retirement') or None,
        d.get('status', 'Active'), d.get('state_of_domicile') or None,
        d.get('contact_number') or None, d.get('aadhar_ref') or None,
    ))
    return vid, None


@app.route('/')
def index():
    return send_from_directory('.', 'index.html')


@app.route('/api/health')
def health():
    try:
        query("SELECT 1 AS ok")
        return jsonify({"status": "ok", "db": "connected"})
    except Exception as e:
        return jsonify({"status": "error", "db": str(e)}), 500


@app.route('/api/stats')
def stats():
    data = query("""
        SELECT
            (SELECT COUNT(*) FROM VETERAN) AS veterans,
            (SELECT COUNT(*) FROM PENSION_RECORD WHERE payment_status='Active') AS active_pensions,
            (SELECT COUNT(*) FROM NOMINEE WHERE is_active='Y') AS nominees,
            (SELECT COUNT(*) FROM REGIMENT) AS regiments,
            (SELECT COALESCE(SUM(monthly_amount*(1+da_percentage/100)),0)
               FROM PENSION_RECORD WHERE payment_status='Active') AS monthly_disbursement
    """)[0]
    return jsonify(data)


@app.route('/api/recent_veterans')
def recent_veterans():
    rows = query("""
        SELECT V.full_name AS NAME, V.rank_name, R.regiment_name AS REGIMENT,
               V.date_of_retirement AS DISCHARGE_DATE
        FROM VETERAN V JOIN REGIMENT R ON V.regiment_id=R.regiment_id
        ORDER BY V.veteran_id DESC LIMIT 5
    """)
    return jsonify(rows)


@app.route('/api/top_pensions')
def top_pensions():
    rows = query("""
        SELECT V.full_name AS NAME, V.rank_name,
               P.monthly_amount AS AMOUNT, P.da_percentage AS DA_PERCENT,
               ROUND(P.monthly_amount*(1+P.da_percentage/100),2) AS TOTAL,
               P.payment_status AS STATUS
        FROM PENSION_RECORD P JOIN VETERAN V ON P.veteran_id=V.veteran_id
        ORDER BY P.monthly_amount DESC LIMIT 5
    """)
    return jsonify(rows)


@app.route('/api/veterans', methods=['GET', 'POST'])
def veterans():
    if request.method == 'GET':
        rows = query("""
            SELECT V.veteran_id AS VID, V.full_name AS NAME, V.rank_name,
                   V.date_of_birth AS DOB, V.date_of_retirement AS DISCHARGE_DATE,
                   FLOOR(DATEDIFF(COALESCE(V.date_of_retirement,CURDATE()),
                         V.date_of_enlistment)/365) AS SERVICE_YEARS,
                   R.regiment_name AS REGIMENT, V.status AS STATUS
            FROM VETERAN V JOIN REGIMENT R ON V.regiment_id=R.regiment_id
            ORDER BY V.veteran_id
        """)
        return jsonify(rows)
    try:
        d = request.get_json(force=True)
        vid, err = insert_veteran(d)
        if err:
            return jsonify({'success': False, 'error': err}), 400
        return jsonify({'success': True, 'veteran_id': vid,
                        'message': f"Veteran '{d['full_name']}' enlisted successfully."}), 201
    except mysql.connector.IntegrityError as e:
        return jsonify({'success': False, 'error': str(e)}), 409
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/veterans/add', methods=['POST'])
def veterans_add():
    try:
        d = request.get_json(force=True)
        vid, err = insert_veteran(d)
        if err:
            return jsonify({'success': False, 'error': err}), 400
        return jsonify({'success': True, 'veteran_id': vid,
                        'message': f"Veteran '{d['full_name']}' enlisted successfully."}), 201
    except mysql.connector.IntegrityError as e:
        return jsonify({'success': False, 'error': str(e)}), 409
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/veterans/<int:vid>/rank', methods=['POST'])
def update_rank(vid):
    """
    Update a veteran's rank_name. The trg_rank_change_log AFTER UPDATE
    trigger fires automatically and inserts an audit row into RANK_HISTORY.
    """
    try:
        d = request.get_json(force=True) or {}
        new_rank = (d.get('new_rank') or '').strip()
        if not new_rank:
            return jsonify({'success': False, 'error': 'new_rank is required'}), 400

        existing = query(
            "SELECT veteran_id, full_name, rank_name FROM VETERAN WHERE veteran_id=%s",
            (vid,)
        )
        if not existing:
            return jsonify({'success': False, 'error': f'Veteran {vid} not found'}), 404

        old_rank = existing[0]['rank_name']
        if old_rank == new_rank:
            return jsonify({'success': False,
                            'error': f'Veteran already holds rank "{new_rank}"'}), 400

        execute(
            "UPDATE VETERAN SET rank_name=%s WHERE veteran_id=%s",
            (new_rank, vid)
        )

        return jsonify({
            'success':   True,
            'veteran_id': vid,
            'name':      existing[0]['full_name'],
            'old_rank':  old_rank,
            'new_rank':  new_rank,
            'message':   'Rank updated. Trigger logged change to RANK_HISTORY.'
        })
    except mysql.connector.IntegrityError as e:
        return jsonify({'success': False, 'error': str(e)}), 409
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/pensions')
def pensions():
    rows = query("""
        SELECT P.pension_id AS PID, V.full_name AS NAME, V.rank_name,
               R.regiment_name AS REGIMENT,
               P.monthly_amount AS AMOUNT, P.da_percentage AS DA_PERCENT,
               ROUND(P.monthly_amount*(1+P.da_percentage/100),2) AS TOTAL,
               P.payment_status AS STATUS, P.pension_start_date AS START_DATE
        FROM PENSION_RECORD P
        JOIN VETERAN V ON P.veteran_id=V.veteran_id
        JOIN REGIMENT R ON V.regiment_id=R.regiment_id
        ORDER BY P.pension_id
    """)
    return jsonify(rows)


@app.route('/api/nominees')
def nominees():
    rows = query("""
        SELECT N.nominee_id AS NID, N.nominee_name AS NOMINEE,
               N.relationship AS RELATION, V.full_name AS VETERAN,
               N.share_percentage AS SHARE_PERCENT
        FROM NOMINEE N JOIN VETERAN V ON N.veteran_id=V.veteran_id
        ORDER BY N.nominee_id
    """)
    return jsonify(rows)


@app.route('/api/regiments')
def regiments():
    rows = query("""
        SELECT R.regiment_id AS RID, R.regiment_name AS NAME,
               R.base_location AS LOCATION, R.arm_of_service AS ARM,
               COUNT(V.veteran_id) AS VETERAN_COUNT
        FROM REGIMENT R LEFT JOIN VETERAN V ON R.regiment_id=V.regiment_id
        GROUP BY R.regiment_id,R.regiment_name,R.base_location,R.arm_of_service
        ORDER BY R.regiment_id
    """)
    return jsonify(rows)


@app.route('/api/regiments_list')
def regiments_list():
    rows = query("""
        SELECT regiment_id AS id, regiment_name AS name,
               base_location AS location, arm_of_service AS arm
        FROM REGIMENT ORDER BY regiment_name
    """)
    return jsonify(rows)


@app.route('/api/rank_log')
def rank_log():
    rows = query("""
        SELECT RH.veteran_id AS VID, V.full_name AS NAME,
               RH.old_rank AS OLD_RANK, RH.new_rank AS NEW_RANK,
               RH.changed_on AS CHANGED_AT, RH.changed_by AS CHANGED_BY
        FROM RANK_HISTORY RH JOIN VETERAN V ON RH.veteran_id=V.veteran_id
        ORDER BY RH.changed_on DESC
    """)
    return jsonify(rows)


@app.route('/api/schema')
def schema():
    rows = query("""
        SELECT TABLE_NAME, TABLE_ROWS, CREATE_TIME
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA=%s ORDER BY TABLE_NAME
    """, (DB_CONFIG["database"],))
    return jsonify(rows)


if __name__ == '__main__':
    port = int(os.environ.get("PORT", "5000"))
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"
    app.run(host="0.0.0.0", port=port, debug=debug)

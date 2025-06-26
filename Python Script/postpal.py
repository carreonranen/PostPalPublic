# Libraries
import os
import time
import threading
import datetime
import smtplib

from flask import Flask, jsonify
from hx711 import HX711
import RPi.GPIO as GPIO

from google.cloud import storage
import firebase_admin
from firebase_admin import credentials, db, messaging

from picamzero import Camera
from time import sleep
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from key.py import SERVICE_ACCOUNT, RTDB_URL, BUCKET_NAME, user, pwd

# Local directories for media
LOCAL_PIC_DIR = "/home/group4/PostPal/Pictures"
LOCAL_VIDEO_DIR = "/home/group4/PostPal/Videos"

# Cloud Storage prefixes
PICTURE_FOLDER = "images/"
VIDEO_FOLDER = "videos/"

UPDATE_INTERVAL = 10      # secs between weight reads & RTDB writes
IGNORE_WINDOW = 3       # secs after motion to suppress alerts
WEIGHT_THRESHOLD = 20      # grams threshold for weight alert
COOLDOWN = 3600    # secs between weight alerts
VIDEO_DURATION_SEC = 5       # record 5s videos on motion


# ensure local directories exist
os.makedirs(LOCAL_PIC_DIR, exist_ok=True)
os.makedirs(LOCAL_VIDEO_DIR, exist_ok=True)

# Initialize Firebase credentials
cred = credentials.Certificate(SERVICE_ACCOUNT)
firebase_admin.initialize_app(cred, {
    'databaseURL':    RTDB_URL,
    'storageBucket':  BUCKET_NAME,
})

# Cloud Storage client
storage_client = storage.Client.from_service_account_json(SERVICE_ACCOUNT)
bucket = storage_client.bucket(BUCKET_NAME)

# Flask API
app = Flask(__name__)
current_weight = 0.0
last_motion_time = "Never"


@app.route('/weight')
def get_weight():
    return jsonify(weight=current_weight)


@app.route('/motion')
def get_motion():
    return jsonify(last_motion=last_motion_time)


# start HTTP server in background
threading.Thread(
    target=lambda: app.run(host="0.0.0.0", port=8080,
                           debug=False, use_reloader=False),
    daemon=True
).start()


def upload_to_storage(local_path: str, storage_path: str):
    blob = bucket.blob(storage_path)
    blob.upload_from_filename(local_path)
    print(f"Uploaded gs://{BUCKET_NAME}/{storage_path}")


def take_and_upload_video():
    """Record a VIDEO for VIDEO_DURATION_SEC, save locally, upload & log to RTDB."""
    now = datetime.datetime.now()
    fname = now.strftime("%Y_%m_%d_%H_%M_%S") + ".mp4"
    local_file = os.path.join(LOCAL_VIDEO_DIR, fname)
    storage_path = VIDEO_FOLDER + fname

    try:
        cam = Camera()
        # record_video returns filename but we ignore it
        cam.record_video(local_file, duration=VIDEO_DURATION_SEC)
        print(f"Recorded video: {local_file}")
    except Exception as e:
        print("ERROR!!! Video capture failed:", e)
        return

    # upload to Cloud Storage
    try:
        upload_to_storage(local_file, storage_path)
    except Exception as e:
        print("ERROR!!!Video upload failed:", e)

    # log it under RTDB: mailbox/status/videos
    try:
        db.reference("mailbox/status/videos").push({
            'path':      storage_path,
            'timestamp': int(now.timestamp()),
        })
        print("? Video record pushed to RTDB")
    except Exception as e:
        print("ERROR!!! Failed to push video record:", e)


#R
def email_alert(subject: str, body: str) -> bool:
    msg = MIMEMultipart()
    msg["From"], msg["To"], msg["Subject"] = user, user, subject
    msg.attach(MIMEText(body, "plain"))
    try:
        s = smtplib.SMTP("smtp.gmail.com", 587)
        s.starttls()
        s.login(user, pwd)
        s.sendmail(user, [user], msg.as_string())
        s.quit()
        print("Email sent")
        return True
    except Exception as e:
        print("Email failed:", e)
        return False


def firebase_alert(title: str, body: str) -> bool:
    msg = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        topic='mailboxAlerts'
    )
    try:
        res = messaging.send(msg)
        print("FCM sent:", res)
        return True
    except Exception as e:
        print("FCM failed:", e)
        return False


#Hardware setup
GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

hx = HX711(6, 5, gain=128)
hx.reset()
time.sleep(1)
print("Taring scale")
hx.tare(25)
print("Calibration?")
hx.set_reference_unit(-280.91)

motion_pin = 23
GPIO.setup(motion_pin, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)

print("Stabilizing PIR for 20s")
time.sleep(20)
print("Entering main loop\n")

last_motion_state = False
last_motion_alert = time.time()
last_weight_alert = 0
last_update_time = 0

while True:
    now = time.time()
    state = GPIO.input(motion_pin)

    # Motion detection(rising edge + cooldown)
    if state and not last_motion_state and (now - last_motion_alert) > IGNORE_WINDOW:
        last_motion_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        last_motion_alert = now
        print(f"Motion detected at {last_motion_time}")

        # record & upload a 5s video
        take_and_upload_video()

        # also push only the timestamp under RTDB/motions
        try:
            db.reference("mailbox/status/motions").push(int(now))
            print("Motion timestamp pushed")
        except Exception as e:
            print("Motion push failed:", e)

    last_motion_state = state

    # ?? Periodic weight read & RTDB write ??
    if now - last_update_time >= UPDATE_INTERVAL:
        last_update_time = now
        try:
            w = hx.get_weight(25)
        except AttributeError:
            raw = hx.get_value(25)
            w = raw / -280.91
        w = round(max(w, 0), 2)
        current_weight = w
        print(f"[{time.strftime('%H:%M:%S')}] Weight: {w:.2f} g")

        try:
            db.reference("mailbox/status").update({
                "weight":      current_weight,
                "last_motion": last_motion_time,
                "updated_at":  int(now)
            })
            print("RTDB updated")
        except Exception as e:
            print("RTDB write failed:", e)

        # weight alert?
        if (w > WEIGHT_THRESHOLD and
            (now - last_weight_alert) > COOLDOWN and
                (now - last_motion_alert) > IGNORE_WINDOW):
            subj = "Mail Detected!"
            body = f"Mailbox weight: {w:.2f} g"
            if email_alert(subj, body) and firebase_alert(subj, body):
                last_weight_alert = now
                print("Weight alert sent")

    time.sleep(1)

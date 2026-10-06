from flask import Flask, request
from flask_cors import CORS
import psycopg2
import os
import boto3

app = Flask(__name__)

cloudwatch = boto3.client("cloudwatch", region_name="us-east-1")

def initialise_database():
    connection = psycopg2.connect(
        host=os.environ["DB_HOST"],
        database="gymtracker",
        user="gymuser",
        password=os.environ["DB_PASSWORD"]
    )

    cursor = connection.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS workouts (
            id SERIAL PRIMARY KEY,
            exercise_name VARCHAR(255) NOT NULL,
            sets INTEGER NOT NULL,
            reps INTEGER NOT NULL,
            weight NUMERIC NOT NULL
        )
    """)

    connection.commit()

    try:
        cloudwatch.put_metric_data(
            Namespace="GymTracker",
            MetricData=[
                {
                    "MetricName": "WorkoutAdded",
                    "Value": 1,
                    "Unit": "Count"
                }
            ]
        )
    except Exception as error:
        print(f"CloudWatch metric failed: {error}")

    cursor.close()
    connection.close()

@app.route("/")
def home():
    return {"message": "Gym Tracker API is running"}


@app.route("/workouts")
def get_workouts():

    connection = psycopg2.connect(
        host=os.environ["DB_HOST"],
        database="gymtracker",
        user="gymuser",
        password=os.environ["DB_PASSWORD"]
    )

    cursor = connection.cursor()

    cursor.execute(
        "SELECT id, exercise_name, sets, reps, weight FROM workouts"
    )

    rows = cursor.fetchall()

    workouts = []

    for row in rows:
        workouts.append({
            "id": row[0],
            "exercise_name": row[1],
            "sets": row[2],
            "reps": row[3],
            "weight": float(row[4]),
            "volume": row[2] * row[3] * float(row[4])
        })

    cursor.close()
    connection.close()

    return workouts

@app.route("/workouts", methods=["POST"])
def add_workout():
    data = request.get_json()

    exercise_name = data["exercise_name"]
    sets = int(data["sets"])
    reps = int(data["reps"])
    weight = float(data["weight"])

    connection = psycopg2.connect(
        host=os.environ["DB_HOST"],
        database="gymtracker",
        user="gymuser",
        password=os.environ["DB_PASSWORD"]
    )

    cursor = connection.cursor()

    cursor.execute(
        """
        INSERT INTO workouts (exercise_name, sets, reps, weight)
        VALUES (%s, %s, %s, %s)
        RETURNING id
        """,
        (exercise_name, sets, reps, weight)
    )

    workout_id = cursor.fetchone()[0]

    connection.commit()
    cursor.close()
    connection.close()

    return {
        "id": workout_id,
        "exercise_name": exercise_name,
        "sets": sets,
        "reps": reps,
        "weight": weight,
        "volume": sets * reps * weight
    }, 201

@app.route("/workouts/<int:workout_id>", methods=["PUT"])
def update_workout(workout_id):
    data = request.get_json()

    exercise_name = data["exercise_name"]
    sets = int(data["sets"])
    reps = int(data["reps"])
    weight = float(data["weight"])

    connection = psycopg2.connect(
        host=os.environ["DB_HOST"],
        database="gymtracker",
        user="gymuser",
        password=os.environ["DB_PASSWORD"]
    )

    cursor = connection.cursor()

    cursor.execute(
        """
        UPDATE workouts
        SET exercise_name = %s,
            sets = %s,
            reps = %s,
            weight = %s
        WHERE id = %s
        """,
        (exercise_name, sets, reps, weight, workout_id)
    )

    connection.commit()
    cursor.close()
    connection.close()

    return {
        "id": workout_id,
        "exercise_name": exercise_name,
        "sets": sets,
        "reps": reps,
        "weight": weight,
        "volume": sets * reps * weight
    }

if __name__ == "__main__":
    initialise_database()
    app.run(host="0.0.0.0", port=5000)
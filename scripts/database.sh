#!/usr/bin/env bash
set -e

sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib

sudo systemctl enable postgresql
sudo systemctl start postgresql

sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" \
  /etc/postgresql/14/main/postgresql.conf

if ! grep -q "gymtracker.*gymuser.*192.168.56.11" /etc/postgresql/14/main/pg_hba.conf; then
  echo "host    gymtracker    gymuser    192.168.56.11/32    scram-sha-256" \
    | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
fi

sudo systemctl restart postgresql

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='gymuser'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE USER gymuser WITH PASSWORD 'gympassword';"
fi

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='gymtracker'" | grep -q 1; then
  sudo -u postgres createdb -O gymuser gymtracker
fi

sudo -u postgres psql -d gymtracker -c \
  "ALTER SCHEMA public OWNER TO gymuser;"

sudo -u postgres psql -d gymtracker <<'EOF'
CREATE TABLE IF NOT EXISTS workouts (
    id SERIAL PRIMARY KEY,
    exercise_name VARCHAR(100) NOT NULL,
    sets INTEGER NOT NULL,
    reps INTEGER NOT NULL,
    weight NUMERIC(6,2) NOT NULL
);
EOF

sudo -u postgres psql -d gymtracker <<'EOF'
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE workouts TO gymuser;
GRANT USAGE, SELECT ON SEQUENCE workouts_id_seq TO gymuser;
EOF

sudo -u postgres psql -d gymtracker <<'EOF'
INSERT INTO workouts (exercise_name, sets, reps, weight)
SELECT *
FROM (
    VALUES
        ('Bench Press', 3, 10, 70.00),
        ('Lat Pulldown', 3, 12, 60.00),
        ('Squat', 4, 8, 100.00)
) AS demo(exercise_name, sets, reps, weight)
WHERE NOT EXISTS (
    SELECT 1 FROM workouts
);
EOF
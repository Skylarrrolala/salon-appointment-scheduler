#! /bin/bash
# Salon appointment scheduler. SQL variables safely quote customer input.
set -u
PSQL=(psql -X --username=freecodecamp --dbname=salon --no-align --tuples-only --quiet -v ON_ERROR_STOP=1)
db() { "${PSQL[@]}" "$@"; }
printf '\n~~~~~ MY SALON ~~~~~\n\nWelcome to My Salon, how can I help you?\n\n'
while true; do
  db <<'SQL'
SELECT service_id || ') ' || name FROM services ORDER BY service_id;
SQL
  read SERVICE_ID_SELECTED || exit 0
  SERVICE_NAME=''
  if [[ $SERVICE_ID_SELECTED =~ ^[0-9]{1,9}$ ]]; then
    SERVICE_NAME=$(db -v selected="$SERVICE_ID_SELECTED" <<'SQL'
SELECT name FROM services WHERE service_id = :'selected'::integer;
SQL
) || exit 1
  fi
  [[ -n $SERVICE_NAME ]] && break
  printf '\nI could not find that service. What would you like today?\n\n'
done
printf "\nWhat's your phone number?\n"
read CUSTOMER_PHONE || exit 0
while [[ -z ${CUSTOMER_PHONE//[[:space:]]/} ]]; do
  printf 'Please enter a phone number:\n'
  read CUSTOMER_PHONE || exit 0
done
CUSTOMER_ID=$(db -v phone="$CUSTOMER_PHONE" <<'SQL'
SELECT customer_id FROM customers WHERE phone = :'phone';
SQL
) || exit 1
if [[ -z $CUSTOMER_ID ]]; then
  printf "\nI don't have a record for that phone number, what's your name?\n"
  read CUSTOMER_NAME || exit 0
  while [[ -z ${CUSTOMER_NAME//[[:space:]]/} ]]; do
    printf 'Please enter your name:\n'
    read CUSTOMER_NAME || exit 0
  done
  CUSTOMER_ID=$(db -v name="$CUSTOMER_NAME" -v phone="$CUSTOMER_PHONE" <<'SQL'
INSERT INTO customers(name, phone) VALUES (:'name', :'phone') RETURNING customer_id;
SQL
) || exit 1
else
  CUSTOMER_NAME=$(db -v phone="$CUSTOMER_PHONE" <<'SQL'
SELECT name FROM customers WHERE phone = :'phone';
SQL
) || exit 1
fi
printf '\nWhat time would you like your %s, %s?\n' "$SERVICE_NAME" "$CUSTOMER_NAME"
read SERVICE_TIME || exit 0
while [[ -z ${SERVICE_TIME//[[:space:]]/} ]]; do
  printf 'Please enter an appointment time:\n'
  read SERVICE_TIME || exit 0
done
if ! db -v customer_id="$CUSTOMER_ID" -v service_id="$SERVICE_ID_SELECTED" -v service_time="$SERVICE_TIME" <<'SQL' >/dev/null
INSERT INTO appointments(customer_id, service_id, time) VALUES (:'customer_id'::integer, :'service_id'::integer, :'service_time');
SQL
then
  printf 'Sorry, your appointment could not be booked.\n' >&2
  exit 1
fi
printf '\nI have put you down for a %s at %s, %s.\n' "$SERVICE_NAME" "$SERVICE_TIME" "$CUSTOMER_NAME"

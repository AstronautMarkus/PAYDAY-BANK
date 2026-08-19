# Legacy Bank

This repository contains a small banking application that mixes a modern Python web frontend with a legacy COBOL backend. The frontend is implemented in Flask and the business logic and persistence live in a COBOL program compiled to a native executable.

## Overview

The project follows a classic hybrid architecture:

- `app.py` provides the web interface and HTTP routes.
- `templates/index.html` renders the bank dashboard and forms.
- `bank_api.cbl` implements the banking logic using an indexed file database.
- The COBOL program is compiled as `bank_api` and called from Python via subprocess.

This is a simple demo of integrating a legacy COBOL system with a web UI without rewriting the core business logic.

## Features

- Register a new account with a complete customer profile
- Create a password-protected customer login
- Generate account numbers automatically with a Luhn check digit
- List all registered accounts
- Check the balance of a specific account
- Deposit money into an account
- Withdraw money from an account
- Basic validation for account numbers and monetary values
- Persistent data storage in an indexed file (`accounts.dat`)

## Repository structure

- `app.py` - Flask server and request handling
- `bank_api.cbl` - COBOL implementation of banking operations
- `requirements.txt` - Python dependencies
- `templates/base.html` - shared layout and navigation
- `templates/login.html` - customer login
- `templates/register.html` - customer onboarding
- `templates/dashboard.html` - authenticated banking dashboard
- `templates/index.html` - legacy interface kept for reference
- `accounts.dat` - generated database file after the COBOL program runs
- `customer_profiles.dat` - indexed customer profile data
- `bank_users.sqlite3` - hashed login credentials and account associations
- `bank_api` - compiled COBOL binary generated during setup

## Prerequisites

You need the following tools installed:

- Python 3.10 or newer
- GNU COBOL (`cobc` compiler)
- pip package manager

## Installation

1. Create and activate a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

2. Install Python dependencies:

```bash
pip install -r requirements.txt
```

3. Compile the COBOL backend:

```bash
cobc -x -free bank_api.cbl -o bank_api
```

This generates the executable `bank_api` in the project root.

## Running the application

Start the Flask app:

```bash
python app.py
```

Then open the browser at:

```text
http://127.0.0.1:5000
```

## How it works

The Flask app exposes routes for:

- `GET /` - redirects to login or the authenticated dashboard
- `GET, POST /login` - authenticates a customer
- `GET, POST /register` - creates the profile, password and automatically generated account
- `POST /logout` - closes the current session
- `GET /dashboard` - shows the authenticated customer's account
- `POST /deposit` - adds funds to the authenticated customer's account
- `POST /withdraw` - removes funds from the authenticated customer's account

When a form is submitted, `app.py` validates the input and invokes the COBOL binary with command-line arguments such as:

```bash
./bank_api REGISTER 123456 Juan DNI-12345 juan@empresa.com \
	"+34 600 000 000" "Calle Mayor 10, Madrid" Director "Empresa SL"
./bank_api DEPOSIT 123456 150.00
./bank_api WITHDRAW 123456 50.00
./bank_api LIST
```

The COBOL program reads and writes to `accounts.dat` and `customer_profiles.dat`, then prints results to stdout, which the Python layer parses and displays in the web UI. Flask stores only password hashes and the association between the login and the COBOL account in `bank_users.sqlite3`.

## COBOL program contract

The backend recognizes these operations:

- `REGISTER <account> <name> <document> <email> <phone> <address> <occupation> <employer>`
- `BALANCE <account>`
- `DEPOSIT <account> <amount>`
- `WITHDRAW <account> <amount>`
- `LIST`

It emits responses in this form:

- `OK|message`
- `ERR|message`
- `ROW|account|owner|balance|document|email|phone|address|occupation|employer`
- `END` for the end of the list output

## Notes

- Account numbers are limited to 6 digits.
- Amounts are expected to be numeric and may include up to two decimal places.
- Customer profiles are stored in the indexed `customer_profiles.dat` file, keyed by account number. Existing balances remain in `accounts.dat`, so older accounts can still be listed while showing a pending profile.
- New account numbers use the `42` entity prefix, a three-digit value chosen with a cryptographically secure random source, and a Luhn check digit. Each candidate is checked against the COBOL index before registration.
- Set `BANK_SECRET_KEY` in a real deployment instead of using the development fallback in `app.py`.
- The project is intentionally lightweight and is better suited for learning and demonstration than for large-scale production banking systems.
- The COBOL layer contains the real business logic and persistence, while the Python app acts as the front-end interface.

## Typical workflow

1. Compile the COBOL program.
2. Start the Flask application.
3. Register accounts from the web interface.
4. Deposit or withdraw funds.
5. Refresh the account list to verify persisted balances.

## License

No explicit license file is present in this repository. Please check with the repository owner before reusing or distributing this code commercially.

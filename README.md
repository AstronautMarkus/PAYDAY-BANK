# PAYDAY BANK Project

PAYDAY BANK is a prototype banking application that demonstrates how to integrate a legacy COBOL system with a modern web UI. It consists of two main components:

- **`core/`** — the COBOL "mainframe": all business logic and persistence (account numbers, balances, customer profiles) live here, compiled to a native binary.
- **`client/`** — the Flask web client: a thin presentation layer, organized into blueprints, that talks to the core over subprocess calls and keeps its own login database.

This is a funny or educational project, not a production-ready banking system. It is intended to illustrate how COBOL can be integrated into a modern web application stack.

## Repository structure

```
PAYDAY-BANK/
├── core/                       # COBOL "mainframe"
│   ├── src/bank_api.cbl        # banking logic over two indexed files
│   ├── bin/bank_api            # compiled binary (generated, gitignored)
│   ├── data/                   # accounts.dat, customer_profiles.dat (generated, gitignored)
│   └── Makefile                # `make build` compiles the binary
│
├── client/                     # Flask web client
│   ├── app/
│   │   ├── __init__.py         # create_app() factory
│   │   ├── config.py           # paths, secret key, SQLAlchemy URI
│   │   ├── extensions.py       # db = SQLAlchemy()
│   │   ├── models.py           # User model (login credentials)
│   │   ├── mainframe/          # subprocess client for the COBOL core
│   │   ├── blueprints/
│   │   │   ├── auth/           # login, logout, registration
│   │   │   └── banking/        # dashboard, deposit, withdraw
│   │   └── templates/
│   ├── instance/                # bank_users.sqlite3 (generated, gitignored)
│   ├── wsgi.py                  # entrypoint
│   └── requirements.txt
│
├── Makefile                     # root orchestration: setup, build-core, run-client, clean
└── README.md
```

## Features

- Register a new account with a complete customer profile
- Create a password-protected customer login
- Generate account numbers automatically with a Luhn check digit
- List all registered accounts
- Check the balance of a specific account
- Deposit and withdraw money
- Basic validation for account numbers and monetary values
- Persistent data storage in indexed COBOL files (`core/data/*.dat`)

## Prerequisites

- Python 3.10 or newer
- GNU COBOL (`cobc` compiler)
- `make`

## Setup

From the repository root:

```bash
make setup       # creates .venv and installs client/requirements.txt
make build-core  # compiles core/src/bank_api.cbl -> core/bin/bank_api
```

## Running the application

```bash
make run-client
```

Then open the browser at:

```text
http://127.0.0.1:5005
```

## How it works

### Core (`core/`)

`bank_api.cbl` is a non-interactive COBOL program: it receives its operation and arguments on the command line, reads/writes two indexed files (`accounts.dat`, `customer_profiles.dat`), and prints one result line to stdout per call. It recognizes:

- `REGISTER <account> <name> <document> <email> <phone> <address> <occupation> <employer>`
- `BALANCE <account>`
- `DEPOSIT <account> <amount>`
- `WITHDRAW <account> <amount>`
- `LIST`

Responses follow this contract:

- `OK|message`
- `ERR|message`
- `ROW|account|owner|balance|document|email|phone|address|occupation|employer`
- `END` marks the end of `LIST` output

### Client (`client/`)

`client/app` is a Flask app built with the application-factory pattern:

- `app/mainframe/client.py` is the only module that shells out to `core/bin/bank_api` (via `subprocess`, with `core/data/` as its working directory) and parses the `OK|`/`ERR|`/`ROW|`/`END` contract above.
- `app/models.py` defines the `User` model (SQLAlchemy) — it stores only password hashes and the association between a login and a COBOL account number in `client/instance/bank_users.sqlite3`. The core remains the source of truth for balances and profile data.
- `app/blueprints/auth` exposes `GET,POST /login`, `POST /logout`, `GET,POST /register`.
- `app/blueprints/banking` exposes `GET /`, `GET /dashboard`, `POST /deposit`, `POST /withdraw`.

When a form is submitted, the relevant blueprint route validates the input and calls into `app.mainframe` with arguments such as:

```bash
core/bin/bank_api REGISTER 123456 Juan DNI-12345 juan@empresa.com \
	"+34 600 000 000" "Calle Mayor 10, Madrid" Director "Empresa SL"
core/bin/bank_api DEPOSIT 123456 150000
core/bin/bank_api WITHDRAW 123456 50000
core/bin/bank_api LIST
```

## Notes

- Account numbers are limited to 6 digits.
- Balances are Chilean pesos (CLP): whole numbers with no decimal places, matching everyday CLP usage. `core/src/bank_api.cbl` stores `FD-BALANCE` as `PIC 9(12) COMP-3` (packed decimal, up to 999,999,999,999 pesos) and prints it through an edited `PIC Z(11)9` field so output has no leading zeros. `client`'s `AMOUNT_RE` (in `app/blueprints/banking/routes.py`) only accepts a positive integer with no leading zero or decimal point, and the dashboard renders balances through the `clp` Jinja filter (`app/formatting.py`), which adds "." as the thousands separator (e.g. `1234567` -> `$1.234.567`).
- Customer profiles are stored in `core/data/customer_profiles.dat`, keyed by account number. Existing balances remain in `core/data/accounts.dat`, so older accounts can still be listed while showing a pending profile.
- New account numbers use the `42` entity prefix, a three-digit value chosen with a cryptographically secure random source, and a Luhn check digit. Each candidate is checked against the COBOL index before registration (`app/mainframe/client.py`).
- Set `BANK_SECRET_KEY` in a real deployment instead of using the development fallback in `app/config.py`.
- All identifiers, comments, and docstrings in the codebase are in English; every user-facing message (flash messages, validation errors, templates) is in Spanish, matching the target audience of the demo.
- The project is intentionally lightweight and is better suited for learning and demonstration than for large-scale production banking systems.

## Typical workflow

1. `make setup && make build-core`
2. `make run-client`
3. Register accounts from the web interface.
4. Deposit or withdraw funds.
5. Refresh the dashboard to verify persisted balances.

## License

No explicit license file is present in this repository. Please check with the repository owner before reusing or distributing this code commercially.

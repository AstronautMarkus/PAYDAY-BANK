# PAYDAY BANK Project

PAYDAY BANK is a prototype banking application that demonstrates how to integrate a legacy COBOL system with a modern web UI. It consists of two main components:

- **`core/`** — the COBOL "mainframe": all business logic and persistence (account numbers, balances, customer profiles) live here, compiled to a native binary.
- **`client/`** — the Flask web client: a thin presentation layer, organized into blueprints, that talks to the core over subprocess calls and keeps no persistent data of its own (not even login credentials — see below).

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
│   │   ├── config.py           # paths, secret key
│   │   ├── mainframe/          # subprocess client for the COBOL core
│   │   ├── blueprints/
│   │   │   ├── auth/           # login, logout, registration; g.user loader
│   │   │   └── banking/        # dashboard, deposit, withdraw, open account, transfer
│   │   ├── static/
│   │   │   ├── css/                # tokens, base, components/, layout/, pages/
│   │   │   └── js/                  # one small script per behavior (toast, wizard, ...)
│   │   └── templates/
│   │       ├── layouts/            # base.html, public.html, dashboard.html (shells)
│   │       ├── partials/           # topbar, login modal, user menu, logout modal, toasts
│   │       ├── macros/             # forms.html (shared field markup)
│   │       ├── public/             # landing.html (anonymous index)
│   │       ├── auth/                # register.html, register_success.html
│   │       └── banking/             # dashboard.html, open_account.html, transfer.html
│   ├── wsgi.py                  # entrypoint
│   └── requirements.txt
│
├── Makefile                     # root orchestration: setup, build-core, run-client, clean
└── README.md
```

## Features

- Register a new customer (with a complete profile) and their first account
- Create a password-protected customer login
- Open additional accounts (Checking or Savings) for an existing customer
- Generate customer and account numbers automatically with a Luhn check digit
- List every account owned by the logged-in customer
- Check the balance of a specific account
- Deposit and withdraw money
- Transfer money between a customer's own accounts
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

`bank_api.cbl` is a non-interactive COBOL program: it receives its operation and arguments on the command line, reads/writes two indexed files (`accounts.dat`, `customer_profiles.dat`), and prints one result line to stdout per call. A **customer** (identity: profile + login) is distinct from an **account** (a product with its own balance and type, `CHECKING` or `SAVINGS`); a customer owns zero or more accounts. Every money-moving operation takes the caller's `customer-id`, and the core verifies each account's ownership before touching its balance. It recognizes:

- `REGISTER <customer-id> <account> <name> <document> <email> <phone> <address> <occupation> <employer> <password-hash>` — creates the customer (rejecting a duplicate email or document) and their first account (type `CHECKING`, balance 0)
- `CUSTEXISTS <customer-id>` — existence check, used to generate unique customer IDs
- `LOGIN <email>` — looks up a customer by email and returns `<customer-id>|<password-hash>`, or a generic error if no customer has that email
- `PROFILE <customer-id>` — returns the customer's display profile (name, document, email, phone, address, occupation, employer)
- `OPENACCT <customer-id> <account> <name> <type>` — opens an additional account (`type` is `CHECKING` or `SAVINGS`) for an existing customer
- `ACCOUNTS <customer-id>` — lists every account owned by one customer
- `BALANCE <account>`
- `DEPOSIT <customer-id> <account> <amount>`
- `WITHDRAW <customer-id> <account> <amount>`
- `TRANSFER <customer-id> <from-account> <to-account> <amount>` — moves money between two accounts; both must belong to `customer-id` (this phase only supports transfers between a customer's own accounts)
- `LIST` — bank-wide admin/debug dump, not used by the Flask client

Responses follow this contract:

- `OK|message`
- `ERR|message`
- `ROW|...` (one per row; shape depends on the operation — see each `OP-*` subprogram under `core/src/ops/`)
- `END` marks the end of a `ROW` listing (`ACCOUNTS`/`LIST` only)

### Client (`client/`)

`client/app` is a Flask app built with the application-factory pattern:

- `app/mainframe/client.py` is the only module that shells out to `core/bin/bank_api` (via `subprocess`, with `core/data/` as its working directory) and parses the `OK|`/`ERR|`/`ROW|`/`END` contract above.
- There is no database, ORM, or client-side persistence at all. The session cookie holds nothing but the logged-in customer-id; everything else — profile, credentials included — is read from COBOL on demand. Passwords are hashed and verified in Python (`werkzeug.security`, since COBOL has no crypto primitives), but the resulting hash is stored as an opaque field inside the COBOL customer record (`PF-PASSWORD-HASH` in `core/src/copybooks/customer-record.cpy`) via `REGISTER`, and read back via `LOGIN`. `app/blueprints/auth/__init__.py`'s `load_logged_in_user()` calls `PROFILE` on every request to hydrate `g.user`.
- `app/blueprints/auth` exposes `GET,POST /login`, `POST /logout`, `GET,POST /register`, `GET /register/success`. `GET /login` renders `public/landing.html` with its Sign In modal opened; `GET /register` renders the standalone `auth/register.html` wizard (personal → contact → employment → security, with client-side validation mirroring the server's) instead of a modal; a successful registration redirects to `auth/register_success.html` rather than flashing the new customer/account numbers.
- `app/blueprints/banking` exposes `GET /`, `GET /dashboard`, `POST /deposit`, `POST /withdraw`, `GET,POST /accounts/open`, `GET,POST /transfer`. `GET /` renders `public/landing.html` for anonymous visitors (redirects to the dashboard if already logged in); the other four routes render `banking/dashboard.html`/`banking/open_account.html`/`banking/transfer.html`, all extending `layouts/dashboard.html`'s sidebar shell.
- Every form is protected by Flask-WTF's `CSRFProtect` (wired up in `app/__init__.py`), and every route renders through `templates/layouts/` (shared shells), `templates/partials/` (shared fragments: topbar, login modal, user menu, logout modal, toast stack) and `templates/macros/forms.html` (shared form-field markup) instead of each page duplicating its own header/CSS. Flash messages (`flash()`/`get_flashed_messages()`) render as floating, auto-dismissing toasts (`partials/_toast_stack.html`, `static/css/components/toast.css`, `static/js/toast.js`) rather than a banner in the document flow.

When a form is submitted, the relevant blueprint route validates the input and calls into `app.mainframe` with arguments such as:

```bash
core/bin/bank_api REGISTER 900001 123456 Jane Doe ID-998877 jane@example.com \
	"(555) 123-4567" "123 Main St, Springfield" Analyst "Acme Corp" "scrypt:32768:8:1$..."
core/bin/bank_api LOGIN jane@example.com
core/bin/bank_api PROFILE 900001
core/bin/bank_api OPENACCT 900001 123457 Jane SAVINGS
core/bin/bank_api DEPOSIT 900001 123456 150000
core/bin/bank_api WITHDRAW 900001 123456 50000
core/bin/bank_api TRANSFER 900001 123456 123457 20000
core/bin/bank_api ACCOUNTS 900001
```

## Notes

- Customer IDs and account numbers are both 6 digits, generated the same way (see below) but in separate keyspaces — a customer ID is never a valid account number and vice versa.
- Balances are US dollars: whole numbers with no decimal places (no cents tracked). `core/src/copybooks/account-record.cpy` stores `FD-BALANCE` as `PIC 9(12) COMP-3` (packed decimal, up to 999,999,999,999) and each op prints it through an edited `PIC Z(11)9` field so output has no leading zeros. `client`'s `AMOUNT_RE` (in `app/blueprints/banking/routes.py`) only accepts a positive integer with no leading zero or decimal point, and the dashboard renders balances through the `usd` Jinja filter (`app/formatting.py`), which adds "," as the thousands separator (e.g. `1234567` -> `$1,234,567`).
- Customer profiles (including name and password hash) are stored in `core/data/customer_profiles.dat`, keyed by `customer-id`, with unique alternate keys on email and document (used by `LOGIN`/`READEMAIL` and the `REGISTER`-time duplicate check/`READDOC`). GnuCOBOL keeps each alternate key's index in a companion file (`customer_profiles.dat.1`, `.2`, ...) alongside the primary `.dat` — also generated and gitignored. Accounts are stored in `core/data/accounts.dat`, keyed by account number, each carrying the `customer-id` of its owner and its `FD-ACCOUNT-TYPE` (`CHECKING` or `SAVINGS`). A customer may own several accounts, including more than one of the same type.
- New account numbers use the `42` entity prefix, and new customer IDs the `77` prefix — both a three-digit value chosen with a cryptographically secure random source plus a Luhn check digit. Each candidate is checked against the COBOL index before use (`app/mainframe/client.py`: `generate_account()`/`generate_customer_id()`).
- Deposits, withdrawals, and transfers all require the caller's `customer-id` and the COBOL core rejects any operation on an account it doesn't own (`ERR|This account does not belong to the customer`) — this is enforced in the core itself, not just in the Flask forms, since the account number involved is client-supplied. Transfers are restricted to a customer's own accounts in this phase (no transfers to other customers).
- Set `BANK_SECRET_KEY` in a real deployment instead of using the development fallback in `app/config.py`.
- The codebase (identifiers, comments, docstrings, and every user-facing message — flash messages, validation errors, templates, COBOL `DISPLAY` strings) is entirely in English.
- The project is intentionally lightweight and is better suited for learning and demonstration than for large-scale production banking systems.

## Running with Docker

A multi-stage `Dockerfile` compiles `core/` (GNU COBOL) in a builder stage and
runs `client/` (gunicorn) in the final image. `core/data/*.dat` is **not**
baked into the image — `docker-compose.yml` bind-mounts `./core/data` so
data survives image rebuilds whenever `core/` is updated.

```bash
cp .env.example .env   # set a real BANK_SECRET_KEY
docker compose up -d --build
```

The app is then served at `http://localhost:5005` (bound to loopback only;
point your own reverse proxy at it). `docker compose logs -f` for logs,
`docker compose down` to stop.

> **Note:** the indexed `.dat` files are tied to the GnuCOBOL/Berkeley DB
> build that created them. Files created by a different GnuCOBOL build (e.g.
> a local `cobc` on macOS) are not guaranteed readable by the container's
> `gnucobol3`/`libcob4` (Debian) — start `core/data` empty in a new
> environment rather than copying files in from a different build.

## Typical workflow

1. `make setup && make build-core`
2. `make run-client`
3. Register accounts from the web interface.
4. Deposit or withdraw funds.
5. Refresh the dashboard to verify persisted balances.

## License

No explicit license file is present in this repository. Please check with the repository owner before reusing or distributing this code commercially.

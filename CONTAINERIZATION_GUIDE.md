# Beginner's Guide: How This Project Was Containerized with Docker & Azure

Welcome! If you are new to Docker, containers, or cloud deployment, this guide breaks down everything that was created in this project, why each piece exists, and how it all works together in plain, simple English.

---

## 💡 1. What is Containerization? (The Big Picture)

Imagine you build a house using specific tools and materials on your local computer. If you try to move that house to someone else's computer or a cloud server like Microsoft Azure, things often break because their computer might have a different version of PHP, Node.js, or database settings.

**Containerization solves this problem.** 

It packages your entire application—including the PHP code, JavaScript/React frontend, web server (Nginx), database driver, and configuration settings—into a single standardized "box" called a **Docker Container**. 

No matter where you run this container (on Windows, macOS, Linux, or Azure), it behaves **100% identically**.

---

## 🛠️ 2. What Technologies Are in This Project?

This project is a modern web application built with:
- **Laravel (PHP 8.4)**: Handles backend logic, database models, and API routes.
- **React + Inertia.js + Tailwind CSS**: Handles the interactive user interface built via **Vite**.
- **Nginx**: A high-performance web server that serves frontend assets and passes requests to PHP.
- **MySQL / SQLite**: The database storing application data.
- **Redis**: An in-memory database used for fast caching, session storage, and background queues.
- **Mailpit**: A tool to capture sent emails locally during development.

---

## 📁 3. File-by-File Breakdown: What Was Created & Why

Here is a map of every containerization file added to this project:

```text
├── Dockerfile                        # Blueprint to build the production application image
├── docker-compose.yml                # Master recipe to run all services (App, DB, Redis, Mail) together
├── docker-compose.dev.yml            # Local development recipe with live code updates & hot reloading
├── .dockerignore                     # List of files NOT to include in the container (keeps it fast & small)
├── .env.docker                       # Environment variables template configured for Docker
├── .github/workflows/deploy-azure.yml# Automatic deployment script to build & deploy to Azure
└── docker/                           # Configuration directory
    ├── entrypoint.sh                 # Startup script that runs when the container starts
    ├── nginx/
    │   ├── nginx.conf                # Main web server settings
    │   └── conf.d/default.conf       # Website routing rules (handles Laravel & React assets)
    ├── php/
    │   ├── php.ini                   # Custom PHP memory & upload limits
    │   └── opcache.ini               # Speed booster setting for PHP execution
    └── supervisor/
        └── supervisord.conf          # Manager script that keeps Nginx and PHP running together
```

---

### A. The `Dockerfile` (The Application Blueprint)

The [`Dockerfile`](file:///C:/Users/kiago/OneDrive/Documents/Work/php/azure_tutorial/Dockerfile) uses a concept called **Multi-Stage Builds**. Instead of installing everything in one heavy image, it breaks the building process into 3 clean stages:

1. **Stage 1 (`builder`)**:
   - Uses PHP 8.4 + Node.js 22 Alpine to install Composer dependencies (`composer install`), Node dependencies (`npm ci`), and compile React/Tailwind code into static files (`npm run build`). Having PHP available during the build allows Laravel Wayfinder (`@laravel/vite-plugin-wayfinder`) to inspect routes properly.
2. **Stage 2 (`final`)**:
   - Takes the application code and built assets from Stage 1 and places them into a lightweight Alpine Linux server equipped with **PHP-FPM**, **Nginx**, and **Supervisor**.
   - **Why?** Node and build dependencies are excluded from the final image, keeping it tiny, secure, and fast!

---

### B. `docker-compose.yml` (The Multi-Container Team)

Your application needs more than just PHP—it needs a web server, database, cache server, and mail handler. [`docker-compose.yml`](file:///C:/Users/kiago/OneDrive/Documents/Work/php/azure_tutorial/docker-compose.yml) launches all these components together as a team:

- **`app`**: Runs your main website on port `8000`.
- **`queue`**: Runs background tasks (like sending emails) so the website stays fast.
- **`mysql`**: Provides a production-grade MySQL 8.4 database.
- **`redis`**: Provides lightning-fast caching and session management.
- **`mailpit`**: Catches test emails locally (access UI at `http://localhost:8025`).

---

### C. `docker/entrypoint.sh` (The Startup Assistant)

Whenever your Docker container turns on, [`docker/entrypoint.sh`](file:///C:/Users/kiago/OneDrive/Documents/Work/php/azure_tutorial/docker/entrypoint.sh) automatically runs in the background to:
1. Fix file permissions so Laravel can safely write logs and cache files.
2. Initialize SQLite if configured.
3. Automatically run database migrations (`php artisan migrate`).
4. Optimize performance by caching Laravel routes and config in production.

---

### D. `docker/nginx/conf.d/default.conf` (The Front Door Server)

Nginx is the front door of your container. When a user requests your site:
- If they ask for a picture, CSS, or JS file, Nginx delivers it instantly.
- If they ask for a web page or API data, Nginx routes the request to PHP-FPM to process Laravel code.
- It also handles security headers and gzip compression to make pages load quickly.

---

### E. `.github/workflows/deploy-azure.yml` (Automated Azure Deployment)

This workflow automates your deployment to Microsoft Azure:
1. Whenever you push code to the `main` branch on GitHub, GitHub Actions starts automatically.
2. It builds your Docker image and pushes it to **GitHub Container Registry (`ghcr.io`)**.
3. It notifies **Azure Web App for Containers** to pull the new container and update your live website!

---

## 🚀 4. Simple How-To Guide

### How to Run the App Locally on Your Computer

1. Open your terminal in this project directory.
2. Run:
   ```bash
   docker compose up --build -d
   ```
3. Visit your app in your browser at: **`http://localhost:8000`**
4. Visit Mailpit (email testing UI) at: **`http://localhost:8025`**

To stop the app:
```bash
docker compose down
```

---

### How to Run in Development Mode (Live Code Reloading)

If you are actively editing code and want your browser to update live:
```bash
docker compose -f docker-compose.dev.yml up --build
```
This mounts your current directory into the container and starts Vite on port `5173`.

---

## 🔑 5. Essential Docker Concepts Glossary

- **Image**: A read-only template or blueprint containing your app and dependencies (like a blueprint for a house).
- **Container**: A running instance of an image (the actual house built from the blueprint).
- **Volume**: Permanent storage attached to a container so your database data isn't erased when containers restart.
- **Port Mapping (`8000:80`)**: Directs traffic from port `8000` on your physical computer to port `80` inside the container.
- **Environment Variables (`.env`)**: Secret keys and configuration values (like database passwords) passed into containers at runtime.

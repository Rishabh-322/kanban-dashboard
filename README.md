# Kanban Dashboard – Docker and Jenkins CI/CD Deployment on AWS

This project is a Kanban task management application built with React, TypeScript and Vite. The main goal of this project was to containerize the application using Docker and build a CI/CD pipeline with Jenkins so that changes pushed to GitHub can automatically be built, pushed to Docker Hub and deployed on an AWS EC2 instance.

The application allows tasks to be created, edited, deleted and moved between To Do, In Progress and Done columns.

## Project Links

**GitHub Repository:**
https://github.com/Rishabh-322/kanban-dashboard

**Docker Hub Repository:**
https://hub.docker.com/r/rishabh322/kanban-dashboard

**Deployed Application:**
http://13.233.159.167:3000

The application link uses the EC2 public IP used during this project. The address may stop working if the EC2 instance is stopped or terminated.

## Technologies Used

| Technology     | Purpose                             |
| -------------- | ----------------------------------- |
| React          | Frontend application                |
| TypeScript     | Application development             |
| Vite           | Frontend build tool                 |
| Docker         | Application containerization        |
| Nginx          | Serving the production React build  |
| Jenkins        | CI/CD automation                    |
| GitHub         | Source code repository              |
| GitHub Webhook | Automatically triggering Jenkins    |
| Docker Hub     | Docker image registry               |
| AWS EC2        | Hosting Jenkins and the application |
| Ubuntu         | EC2 operating system                |

## Project Architecture

The deployment flow used in this project is:

```text
Developer
    |
    | git push
    v
GitHub Repository
    |
    | Webhook
    v
Jenkins on AWS EC2
    |
    | Build Docker image
    v
Docker Hub
    |
    | Pull image
    v
Docker Container on EC2
    |
    v
Nginx
    |
    v
Kanban Dashboard :3000
```

Whenever a change is pushed to the main branch, GitHub sends a webhook request to Jenkins. Jenkins then builds a new Docker image, pushes it to Docker Hub and deploys the new version on the EC2 instance.

## Repository Structure

```text
kanban-dashboard/
│
├── public/
├── scripts/
├── src/
│
├── .dockerignore
├── Dockerfile
├── Jenkinsfile
├── nginx.conf
│
├── package.json
├── package-lock.json
├── tailwind.config.js
├── vite.config.ts
└── README.md
```

The main application code is present inside the `src` directory.

The `Dockerfile`, `nginx.conf` and `Jenkinsfile` contain the configuration added for containerization and CI/CD deployment.

## Running the Project Locally

Clone the repository:

```bash
git clone https://github.com/Rishabh-322/kanban-dashboard.git
```

Move into the project directory:

```bash
cd kanban-dashboard
```

Install the dependencies:

```bash
npm install
```

Start the Vite development server:

```bash
npm run dev
```

The application should normally be available at:

```text
http://localhost:5173
```

## Docker Setup

The application uses a multi-stage Docker build.

The first stage uses Node.js to install the project dependencies and create the production build.

The second stage uses an unprivileged Nginx Alpine image and copies only the compiled `dist` directory into the production container.

This keeps the final runtime container separate from the Node.js build environment.

### Build the Docker Image

```bash
docker build -t kanban-dashboard:local .
```

Check that the image was created:

```bash
docker images
```

### Run the Container

```bash
docker run -d \
  --name kanban-local \
  -p 3000:3000 \
  --memory=256m \
  --cpus=0.5 \
  kanban-dashboard:local
```

The containerized application can then be opened at:

```text
http://localhost:3000
```

## Nginx Configuration

The production React build is served using Nginx.

Nginx listens on port `3000`.

The configuration also handles React client-side routing using:

```nginx
try_files $uri $uri/ /index.html;
```

A separate health endpoint is available at:

```text
/health
```

A successful request returns:

```text
OK
```

## Docker Health Check

The Docker image includes a health check that calls the application every 10 seconds.

It checks:

```text
http://127.0.0.1:3000/health
```

The health endpoint can also be tested manually:

```bash
curl http://localhost:3000/health
```

Expected result:

```text
OK
```

The Docker health status can be checked with:

```bash
docker inspect \
  --format='{{.State.Health.Status}}' \
  kanban-local
```

A successful container should return:

```text
healthy
```

## Running the Container as a Non-Root User

Instead of using a normal Nginx image running as root, the final Docker image uses:

```text
nginxinc/nginx-unprivileged:alpine
```

The application runs using user ID:

```text
101
```

This can be checked using:

```bash
docker inspect --format='{{.Config.User}}' kanban-dashboard:local
```

Expected output:

```text
101
```

## Resource Limits

The deployed application container is started with CPU and memory limits.

```text
Memory: 256 MB
CPU: 0.5
```

The Jenkins deployment command uses:

```bash
--memory=256m
--cpus=0.5
```

These limits prevent the application container from unnecessarily using all of the resources available on the EC2 instance.

## Docker Ignore

A `.dockerignore` file is included to prevent unnecessary files from being added to the Docker build context.

Files and directories excluded include:

```text
node_modules
dist
.git
.gitignore
.env
.env.*
coverage
npm-debug.log*
.vscode
.idea
```

This reduces the Docker build context and prevents local or unnecessary files from being copied into the image.

## Docker Hub

Before setting up Jenkins, I manually built and pushed the Docker image to Docker Hub to verify that the repository and authentication were working.

The initial manually pushed image used the tag:

```text
manual-v1
```

After Jenkins was configured, the pipeline began creating versioned image tags automatically.

An example tag produced during the project was:

```text
1-e183ad1
```

Instead of deploying only a `latest` image, the pipeline generates tags using:

```text
Jenkins Build Number + Git Commit SHA
```

For example:

```text
rishabh322/kanban-dashboard:1-e183ad1
```

This makes each deployment identifiable and allows an older working image to be used if a new deployment fails.

## Jenkins CI/CD Pipeline

The complete pipeline is defined in the `Jenkinsfile` stored in the repository.

The pipeline contains the following main stages.

### 1. Checkout

Jenkins checks out the source code from GitHub.

It reads the short Git commit SHA and combines it with the Jenkins build number to create a unique Docker image tag.

For example:

```text
BUILD_NUMBER = 1
GIT_SHA = e183ad1

IMAGE TAG = 1-e183ad1
```

### 2. Docker Build

Jenkins builds the Docker image directly from the repository:

```bash
docker build -t "$IMAGE" .
```

### 3. Push Image

Docker Hub credentials are stored inside Jenkins rather than directly inside the repository.

Jenkins logs in using the stored credentials and pushes the versioned image:

```bash
docker push "$IMAGE"
```

### 4. Registry Pull Test

After pushing the image, Jenkins removes the local copy and pulls the same version back from Docker Hub.

This confirms that the image was actually uploaded successfully and can be retrieved from the registry.

### 5. Deployment

Before replacing the running application, Jenkins records the image currently being used by the existing container.

The existing container is then removed and the new image is started.

The container is configured with:

```text
Restart policy: unless-stopped
Memory limit: 256 MB
CPU limit: 0.5
Port: 3000
```

### 6. Health Check

Jenkins waits for the Docker container to report itself as healthy.

Once Docker reports:

```text
healthy
```

Jenkins also calls:

```text
http://127.0.0.1:3000/health
```

If the request returns successfully, Jenkins reports:

```text
Application is healthy.
```

and the deployment is considered successful.

## GitHub Webhook

A GitHub webhook is connected to Jenkins.

This means I do not have to manually click **Build Now** after every code change.

The process is:

```text
Code Change
    |
    v
git commit
    |
    v
git push
    |
    v
GitHub
    |
    v
Webhook
    |
    v
Jenkins Pipeline
    |
    v
Docker Build
    |
    v
Docker Hub
    |
    v
AWS EC2 Deployment
```

I tested the webhook by making a visible change to the application heading.

The heading was changed from:

```text
Kanban Task Manager
```

to:

```text
My Kanban Task Manager
```

The change was committed and pushed to GitHub.

The GitHub webhook triggered Jenkins, the new image was built and deployed, and the updated heading became visible on the application running on the EC2 instance.

## Automatic Rollback

I also tested what happens when a deployment does not pass validation.

For the test, I temporarily changed the Jenkins health validation request to use port:

```text
3999
```

instead of the correct application port:

```text
3000
```

The request therefore failed with a connection error.

Jenkins marked that deployment as failed and used the image recorded before the deployment to restore the previous working container.

The failed container was removed and the previous Docker image was started again.

After confirming that the rollback worked, I restored the health validation to port `3000`.

The next Jenkins pipeline completed successfully.

This confirmed that a deployment failure would not permanently replace the previously working version of the application.

## Checking the Deployment on EC2

The running application container can be checked with:

```bash
docker ps
```

The application health endpoint can be checked directly from the EC2 instance:

```bash
curl http://localhost:3000/health
```

Expected output:

```text
OK
```

The container health can also be checked using:

```bash
docker inspect \
  --format='{{.State.Health.Status}}' \
  kanban-dashboard
```

Expected result:

```text
healthy
```

## Logs and Troubleshooting

Container logs can be viewed using:

```bash
docker logs kanban-dashboard
```

This shows the Nginx startup information and runtime logs from the deployed container.

More detailed information about the container can be viewed using:

```bash
docker inspect kanban-dashboard
```

This can be used to check information such as container state, network configuration, exposed ports and health status.

## Final Result

The final setup provides an automated deployment flow from GitHub to AWS.

A code change pushed to the repository can trigger Jenkins automatically. Jenkins builds a versioned Docker image, pushes it to Docker Hub, deploys the image on AWS EC2 and verifies that the application is healthy.

The project also includes a multi-stage Docker build, a non-root runtime container, Docker health checks, CPU and memory limits, Docker Hub registry validation, GitHub webhook integration, container logging and an automatic rollback mechanism for failed deployments.

The final Kanban dashboard was successfully deployed and running from the AWS EC2 instance on port `3000`.

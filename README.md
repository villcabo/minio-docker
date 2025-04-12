# MinIO Docker Setup

This repository contains a Docker Compose configuration for quickly setting up a MinIO server instance. MinIO is a high-performance, S3-compatible object storage server.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Configuration Overview

The Docker Compose file configures a single MinIO service with the following specifications:

- Uses the latest MinIO image
- Exposes the S3 API on port 9000
- Exposes the MinIO Console (web interface) on port 9001
- Uses default credentials (admin/admin)
- Stores data persistently in the `./data` directory

## Quick Start

1. Clone this repository or create a new directory with the docker-compose.yml file

2. Start the MinIO service:
   ```bash
   docker compose up -d
   ```

3. Access the MinIO Console:
   - URL: http://localhost:9001
   - Username: admin
   - Password: admin

4. Access the S3 API endpoint at http://localhost:9000

## Environment Variables

| Variable | Description | Default Value |
|----------|-------------|---------------|
| MINIO_ROOT_USER | MinIO root username | admin |
| MINIO_ROOT_PASSWORD | MinIO root password | admin |
| MINIO_BROWSER_REDIRECT_URL | Custom domain for the console (commented out by default) | N/A |

## Data Persistence

Data is stored in the `./data` directory, which is mounted as a volume. This ensures your data persists even if the container is removed.

## Using MinIO with S3 Clients

You can use any S3-compatible client to connect to your MinIO server. Here are some example configurations:

### AWS CLI

```bash
aws s3 ls --endpoint-url http://localhost:9000 \
   --access-key admin \
   --secret-key admin
```

### MinIO Client (mc)

```bash
mc alias set myminio http://localhost:9000 admin admin
mc ls myminio
```

## Security Considerations

- **Default Credentials**: The default credentials (admin/admin) should be changed in production environments.
- **No TLS**: This setup doesn't include TLS encryption. For production use, consider enabling TLS.
- **Exposed Ports**: The service exposes ports directly to the host. Consider using a reverse proxy for additional security.

## Custom Domain Configuration

To use a custom domain:

1. Uncomment the `MINIO_BROWSER_REDIRECT_URL` line in the docker-compose.yml
2. Replace `minio.localhost` with your desired domain
3. Set up the appropriate DNS records
4. Configure a reverse proxy (like Nginx or Traefik) to handle the connections

## Troubleshooting

- **Port Conflicts**: If ports 9000 or 9001 are already in use, modify the port mappings in the docker-compose.yml
- **Permission Issues**: Ensure the `./data` directory has appropriate permissions

## Additional Resources

- [MinIO Documentation](https://docs.min.io/)
- [MinIO Docker Hub](https://hub.docker.com/r/minio/minio/)
- [S3 API Reference](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html)
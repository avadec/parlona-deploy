# Security

Before production use:

- Use pinned image tags, not `latest`.
- Generate unique secrets per customer install.
- Restrict ports `8080`, `3000`, `5432`, and `6379` at the firewall.
- Put TLS in front of the dashboard and API.
- Prefer customer-managed Keycloak/OIDC for enterprise deployments.
- Store `.env` securely; it contains API keys and passwords.
- Back up PostgreSQL and audio storage.

The bundled Redis and PostgreSQL services are intended for single-machine deployments. Larger production environments can use managed services and compose overrides.

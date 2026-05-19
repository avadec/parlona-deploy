# Keycloak

Production customers should normally bring their own Keycloak or OIDC provider.

Set:

```bash
KEYCLOAK_ENABLED=1
KEYCLOAK_URL=https://keycloak.example.com
NEXT_PUBLIC_KEYCLOAK_URL=https://keycloak.example.com
KEYCLOAK_REALM=voicecore
KEYCLOAK_CLIENT_ID=voicecore-frontend
```

Create a public client:

- Client ID: `voicecore-frontend`
- Standard flow: enabled
- PKCE: S256
- Client authentication: off
- Valid redirect URIs: `https://YOUR_FRONTEND_HOST/*`
- Web origins: `https://YOUR_FRONTEND_HOST`

For local evaluation only, this bundle includes a Keycloak overlay:

```bash
./install.sh --with-keycloak
```

That overlay is not intended as a hardened production identity provider.

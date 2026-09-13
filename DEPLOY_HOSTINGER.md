# Desplegar en un VPS de Hostinger con Docker

Guía paso a paso para publicar esta landing page en un VPS de Hostinger usando
el `Dockerfile` y `docker-compose.yml` de este repositorio.

## 0. Datos que necesitas de hPanel

En [hPanel](https://hpanel.hostinger.com/) → **VPS** → tu servidor → pestaña
**Overview** encontrarás:

- La **IP pública** del VPS.
- Usuario `root` y su contraseña (o puedes subir tu clave SSH en
  **Settings → SSH Keys** para entrar sin contraseña).

Si aún no creaste el VPS: al elegir el sistema operativo, Hostinger ofrece
plantillas con **Docker ya preinstalado** (busca "Docker" en la lista de OS /
Apps). Elegirla te ahorra el paso 2.

## 1. Conéctate por SSH

Desde tu computadora:

```bash
ssh root@TU_IP_DEL_VPS
```

(También puedes usar la **terminal del navegador** que ofrece hPanel dentro
de la vista del VPS, sin instalar nada localmente.)

## 2. Instala Docker (si tu plantilla no lo trae)

```bash
apt update && apt upgrade -y
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin git
docker --version
docker compose version
```

## 3. Clona el repositorio

```bash
mkdir -p /opt && cd /opt
git clone https://github.com/klever747/LandingPageKP.git
cd LandingPageKP
git checkout main
```

Si el repositorio es **privado**, usa un token de acceso personal de GitHub
en la URL de clonado:

```bash
git clone https://TU_TOKEN@github.com/klever747/LandingPageKP.git
```

## 4. Levanta el contenedor

Para exponer el sitio directamente en el puerto 80 (recomendado si aún no
tienes dominio), edita `docker-compose.yml` y cambia el mapeo de puertos:

```yaml
services:
  web:
    ports:
      - "80:80"   # en vez de "8080:80"
```

Luego construye y arranca:

```bash
docker compose up -d --build
docker ps          # confirma que el contenedor "landingpage-kp" está Up
docker compose logs -f web   # para ver logs si algo falla (Ctrl+C para salir)
```

## 5. Abre el puerto en el firewall

**a) Firewall de Hostinger (hPanel):**
hPanel → tu VPS → pestaña **Firewall** → crea/activa reglas que permitan
tráfico entrante TCP en el puerto **80** (y **443** si más adelante usas
HTTPS). El puerto 22 (SSH) normalmente ya está permitido.

**b) Firewall del sistema (si usas `ufw`):**

```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw status
```

## 6. Verifica que funciona

Abre en el navegador: `http://TU_IP_DEL_VPS`

Deberías ver la landing page. Si no carga, revisa en este orden:
`docker ps` (¿el contenedor sigue corriendo?) → `docker compose logs web`
(¿hay errores?) → firewall de hPanel → firewall `ufw` del sistema.

## 7. Actualizar el sitio tras un cambio

Desde tu equipo, haz `git push` a la rama que uses en el VPS y luego, en el
VPS:

```bash
cd /opt/LandingPageKP
git pull
docker compose up -d --build
```

## 8. (Opcional) Dominio propio + HTTPS con Caddy

Si tienes un dominio, apunta un registro **A** hacia la IP del VPS. Luego usa
[Caddy](https://caddyserver.com/) como proxy inverso: obtiene y renueva el
certificado SSL automáticamente, sin configuración manual de Certbot.

**a)** Deja el sitio solo accesible internamente, cambiando el puerto en
`docker-compose.yml`:

```yaml
services:
  web:
    ports:
      - "127.0.0.1:8080:80"   # ya no expuesto directamente a internet
```

**b)** Crea `Caddyfile` en la misma carpeta del proyecto:

```
tudominio.com {
    reverse_proxy 127.0.0.1:8080
}
```

**c)** Añade el servicio de Caddy a `docker-compose.yml`:

```yaml
services:
  web:
    # ... (como quedó en el paso a)

  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddyfile
      - caddy_data:/data
      - caddy_config:/config
    command: caddy run --config /etc/caddyfile

volumes:
  caddy_data:
  caddy_config:
```

**d)** Aplica los cambios:

```bash
docker compose up -d --build
```

Caddy emitirá el certificado de Let's Encrypt automáticamente la primera vez
que reciba tráfico en tu dominio (asegúrate de que el DNS ya propagó y de que
el puerto 80/443 estén abiertos en el firewall de Hostinger).

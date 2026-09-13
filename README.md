# LandingPageKP

Landing page para ofrecer servicios de:

- **DPO** (Delegado de Protección de Datos)
- **Ingeniería en Sistemas**
- **Cableado Estructurado**

Sitio estático (HTML/CSS/JS sin frameworks ni dependencias externas), listo para
publicarse en GitHub y desplegarse en cualquier VPS mediante Docker.

## Estructura

```
.
├── public/              # Archivos del sitio (esto es lo que se sirve)
│   ├── index.html
│   ├── css/style.css
│   ├── js/script.js
│   └── assets/favicon.svg
├── Dockerfile
├── docker-compose.yml
├── nginx.conf
└── README.md
```

## Personalizar contenido

Antes de publicar, edita en `public/index.html`:

- Nombre/marca: busca `KP Soluciones` y `brand-name`.
- Datos de contacto: sección `<section class="contacto">` (correo, teléfono y
  ubicación).
- Textos de cada servicio dentro de `<section class="servicios">`.

El formulario de contacto envía los mensajes mediante
[Formspree](https://formspree.io) (sin backend propio). Para activarlo:

1. Crea una cuenta gratuita en https://formspree.io/register.
2. Crea un formulario nuevo y confirma el correo de destino
   (`kleverpardo747@gmail.com`).
3. Copia el endpoint que te da Formspree (`https://formspree.io/f/xxxxxxx`) y
   pégalo en el atributo `action` del `<form id="contactForm">` dentro de
   `public/index.html`, reemplazando `TU_FORM_ID`.

Si prefieres otra solución (un backend propio en Node/PHP, un webhook, etc.),
reemplaza el manejador del evento `submit` en `public/js/script.js`.

## Ver el sitio en local

No requiere instalación de dependencias. Basta un servidor estático simple:

```bash
cd public
python3 -m http.server 8000
# abre http://localhost:8000
```

## Subir el proyecto a GitHub

```bash
git init                      # si aún no es un repositorio
git add .
git commit -m "Landing page de servicios DPO, TI y cableado estructurado"
git branch -M main
git remote add origin https://github.com/<tu-usuario>/<tu-repo>.git
git push -u origin main
```

Si ya clonaste el repositorio desde GitHub, solo necesitas:

```bash
git add .
git commit -m "Actualiza landing page"
git push
```

## Desplegar en tu VPS con Docker

### 1. Construir y correr con Docker Compose (recomendado)

En el servidor, dentro de la carpeta del proyecto:

```bash
docker compose up -d --build
```

Esto construye la imagen con Nginx sirviendo el sitio y lo publica en el
puerto **8089** del VPS (`http://IP_DEL_VPS:8089`). Puedes cambiar el puerto
editando `docker-compose.yml` (por ejemplo `"80:80"` si el puerto 80 está
libre).

Para actualizar el sitio tras un cambio:

```bash
git pull
docker compose up -d --build
```

### 2. Alternativa: Docker sin Compose

```bash
docker build -t landingpage-kp .
docker run -d --name landingpage-kp --restart unless-stopped -p 8089:80 landingpage-kp
```

### 3. Exponer con dominio propio y HTTPS

El contenedor solo sirve HTTP en el puerto interno 80. Para usar tu dominio
con certificado SSL, coloca por delante un proxy inverso en el VPS, por
ejemplo:

- **Nginx Proxy Manager** o **Traefik**, apuntando al contenedor
  (`landingpage-kp:80` en la misma red Docker, o `IP_VPS:8089` si expones el
  puerto).
- O un Nginx/Caddy instalado directamente en el VPS haciendo `proxy_pass` a
  `http://127.0.0.1:8089` y gestionando el certificado con Let's Encrypt
  (Certbot o el propio Caddy, que lo hace automático).

Ejemplo mínimo de bloque Nginx como proxy inverso en el host:

```nginx
server {
    listen 80;
    server_name tudominio.com;

    location / {
        proxy_pass http://127.0.0.1:8089;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Después de eso, corre `certbot --nginx -d tudominio.com` para habilitar HTTPS.

## Notas de seguridad

`nginx.conf` incluye compresión gzip, cache para archivos estáticos y
cabeceras de seguridad básicas (`X-Content-Type-Options`, `X-Frame-Options`,
`Referrer-Policy`), acorde a un sitio que promociona servicios de protección
de datos.

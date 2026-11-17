<p align="center"><img src="keshiki.png" width="339"></p>

<p align="center">un gestor de fondos de pantalla animados liviano para Linux escrito en Bash.</p>

<p align="center">Version<b> 1.1.5 <b></p>

# Keshiki ー景色ー

Si te gusta mi proyecto, ¡por favor no olvides hacer clic en el botón de estrella! 🌟 ¡Tu apoyo es muy valioso!

[![GitHub estrellas](https://img.shields.io/github/stars/Konqi0139/Keshiki?style=flat-square)](https://github.com/Konqi0139/Keshiki/stargazers)
[![GitHub observadores](https://img.shields.io/github/watchers/Konqi0139/Keshiki?style=flat-square)](https://github.com/Konqi0139/Keshiki/watchers)
[![GitHub licencia](https://img.shields.io/github/license/Konqi0139/Keshiki?style=flat-square)](https://github.com/Konqi0139/Keshiki)
[![GitHub último commit](https://img.shields.io/github/last-commit/Konqi0139/Keshiki?style=flat-square)](https://github.com/Konqi0139/Keshiki/commits)



---

## Características 🔥

Existen varias soluciones para lograr tener un video como fondo de pantalla en Linux (como el propio Hidamari o Komorebi). Keshiki ofrece una alternativa ultra-liviana construida sobre scripts nativos, con las siguientes funciones:

- [x] **100% Bash:** Sin pesados entornos de ejecución, inicio instantáneo y mínimo impacto en el sistema.
- [x] **Renderizado nativo:** Utiliza `xwinwrap` para incrustar el contenido directamente detrás de tus ventanas e íconos.
- [x] **Reproducción fluida:** Soporte multiformato delegando la tarea en el potente motor de `mpv`.
- [x] **Interfaz Gráfica nativa (GUI):** Ventanas de diálogo intuitivas creadas gracias a `yad` para gestionar tus fondos.
- [x] **Detección de ventanas maximizadas y pantalla completa!** <sup>1</sup>
- [x] **Control del reproductor en segundo plano:** Comunicación bidireccional mediante sockets IPC. <sup>2</sup>
- [x] **Extracción automática de miniaturas:** Genera vistas previas de tus videos al agregarlos. <sup>3</sup>
- [x] **Bandeja del sistema (Systray):** Control total de pausa, reproducción y apagado con solo dos clics desde tu barra de tareas.

<sup>**1**</sup> Pausa automáticamente la reproducción del video de fondo al detectar ventanas maximizadas (horizontal + vertical) o juegos en pantalla completa para priorizar los recursos de hardware (Actualmente exclusivo de X11).
<sup>**2**</sup> Utiliza `socat` para enviar comandos limpios a `mpv` (como mutear, pausar o cerrar), evitando matar procesos a la fuerza y previniendo conflictos si estás reproduciendo otro video de forma externa.
<sup>**3**</sup> Utiliza `ffmpeg` o `ffmpegthumbnailer` para extraer fotogramas exactos y `imagemagick` para el reescalado óptimo dentro de la interfaz gráfica.

---

## Instalación ⏬

Keshiki incluye un script que comprueba las dependencias e instala el lanzador y el acceso al menú. Por defecto instala para el usuario actual, sin privilegios:

### Instrucciones de consola

```bash
# 1. Clonar el repositorio
git clone https://github.com/Konqi0139/Keshiki.git
cd Keshiki

# 2. Otorgar permisos y ejecutar el instalador
./install.sh
```

Los archivos se instalan en `${XDG_DATA_HOME:-~/.local/share}/keshiki` y el comando en `~/.local/bin`. Para instalar para todos los usuarios en `/usr/local`, ejecuta `sudo ./install.sh`. El instalador no instala dependencias ni ejecuta `sudo` por su cuenta.

### Tabla de Dependencias Verificadas

| Herramienta | Función en Keshiki | Estado en el instalador |
| :--- | :--- | :---: |
| `bash` | Intérprete principal del script | Requerido |
| `yad` | Ventanas de interfaz y menú en barra de tareas | Requerido |
| `mpv` | Renderizado multimedia fluido | Requerido |
| `xwinwrap` | Dibujado de video en la Root Window (X11) | Requerido |
| `socat` | Sockets de comunicación IPC con mpv | Requerido |
| `xdotool` / `wmctrl` / `xprop` | Monitoreo y detección de estado de ventanas | Requerido |
| `flock` / `setsid` / `sha256sum` | Aislamiento, control de sesiones e integridad | Requerido |
| `ffmpeg` | Captura de fotogramas para recursos | Requerido |
| `imagemagick` | Tratamiento y redimensión de miniaturas | Opcional |

---
### Instalación rápida de `xwinwrap` (Si no está en tus repositorios)

Si usás **Arch Linux** o derivados, podés instalarlo directo desde el AUR:
```bash
yay -S xwinwrap-mmhobi7-git
```

Para **Debian / Ubuntu / Linux Mint** (compilación desde el fork recomendado):
```bash
sudo apt install git build-essential libx11-dev libxext-dev libxrender-dev
git clone https://github.com/mmhobi7/xwinwrap.git
cd xwinwrap && make && sudo make install
```

> **💡 Nota para soporte de YouTube:** Para agregar enlaces o directos de YouTube, asegurate de tener instalado `yt-dlp` junto con un motor de JavaScript ligero como: `deno`, `quickjs` o `nodejs`.

### Desinstalación 🗑️

Para desinstalar, usa la misma modalidad que durante la instalación:

```bash
./install.sh --remove       # instalación de usuario
sudo ./install.sh --remove  # instalación de sistema
```

La desinstalación conserva la configuración y las miniaturas en `${XDG_CONFIG_HOME:-~/.config}/keshiki`. Las instalaciones antiguas en `/opt/keshiki` deben revisarse y retirarse manualmente.

## Screenshots 📸

| Interfaz Principal | Selección de Wallpapers |
| :---: | :---: |
| ![Keshiki GUI](screenshots/preview.png) | ![Selector de archivos](screenshots/file-selector.png) |

| Bandeja del Sistema (Systray) | Opciones y Configuración |
| :---: | :---: |
| ![Keshiki Systray](screenshots/system-tray.png) | ![Configuración de Opacidad](screenshots/dialog-options.png) |

---

## ¡Por favor! 🙏

¡La colaboración es más que bienvenida! Hagamos este script cada vez mejor y más optimizado. 

Si encontrás algún error, tenés sugerencias sobre el consumo de recursos o querés proponer una nueva característica, sentite libre de abrir un **Issue** o enviar un **Pull Request** 🤗

## Contribuidores ✨

* **S.Konqi0139** (Creador y desarrollador principal)
* **Monstercat Guy Ü** (Arte de iconos / Recursos gráficos)

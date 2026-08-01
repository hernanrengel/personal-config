# Personal Configuration (dotfiles) - Arch Linux + Hyprland

Este repositorio contiene toda mi configuración personal, incluyendo configuraciones de aplicaciones, scripts, temas visuales, cursores, fuentes y fondos de pantalla. Está diseñado para poder clonarse en una nueva computadora con Arch Linux y restaurar exactamente el mismo entorno de trabajo y experiencia de usuario ejecutando un único script.

## Estructura del Proyecto

El repositorio está organizado de la siguiente manera:
- **`backup.sh`**: Script para recopilar y actualizar las configuraciones locales de la computadora actual en este repositorio.
- **`install.sh`**: Script único de restauración para instalar los paquetes y enlazar las configuraciones en la nueva computadora.
- **`packages/`**: Listas de paquetes explícitamente instalados (tanto nativos de Arch con `pacman` como desde el AUR con `yay`/`paru`).
- **`dot_config/`**: Copia de carpetas de configuración de aplicaciones (mapeadas a `~/.config/`). Incluye Hyprland, Waybar, Alacritty, Kitty, Cava, Wofi, Lazygit, Yazi, Swaync, Wlogout, etc.
- **`home/`**: Archivos del directorio personal (mapeados a `~/`), como tu `.zshrc`, `.gitconfig` y `.gtkrc-2.0`.
- **`bin/`** y **`local_bin/`**: Scripts de usuario personalizados (mapeados a `~/bin` y `~/.local/bin/`). Los binarios compilados pesados (como `terraform` o `uv`) se excluyen automáticamente para mantener el repositorio ligero.
- **`scripts/`**: Scripts adicionales personalizados de automatización (mapeados a `~/scripts/`).
- **`wallpapers/`**: Imágenes de fondos de pantalla personalizados y recursos locales de wallpapers. El repositorio de fondos masivo de `mylinuxforwork` se clona dinámicamente durante la instalación para ahorrar espacio en Git.
- **`themes/`** y **`icons/`**: Temas e iconos personalizados, como el tema `Graphite-Dark`.

---

## Cómo usar el sistema de respaldo

### 1. En tu computadora actual (Guardar cambios)
Cada vez que realices cambios en tus configuraciones locales, añade nuevos scripts o instales paquetes y desees respaldarlos en este repositorio, simplemente ejecuta:

```bash
./backup.sh
```

El script actualizará las listas de paquetes y copiará los archivos de configuración modificados al repositorio. Después, puedes guardar los cambios en Git y subirlos a tu servidor remoto (por ejemplo, GitHub):

```bash
git add .
git commit -m "update: sincronizar ultimas configuraciones y scripts"
git push origin main
```

---

### 2. En la nueva computadora (Restaurar todo)
Una vez que hayas instalado Arch Linux en tu nueva computadora, abre una terminal y sigue estos pasos:

1. **Clona este repositorio**:
   ```bash
   git clone <URL-DE-TU-REPOSITORIO> ~/personal-config
   ```

2. **Entra al directorio**:
   ```bash
   cd ~/personal-config
   ```

3. **Ejecuta el script de instalación**:
   ```bash
   ./install.sh
   ```

### ¿Qué hace el script de restauración automáticamente?
1. **Comprobación de Sistema**: Verifica que estás en Arch Linux.
2. **Bootstrap del AUR Helper**: Si no tienes un gestor de AUR (`yay` o `paru`), descarga y compila `yay-bin` de forma totalmente automática.
3. **Instalación de Aplicaciones**: Lee las listas en `packages/` e instala todos tus programas y herramientas de desarrollo (tanto nativos de Arch como de AUR) de forma masiva y silenciosa.
4. **Respaldo de Seguridad**: Si en la nueva computadora ya existen archivos en `~/.config/` o dotfiles, los renombra añadiendo la extensión `.backup` para que no pierdas nada de información.
5. **Creación de Enlaces Simbólicos (Symlinks)**: Crea enlaces simbólicos desde el repositorio clonado hacia las carpetas reales (`~/.config`, `~/`, `~/scripts`, etc.). 
   > [!NOTE]
   > Al usar enlaces simbólicos, cualquier modificación futura que hagas en tus programas (ej. cambiar colores en Hyprland o editar tu `.zshrc`) modificará directamente los archivos dentro del repositorio de configuración local. Así sólo tienes que hacer `git commit` y `git push` para mantenerlo todo actualizado sin tener que copiar archivos manualmente.
6. **Instalación de Oh My Zsh y Plugins**: Descarga Oh My Zsh y clona los plugins más útiles (`zsh-autosuggestions` y `zsh-syntax-highlighting`).
7. **Fondos de Pantalla**: Clona de manera eficiente (con profundidad 1) el set de wallpapers de `mylinuxforwork` y enlaza tus fondos locales.
8. **Configuración del Shell**: Cambia tu shell por defecto a `Zsh` para que todo cargue de inmediato.

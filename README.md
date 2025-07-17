# Hardening Script - Fidelity Marketing 2025

Este script interactivo de Bash automatiza el proceso de hardening (fortalecimiento de seguridad) para sistemas Linux.  Permite ejecutar o auditar scripts de seguridad organizados en bloques y gestiona los logs de cada operación.

## Requisitos

*   Bash

*   Privilegios de root (el script debe ejecutarse con `sudo`)

*   Comandos: `find`, `chmod`, `mktemp`, `head`, `rm`, `less`, `tee`, `cat`, `echo`, `select`, `case`, `read`

## Uso

1.  **Clonar el repositorio:**

    ```bash
    git clone https://github.com/Golidor24/Hardening_Fmkt.git
    cd Hardening_Fmkt
    ```

2.  **Ejecutar el script:**

    ```bash
    sudo ./hardening.sh
    ```

3.  **Interfaz interactiva:**

    El script presenta un menú con las siguientes opciones:

    *   **Ejecutar:**  Ejecuta los scripts de hardening en cada bloque, aplicando las configuraciones de seguridad.  **Requiere reiniciar el sistema después de la ejecución.**

    *   **Auditar:**  Realiza una ejecución en modo "dry-run" (simulación), mostrando los cambios que se aplicarían sin realmente modificarlos.

    *   **Ver log general:**  Muestra el archivo `Hardening.log`, que contiene un registro de todas las ejecuciones y auditorías.

    *   **Ver logs por bloque:** Permite explorar los logs específicos de cada bloque de hardening, si existen.
    
    *   **Salir:** Termina la ejecución del script.

## Estructura del proyecto

El proyecto debe organizarse en directorios `Bloque*`, cada uno representando un conjunto de configuraciones de hardening segun los informes de Nessus.  Dentro de cada bloque, los scripts de hardening deben tener la extensión `.sh`.  Opcionalmente, cada bloque puede contener una carpeta `Log` para almacenar logs específicos del bloque.

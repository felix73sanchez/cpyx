# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Felix Sanchez <felixsanchez73@outlook.com>

# Autocompletado de cpyx para fish
complete -c cpyx -s n -l dry-run -d 'Simulación: no copia nada'
complete -c cpyx -s d -l delete -d 'Borrar en destino lo que no exista en origen'
complete -c cpyx -s y -l yes -d 'No pedir confirmación'
complete -c cpyx -s x -l exclude -r -d 'Excluir patrón'
complete -c cpyx -s X -l exclude-from -r -F -d 'Leer exclusiones desde archivo'
complete -c cpyx -s l -l log -r -F -d 'Guardar el log en ARCHIVO'
complete -c cpyx -s L -l no-log -d 'No guardar log'
complete -c cpyx -s b -l backup -d 'Modo backup incremental con hardlinks'
complete -c cpyx -l keep -r -d 'Conservar últimos N snapshots'
complete -c cpyx -l bwlimit -r -d 'Limitar ancho de banda'
complete -c cpyx -s u -l update -d 'Actualizar cpyx'
complete -c cpyx -s v -l version -d 'Mostrar la versión'
complete -c cpyx -s V -d 'Mostrar la versión'
complete -c cpyx -s h -l help -d 'Mostrar la ayuda'
